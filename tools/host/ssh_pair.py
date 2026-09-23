"""One-use LAN enrollment over certificate-bound TLS; OpenSSH owns sessions."""
import base64
import getpass
import hmac
import ipaddress
import queue
import secrets
import shlex
import socket
import ssl
import struct
import threading


def ssh_tool(name):
    path = shutil.which(name)
    if not path and os.name == 'nt':
        candidate=Path(os.environ.get('WINDIR','C:/Windows'))/'System32'/'OpenSSH'/(name+'.exe')
        if candidate.is_file(): path=str(candidate)
    require(path, 'missing prerequisite: '+name)
    return path


def ssh_state(value=None, create=True):
    root=Path(value) if value else Path.home()/'.hap'/'ssh'
    return private_root(root) if create else safe_root(root)


def public_key(text):
    require(isinstance(text,str),'expected public key text')
    parts=text.strip().split()
    require(len(parts) in (2,3) and parts[0] == 'ssh-ed25519', 'expected Ed25519 public key')
    blob=base64.b64decode(parts[1],validate=True)
    require(len(blob)==51 and blob[:19]==b'\x00\x00\x00\x0bssh-ed25519\x00\x00\x00\x20','invalid Ed25519 public key')
    return ' '.join(parts[:2])


def fingerprint(key):
    return 'SHA256:'+base64.b64encode(hashlib.sha256(base64.b64decode(key.split()[1])).digest()).decode().rstrip('=')


def address(value):
    ip=ipaddress.ip_address(value)
    require(ip.version==4 and (ip.is_loopback or any(ip in ipaddress.ip_network(n) for n in ['10.0.0.0/8','172.16.0.0/12','192.168.0.0/16'])) and not ip.is_unspecified and not ip.is_multicast and not ip.is_link_local,'select a private IPv4 LAN address')
    return str(ip)


def user_name(value):
    require(re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}',value),'invalid SSH account name')
    return value


def send_frame(conn, data):
    raw=json.dumps(data,sort_keys=True,separators=(',',':')).encode()
    require(len(raw)<=16384,'frame too large');conn.sendall(struct.pack('!I',len(raw))+raw)


def read_frame(conn):
    def read(n):
        data=b''
        while len(data)<n:
            chunk=conn.recv(n-len(data));require(chunk,'truncated pairing frame');data+=chunk
        return data
    size=struct.unpack('!I',read(4))[0];require(0<size<=16384,'frame too large')
    try:data=json.loads(read(size))
    except (ValueError,RecursionError,UnicodeError):raise ValueError('invalid pairing JSON') from None
    require(isinstance(data,dict),'expected object');return data


def decode_code(code):
    require(0<len(code)<8192 and code.startswith('hapssh1.'),'invalid pairing code')
    data=json.loads(base64.urlsafe_b64decode(code[8:]+'='*((-len(code[8:]))%4)))
    require(set(data)=={'v','ip','port','sshPort','id','secret','cert','user','expires'},'invalid pairing code fields')
    require(data['v']==1,'unsupported protocol');address(data['ip']);user_name(data['user'])
    require(type(data['port']) is int and 1024<=data['port']<=65535 and type(data['sshPort']) is int and 1<=data['sshPort']<=65535,'invalid port')
    require(re.fullmatch('[0-9a-f]{32}',data['id']) and re.fullmatch('[0-9a-f]{64}',data['secret']),'invalid session secret')
    require(type(data['expires']) is int and time.time()<data['expires']<=time.time()+605,'expired or invalid code')
    cert=base64.b64decode(data['cert'],validate=True);require(len(cert)<=4096,'certificate too large')
    return data,cert


def challenge_bytes(code, challenge, key):
    return json.dumps({'protocol':'hap-ssh-pair-v1','session':code['id'],'ip':code['ip'],'sshPort':code['sshPort'],'user':code['user'],'challenge':challenge,'clientKey':key},sort_keys=True,separators=(',',':')).encode()


def confirm_pair(key, user, deadline, preauthorized):
    if preauthorized:return True
    require(sys.stdin.isatty(),'pairing requires host TTY confirmation or explicit --preauthorize')
    print('Grant persistent shell access to '+user+' for '+fingerprint(key)+' until hap ssh revoke? Type yes:',file=sys.stderr,flush=True)
    q=queue.Queue()
    threading.Thread(target=lambda:q.put(sys.stdin.readline().strip()),daemon=True).start()
    try:return q.get(timeout=max(0.1,deadline-time.time()))=='yes'
    except queue.Empty:return False


def authorized_file(user, allow_privileged=False):
    require(user.lower()==getpass.getuser().lower(),'run pairing as the selected existing account')
    if os.name=='nt':
        # sshd uses group membership, including a UAC-filtered administrator token.
        admin = subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-Command',"if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups.Value -contains 'S-1-5-32-544') {exit 0} else {exit 1}"],capture_output=True).returncode==0
        if admin:
            require(allow_privileged,'administrator enrollment needs --allow-privileged; shared administrators keys grant administrative shell access')
            return safe_root(Path(os.environ.get('ProgramData','C:/ProgramData'))/'ssh'/'administrators_authorized_keys')
    elif os.getuid()==0:
        require(allow_privileged,'root enrollment needs --allow-privileged')
    return safe_root(Path.home()/'.ssh'/'authorized_keys')


def write_authorized(path, data):
    path.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
    if os.name!='nt':
        s=path.parent.stat();require(s.st_uid==os.getuid() and s.st_mode & 0o022==0,'untrusted .ssh directory')
    temp=path.with_name('.hap-keys-'+uuid.uuid4().hex)
    try:
        with open(temp,'xb') as f:
            if os.name!='nt':os.chmod(temp,0o600)
            f.write(data);f.flush();os.fsync(f.fileno())
        if os.name=='nt':
            principals=['*S-1-5-32-544:F','*S-1-5-18:F'] if path.name=='administrators_authorized_keys' else [command(['whoami'])+':F','*S-1-5-18:F']
            command(['icacls',str(temp),'/inheritance:r','/grant:r',*principals])
        os.replace(temp,path)
    finally:temp.unlink(missing_ok=True)


def enroll(root, auth, key, user, session):
    peer=hashlib.sha256(key.encode()).hexdigest()[:32]
    with lock(root,'.authorized-lock'):
        old=auth.read_bytes() if auth.exists() else b''
        require(len(old)<=1024*1024,'authorized_keys too large')
        require(key.split()[1].encode() not in old,'public key already registered')
        atomic_json(root/('authorized-backup-'+session+'.json'),{'path':str(auth),'bytesBase64':base64.b64encode(old).decode()})
        record=root/('host-'+peer+'.json');require(not record.exists(),'peer already recorded')
        line='no-agent-forwarding,no-port-forwarding,no-X11-forwarding '+key+' hap-'+peer
        rec={'peerId':peer,'publicKey':key,'keyLine':line,'user':user,'authorizedKeys':str(auth),'session':session,'status':'registering','authorization':'until-revoked','createdAt':int(time.time())}
        atomic_json(record,rec)
        # Recovery can revoke the exact key even after a crash between file updates.
        write_authorized(auth,old+(b'\n' if old and not old.endswith(b'\n') else b'')+line.encode()+b'\n')
        rec['status']='active';atomic_json(record,rec)
    return peer


def revoke(root, peer):
    require(re.fullmatch('[0-9a-f]{32}',peer),'invalid peer id')
    with lock(root,'.authorized-lock'):
        path=root/('host-'+peer+'.json');rec=read_json(path)
        auth=authorized_file(rec['user'],True)
        require(str(auth)==rec['authorizedKeys'],'authorized_keys location changed')
        old=auth.read_bytes() if auth.exists() else b''
        require(len(old)<=1024*1024,'authorized_keys too large')
        blob=rec['publicKey'].split()[1].encode()
        lines=old.splitlines(keepends=True)
        # Remove every exact blob occurrence, including a re-formatted Hap-owned line.
        def owns_key(line):
            try:
                fields=shlex.split(line.decode('utf-8'),comments=True)
                index=0 if fields and fields[0]=='ssh-ed25519' else 1
                return len(fields)>index+1 and fields[index]=='ssh-ed25519' and fields[index+1].encode()==blob
            except (ValueError,UnicodeError):return False
        new=b''.join(line for line in lines if not owns_key(line))
        if new!=old:write_authorized(auth,new)
        rec['status']='revoked';rec['revokedAt']=int(time.time());atomic_json(path,rec)
        return {'ok':True,'status':'revoked','peerId':peer,'serverKeyRemoved':True,'newConnectionRejectionVerified':False,'existingSessionsTerminated':False}


def ssh_pair(o):
    ip=address(o.listen); user=user_name(o.user or getpass.getuser());auth=authorized_file(user,o.allow_privileged)
    require(30<=o.ttl<=600,'TTL must be 30..600 seconds')
    require(1024<=o.pair_port<=65535 and 1<=o.port<=65535,'invalid port')
    require(o.show_code or (sys.stdout.isatty() and not o.json),'use --show-code for explicit sensitive output; ordinary JSON omits the code')
    require(o.preauthorize or sys.stdin.isatty(),'host confirmation requires a TTY or --preauthorize')
    root=ssh_state(o.state_root)
    default_key=(Path(os.environ.get('ProgramData','C:/ProgramData'))/'ssh'/'ssh_host_ed25519_key.pub') if os.name=='nt' else Path('/etc/ssh/ssh_host_ed25519_key.pub')
    host_key=public_key((Path(o.host_key) if o.host_key else default_key).read_text().strip())
    openssl=ssh_tool('openssl');ssh_tool('ssh-keygen')
    with tempfile.TemporaryDirectory(prefix='.pair-',dir=root) as temp:
        temp=Path(temp); cert=temp/'cert.pem'; private=temp/'tls-key.pem'
        command([openssl,'req','-x509','-newkey','rsa:2048','-sha256','-nodes','-days','1','-subj','/CN=Hap pairing','-addext','subjectAltName=IP:'+ip,'-keyout',private,'-out',cert],60)
        private.chmod(0o600)
        der=ssl.PEM_cert_to_DER_cert(cert.read_text())
        context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.minimum_version=ssl.TLSVersion.TLSv1_2;context.load_cert_chain(cert,private)
        deadline=int(time.time())+o.ttl
        code={'v':1,'ip':ip,'port':o.pair_port,'sshPort':o.port,'id':uuid.uuid4().hex,'secret':secrets.token_hex(32),'cert':base64.b64encode(der).decode(),'user':user,'expires':deadline}
        encoded='hapssh1.'+base64.urlsafe_b64encode(json.dumps(code,separators=(',',':')).encode()).decode().rstrip('=')
        with socket.socket() as server:
            server.bind((ip,o.pair_port));server.listen(4);server.settimeout(1)
            emit(ok=True,status='pairing-listening',code=encoded,expires=deadline,authorization='until-revoked',account=user,hostKeyFingerprint=fingerprint(host_key))
            attempts=0
            consumed=False
            while time.time()<deadline and attempts<32:
                try:raw,_=server.accept()
                except socket.timeout:continue
                attempts+=1
                try:
                    raw.settimeout(min(10,max(0.1,deadline-time.time())))
                    with context.wrap_socket(raw,server_side=True) as conn:
                        challenge=secrets.token_hex(32);send_frame(conn,{'challenge':challenge,'session':code['id']})
                        req=read_frame(conn)
                        require(req.get('session')==code['id'] and isinstance(req.get('secret'),str) and hmac.compare_digest(req['secret'],code['secret']),'authentication failed')
                        key=public_key(req.get('publicKey',''))
                        signature=base64.b64decode(req.get('signature',''),validate=True);require(len(signature)<=2048,'signature too large')
                        (temp/'allowed').write_text('hap '+key+'\n');(temp/'signature').write_bytes(signature)
                        command([ssh_tool('ssh-keygen'),'-Y','verify','-f',temp/'allowed','-I','hap','-n','hap-pair-v1','-s',temp/'signature'],input=challenge_bytes(code,challenge,key))
                        require(time.time()<deadline and confirm_pair(key,user,deadline,o.preauthorize),'host confirmation denied or expired')
                        require(time.time()<deadline,'expired')
                        consumed=True
                        peer=enroll(root,auth,key,user,code['id'])
                        send_frame(conn,{'ok':True,'peerId':peer,'hostKey':host_key,'user':user,'authorization':'until-revoked'})
                        return {'ok':True,'status':'paired','peerId':peer,'pairReady':True,'sshAuthenticated':False,'guiSessionVerified':False}
                except (ValueError,KeyError,TypeError,UnicodeError,OSError,ssl.SSLError,subprocess.SubprocessError):
                    raw.close()
                    if consumed:
                        return {'ok':False,'status':'enrollment-interrupted','detail':'Code consumed. Inspect host peers and revoke any registering/active peer before retrying.','pairReady':False}
                    # Never log request, code, keys, or exception details from the wire.
                    print('Pairing attempt rejected.',file=sys.stderr)
                    time.sleep(min(0.25,max(0,deadline-time.time())))
            raise ValueError('pairing expired or attempt limit reached')


def ssh_argv(root, peer):
    data=read_json(root/('client-'+peer+'.json'))
    user_name(data['user']);address(data['ip'])
    require(type(data['port']) is int and 1<=data['port']<=65535,'invalid saved port')
    key=safe_root(root/('key-'+peer));known=safe_root(root/('known-'+peer))
    require(key.is_file() and known.is_file(),'peer key or host identity missing')
    return [ssh_tool('ssh'),'-F','NUL' if os.name=='nt' else '/dev/null','-o','BatchMode=yes','-o','IdentitiesOnly=yes','-o','IdentityAgent=none','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(known),'-o','GlobalKnownHostsFile='+('NUL' if os.name=='nt' else '/dev/null'),'-o','ForwardAgent=no','-o','ForwardX11=no','-o','ClearAllForwardings=yes','-o','ConnectTimeout=10','-i',str(key),'-p',str(data['port']),data['user']+'@'+data['ip']]


def connect(o):
    raw=sys.stdin.readline(8193).strip() if o.code_stdin else o.code
    require(raw,'provide a pairing code or alias')
    root=ssh_state(o.state_root)
    if not raw.startswith('hapssh1.'):
        token(raw);alias=read_json(root/('alias-'+raw+'.json'));peer=alias['peerId'];require(re.fullmatch('[0-9a-f]{32}',peer),'invalid alias peer')
    else:
        code,der=decode_code(raw)
        if o.save:token(o.save);require(not (root/('alias-'+o.save+'.json')).exists(),'alias already exists')
        context=ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT);context.minimum_version=ssl.TLSVersion.TLSv1_2
        context.load_verify_locations(cadata=ssl.DER_cert_to_PEM_cert(der))
        with tempfile.TemporaryDirectory(prefix='.client-',dir=root) as temp:
            temp=Path(temp);key=temp/'key'
            command([ssh_tool('ssh-keygen'),'-q','-t','ed25519','-N','','-f',key])
            pub=public_key((temp/'key.pub').read_text())
            with socket.create_connection((code['ip'],code['port']),timeout=10) as tcp:
                with context.wrap_socket(tcp,server_hostname=code['ip']) as conn:
                    require(hmac.compare_digest(hashlib.sha256(conn.getpeercert(binary_form=True)).digest(),hashlib.sha256(der).digest()),'TLS certificate pin mismatch')
                    challenge=read_frame(conn);require(challenge.get('session')==code['id'] and re.fullmatch('[0-9a-f]{64}',challenge.get('challenge','')),'invalid challenge')
                    data=temp/'challenge';data.write_bytes(challenge_bytes(code,challenge['challenge'],pub))
                    command([ssh_tool('ssh-keygen'),'-Y','sign','-f',key,'-n','hap-pair-v1',data])
                    send_frame(conn,{'session':code['id'],'secret':code['secret'],'publicKey':pub,'signature':base64.b64encode((temp/'challenge.sig').read_bytes()).decode()})
                    conn.settimeout(min(600,max(1,code['expires']-time.time())))
                    result=read_frame(conn);require(result.get('ok') is True and result.get('user')==code['user'],'pairing rejected')
                    hostkey=public_key(result['hostKey']);peer=result['peerId'];require(peer==hashlib.sha256(pub.encode()).hexdigest()[:32],'peer identity mismatch')
            with lock(root,'.client-lock'):
                require(not (root/('client-'+peer+'.json')).exists(),'peer already exists')
                os.rename(key,root/('key-'+peer));os.chmod(root/('key-'+peer),0o600)
                host=code['ip'] if code['sshPort']==22 else '['+code['ip']+']:'+str(code['sshPort'])
                (root/('known-'+peer)).write_text(host+' '+hostkey+'\n');os.chmod(root/('known-'+peer),0o600)
                atomic_json(root/('client-'+peer+'.json'),{'peerId':peer,'ip':code['ip'],'port':code['sshPort'],'user':code['user'],'hostKeyFingerprint':fingerprint(hostkey),'authorization':'until-revoked'})
                if o.save:atomic_json(root/('alias-'+o.save+'.json'),{'peerId':peer})
    if o.no_connect:return {'ok':True,'status':'paired','peerId':peer,'pairReady':True,'sshAuthenticated':False,'guiSessionVerified':False}
    code=subprocess.run(ssh_argv(root,peer)).returncode
    return {'ok':code==0,'status':'session-ended' if code==0 else 'ssh-session-failed','peerId':peer,'exitCode':code,'sshAuthenticated':code==0,'guiSessionVerified':False}


def ssh_main(args):
    if not args:
        require(sys.stdin.isatty(),'choose --pair, conn, peers, revoke or doctor')
        choice=input('1: Generate pairing code  2: Connect to peer\n> ')
        if choice=='1':args=['--pair','--listen',input('LAN IPv4: ').strip()]
        elif choice=='2':args=['conn',input('Code or alias: ').strip()]
        else:raise ValueError('cancelled')
    if args[0]=='--pair':args=['pair',*args[1:]]
    p=argparse.ArgumentParser(prog='hap ssh');sub=p.add_subparsers(dest='action',required=True)
    pair=sub.add_parser('pair');pair.add_argument('--listen',required=True);pair.add_argument('--user');pair.add_argument('--port',type=int,default=22);pair.add_argument('--pair-port',type=int,default=49222)
    pair.add_argument('--ttl',type=lambda x:int(x[:-1])*60 if x.endswith('m') else int(x),default=300);pair.add_argument('--preauthorize',action='store_true');pair.add_argument('--allow-privileged',action='store_true');pair.add_argument('--show-code',action='store_true');pair.add_argument('--host-key')
    con=sub.add_parser('conn');con.add_argument('code',nargs='?');con.add_argument('--code-stdin',action='store_true');con.add_argument('--save');con.add_argument('--no-connect',action='store_true')
    rev=sub.add_parser('revoke');rev.add_argument('peer')
    forget=sub.add_parser('forget');forget.add_argument('alias')
    peers=sub.add_parser('peers');doctor=sub.add_parser('doctor');doctor.add_argument('--target')
    for parser in [pair,con,rev,forget,peers,doctor]:parser.add_argument('--state-root');parser.add_argument('--json',action='store_true')
    o=p.parse_args(args)
    if o.action=='pair':return ssh_pair(o)
    if o.action=='conn':
        require(not (o.code and o.code_stdin),'choose code argument or --code-stdin');return connect(o)
    root=ssh_state(o.state_root,create=False)
    if o.action=='doctor':
        tools={name:bool(shutil.which(name)) for name in ['ssh','ssh-keygen','openssl']}
        versions={};health={}
        for name,flag in [('ssh','-V'),('openssl','version')]:
            if tools[name]:
                observed=subprocess.run([ssh_tool(name),flag],capture_output=True,timeout=10)
                health[name]=observed.returncode==0
                versions[name]=(observed.stderr+observed.stdout).decode('utf-8','replace')[:300].strip()
        result={'ok':True,'status':'diagnosed','host':host_id(),'tools':tools,'healthy':health,'versions':versions,'installReady':health.get('ssh',False),'pairDependenciesReady':all(tools.values()) and all(health.values()),'pairReady':False,'sshAuthenticated':False,'guiSessionVerified':False}
        if os.name=='nt':
            script="$s=Get-CimInstance Win32_Service -Filter \"Name='sshd'\" -ErrorAction SilentlyContinue; if($s){@{state=$s.State;path=$s.PathName;pid=$s.ProcessId;startMode=$s.StartMode;ports=@(Get-NetTCPConnection -State Listen -OwningProcess $s.ProcessId -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort -Unique)} | ConvertTo-Json -Compress}else{'null'}"
            result['service']=json.loads(command(['powershell.exe','-NoProfile','-NonInteractive','-Command',script]))
            result['diagnosticHint']='Entry-point or dependency errors such as 0xC0000139 need binary/path analysis; do not replace random system DLLs.'
        if o.target:
            token(o.target);alias=read_json(root/('alias-'+o.target+'.json'));peer=alias['peerId'];require(re.fullmatch('[0-9a-f]{32}',peer),'invalid peer id')
            saved=read_json(root/('client-'+peer+'.json'))
            result['target']={k:saved[k] for k in ['peerId','ip','port','user','hostKeyFingerprint']}
            result['identityFilesPresent']=(root/('key-'+peer)).is_file() and (root/('known-'+peer)).is_file()
        return result
    if o.action=='peers':
        return {'ok':True,'peers':[{k:v for k,v in read_json(f).items() if k in ('peerId','user','status','ip','authorization','hostKeyFingerprint')} for f in sorted(root.glob('*-*.json')) if f.name.startswith(('host-','client-'))]}
    require(root.exists(),'no SSH state')
    if o.action=='revoke':return revoke(root,o.peer)
    token(o.alias);(root/('alias-'+o.alias+'.json')).unlink()
    return {'ok':True,'status':'alias-forgotten','serverKeyRemoved':False}
