#!/usr/bin/env python3
"""Real loopback sshd authentication, transfer and revocation using isolated keys."""
import getpass,json,os
from pathlib import Path
import shlex,socket,subprocess,sys,tempfile,time
binary=str(Path(sys.argv[1]).resolve())
def port():
 with socket.socket() as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
def run(args,env,input=None):
 p=subprocess.run([binary,*args],env=env,input=input,capture_output=True,text=True,timeout=30)
 assert p.returncode==0,(p.stdout,p.stderr);return json.loads(p.stdout)
with tempfile.TemporaryDirectory(prefix='hap-ssh-session-') as tmp:
 root=Path(tmp).resolve();sh=root/'server';ch=root/'client'
 for h in [sh,ch]:h.mkdir(mode=0o700)
 se=dict(os.environ,HOME=str(sh));ce=dict(os.environ,HOME=str(ch))
 sshport=port();pairport=port();key=root/'hostkey'
 subprocess.run(['ssh-keygen','-q','-t','ed25519','-N','','-f',str(key)],check=True)
 config=root/'sshd_config';config.write_text(f'Port {sshport}\nListenAddress 127.0.0.1\nHostKey {key}\nPidFile {root}/sshd.pid\nAuthorizedKeysFile {sh}/.ssh/authorized_keys\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nUsePAM no\nStrictModes yes\nAllowUsers {getpass.getuser()}\nLogLevel VERBOSE\nSubsystem sftp internal-sftp\n')
 log=(root/'sshd.log').open('w+')
 daemon=subprocess.Popen(['/usr/sbin/sshd','-D','-e','-f',str(config)],stdout=log,stderr=log)
 server=None
 try:
  time.sleep(.4)
  if daemon.poll() is not None:
   log.seek(0);raise RuntimeError('isolated sshd unavailable: '+log.read())
  server=subprocess.Popen([binary,'ssh','--pair','--listen','127.0.0.1','--port',str(sshport),'--pair-port',str(pairport),'--host-key',str(key)+'.pub','--show-code','--preauthorize','--ttl','60'],env=se,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
  first=json.loads(server.stdout.readline());assert 'code' in first,first
  paired=run(['ssh','conn','--code-stdin','--save','test','--no-connect'],ce,first['code']+'\n');peer=paired['peerId']
  server.communicate(timeout=20);assert server.returncode==0
  state=ch/'.hap/ssh'
  ssh=['ssh','-F','/dev/null','-o','BatchMode=yes','-o','IdentitiesOnly=yes','-o','IdentityAgent=none','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(state/('known-'+peer)),'-i',str(state/('key-'+peer)),'-p',str(sshport),getpass.getuser()+'@127.0.0.1']
  data=os.urandom(16384)
  p=subprocess.run(ssh+['cat'],input=data,capture_output=True,timeout=20);assert p.returncode==0 and p.stdout==data,(p.returncode,p.stderr)
  p=subprocess.run([binary,'ssh','conn','test'],input='exit\n',env=ce,text=True,capture_output=True,timeout=20);assert p.returncode==0,(p.stdout,p.stderr)
  known=state/('known-'+peer);saved=known.read_text()
  # A changed host key must fail, even though the peer name/address are unchanged.
  client_pub=subprocess.check_output(['ssh-keygen','-y','-f',str(state/('key-'+peer))],text=True).strip()
  known.write_text('['+'127.0.0.1'+']:'+str(sshport)+' '+client_pub+'\n')
  denied=subprocess.run([binary,'ssh','conn','test'],input='exit\n',env=ce,text=True,capture_output=True,timeout=20);assert denied.returncode!=0
  known.write_text(saved)
  run(['ssh','revoke',peer],se)
  p=subprocess.run(ssh+['true'],capture_output=True,timeout=20);assert p.returncode==255,p.returncode
  print(json.dumps({'installReady':True,'pairReady':True,'sshAuthenticated':True,'reconnectVerified':True,'transferBytesVerified':len(data),'hostKeyChangeRejected':True,'newConnectionRejectedAfterRevoke':True,'guiSessionVerified':False,'scope':'same-host loopback, isolated sshd'}))
 finally:
  if server and server.poll() is None:server.terminate();server.wait(timeout=10)
  if daemon.poll() is None:daemon.terminate();daemon.wait(timeout=10)
