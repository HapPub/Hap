"""Windows JDK adapter using the shared private-root, lock and archive contracts."""
def windows_jdk_install(raw):
    require(os.name == 'nt', 'Windows JDK adapter requires a Windows host')
    o = json.loads(raw)
    require(set(o) == {'root','version','requestedVersion','url','archive','sha256','authority','activate','target'}, 'invalid JDK adapter contract')
    token(o['version']); token(o['requestedVersion'])
    require(o['target'] == 'windows-amd64' and host_id() == 'win32-x86_64', 'native Windows x64 JDK required')
    require(re.fullmatch('[0-9a-f]{64}',o['sha256']), 'invalid JDK checksum')
    root = safe_root(o['root'])
    bases = (safe_root(Path.home()/'.hap'), safe_root(tempfile.gettempdir()))
    require(any(root != base and base in root.parents for base in bases), 'JDK root must stay within private HOME/.hap or temporary storage')
    root = private_root(root)
    final = safe_root(root/'jdk'/o['version']/o['target']/('full-'+o['sha256'][:12]))
    requested_major = o['requestedVersion'].removeprefix('jdk-').split('.')[0].split('+')[0]
    require(requested_major in ('11','17','21','25'), 'unsupported Semeru major')

    def verify(payload):
        compilers=list(payload.rglob('javac.exe'))
        require(len(compilers)==1,'JDK must contain exactly one javac.exe')
        home=compilers[0].parent.parent
        require((home/'bin/java.exe').is_file() and (home/'release').is_file(),'incomplete JDK')
        metadata=(home/'release').read_text(encoding='utf-8')
        require('IBM' in metadata or 'Semeru' in metadata,'archive does not identify IBM Semeru')
        versions=re.findall(r'^JAVA_VERSION="([^"]+)"$',metadata,re.M)
        require(len(versions)==1 and versions[0].split('.')[0]==requested_major,'JDK version mismatch')
        command([home/'bin/java.exe','-version'])
        with tempfile.TemporaryDirectory(prefix='.java-smoke-',dir=payload) as smoke:
            smoke=Path(smoke)
            (smoke/'HapSdkSmoke.java').write_text('public class HapSdkSmoke { public static void main(String[] args) { System.out.print("hap-sdk-ok"); } }',encoding='utf-8')
            command([compilers[0],'-d',smoke,smoke/'HapSdkSmoke.java'],timeout=60)
            require(command([home/'bin/java.exe','-cp',smoke,'HapSdkSmoke'],timeout=30)=='hap-sdk-ok','JDK compile/run failed')
        return home,versions[0]

    with lock(root,'.jdk-install-lock'):
        receipt=final/'.hap-receipt.json'
        cached=final.exists()
        if cached:
            previous=read_json(receipt)
            require(previous.get('sha256')==o['sha256'],'cached JDK receipt checksum mismatch')
        else:
            final.parent.mkdir(parents=True,exist_ok=True)
            stage=Path(tempfile.mkdtemp(prefix='.jdk-stage-',dir=final.parent))
            try:
                archive=stage/'archive.zip'
                if o['archive']:
                    origin=Path(o['archive']);require(no_link(origin).st_size<=MAX_BYTES,'JDK archive too large');shutil.copyfile(origin,archive)
                else:
                    url=urllib.parse.urlsplit(o['url'])
                    require(url.scheme=='https' and url.hostname and not url.username and not url.password and not url.fragment,'JDK URL must be HTTPS without credentials')
                    command(['curl.exe','--disable','--proto','=https','--proto-redir','=https','--fail','--location','--silent','--show-error','--connect-timeout','10','--max-time','1800','--speed-limit','16384','--speed-time','15','--output',archive,o['url']],timeout=1820)
                require(digest(archive)==o['sha256'],'JDK archive SHA-256 mismatch')
                require(zipfile.is_zipfile(archive),'Windows JDK requires a ZIP archive')
                extract_engine(archive,stage/'payload');archive.unlink()
                verify(stage/'payload')
                os.rename(stage,final)
                try:verify(final/'payload')
                except BaseException:
                    os.rename(final,stage);raise
            finally:
                if stage.exists():shutil.rmtree(stage)
        home,version=verify(final/'payload')
        def literal(value):return "'"+str(value).replace("'","''")+"'"
        environment='$env:JAVA_HOME='+literal(home)+'\n$env:HAP_JDK_HOME='+literal(home)+'\n$env:PATH='+literal(home/'bin')+'+[IO.Path]::PathSeparator+$env:PATH\n'
        env_file=final/'env.ps1'
        temporary=final/'env.ps1.new';require(not temporary.exists(),'environment staging file already exists')
        temporary.write_text(environment,encoding='utf-8-sig');os.replace(temporary,env_file)
        result={'schema':'happub-sdk-get-v1','ok':True,'status':'installed','subject':'jdk','provider':'semeru',
                'requestedVersion':o['requestedVersion'],'resolvedVersion':o['version'],'observedVersion':version,
                'target':o['target'],'sha256':o['sha256'],'checksumAuthority':o['authority'],'sourceUrl':o['url'],
                'checksumVerified':not cached,'verificationLevel':'native-probe','cacheHit':cached,'nativeToolsVerified':True,
                'installed':True,'activated':False,'shellStartupChanged':False,'finalRoot':str(final),'receipt':str(receipt),
                'activationHint':'. '+literal(env_file),'activationScope':'managed-powershell-script'}
        atomic_json(receipt,result)
        if o['activate']:
            selected=private_root(Path.home()/'.hap')/'env-jdk.ps1'
            if selected.exists() or selected.is_symlink():no_link(selected)
            tmp=selected.with_name('env-jdk-'+uuid.uuid4().hex+'.tmp')
            try:
                tmp.write_text(environment,encoding='utf-8-sig');os.replace(tmp,selected)
            finally:tmp.unlink(missing_ok=True)
            result.update(activated=True,activationHint='. '+literal(selected))
            atomic_json(receipt,result)
        return result
