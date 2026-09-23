"""Installer engine discovery and checksum-bound private installation."""
import tarfile
import zipfile
import urllib.parse


def inventory(root):
    files, seen, count, size = {}, set(), 0, 0
    for base, dirs, names in os.walk(root, followlinks=False):
        for name in dirs + names:
            p = Path(base) / name
            s = no_link(p)
            if os.name != 'nt':
                require(s.st_uid in (0,os.getuid()) and s.st_mode & 0o022 == 0, 'untrusted engine file ownership or permissions')
            rel = p.relative_to(root).as_posix(); relative_name(rel)
            count += 1
            require(count <= MAX_FILES, 'too many engine entries')
            require(rel.casefold() not in seen, 'case collision'); seen.add(rel.casefold())
            require(stat.S_ISREG(s.st_mode) or stat.S_ISDIR(s.st_mode), 'special engine file')
            if stat.S_ISREG(s.st_mode):
                size += s.st_size; require(size <= MAX_BYTES, 'engine exceeds 1 GiB')
                if rel != 'engine.json': files[rel] = digest(p)
    return files


def validate_engine(root, engine, version='', native=True):
    root = safe_root(root)
    if os.name != 'nt':
        require(root.stat().st_mode & 0o022 == 0, 'untrusted writable engine directory')
    m = read_json(root / 'engine.json')
    expected = 'chui.installer-engine.v1' if engine == 'nsis' else 'happub.wix-engine.v1'
    require(m.get('schema') == expected, 'wrong engine schema')
    token(m.get('version', ''))
    require(not version or m['version'] == version, 'engine version conflict')
    require(m.get('host') == host_id(), 'engine host/architecture mismatch')
    files = m.get('files')
    require(isinstance(files, dict) and 0 < len(files) <= MAX_FILES, 'invalid engine inventory')
    for name, sha in files.items():
        relative_name(name)
        require(isinstance(sha, str) and re.fullmatch('[0-9a-f]{64}', sha), 'invalid file digest')
    require(inventory(root) == files, 'engine inventory or SHA-256 mismatch')
    entry = ('makensis.exe' if os.name == 'nt' else 'makensis') if engine == 'nsis' else 'wix.exe'
    require(entry in files, 'fixed compiler entry missing')
    if engine == 'nsis':
        require(m.get('engine','canghui-package') == 'canghui-package' and m.get('backend','NSIS') == 'NSIS', 'wrong engine identity')
        require('COPYING' in files, 'NSIS license missing')
        for part in ['Stubs', 'Include', 'Contrib', 'Plugins']:
            require(any(n.startswith(part + '/') for n in files), 'NSIS data directory missing: ' + part)
    else:
        require(os.name == 'nt', 'WiX native execution requires Windows')
        require(any(n.upper().startswith(('LICENSE','COPYING')) for n in files), 'WiX license missing')
    declared = m.get('targetArchitectures', [])
    require(isinstance(declared, list) and all(isinstance(x, str) and re.fullmatch('[a-z0-9_-]{1,48}', x) for x in declared) and len(set(declared)) == len(declared), 'invalid declared target list')
    observed = ''
    if native:
        env=dict(os.environ)
        if engine=='nsis':
            env['NSISDIR']=str(root);env.pop('NSISCONFDIR',None)
        observed = command([str(root / entry), '/NOCONFIG', '/VERSION'] if engine == 'nsis' and os.name == 'nt' else
                           [str(root / entry), '-NOCONFIG', '-VERSION'] if engine == 'nsis' else [str(root / entry), '--version'], env=env)
        require(re.search(r'(?<![\d.])v?' + re.escape(m['version']) + r'(?![\d.])', observed), 'compiler reported different version')
    return {'schema':'happub-installer-receipt-v1', 'ok':True, 'engine':engine, 'version':m['version'],
            'host':m['host'], 'targetArchitectures':[], 'declaredTargets':declared, 'verifiedTargets':[], 'verificationLevel':'inventory+native-probe' if native else 'inventory', 'bundleRoot':str(root), 'entry':str(root / entry),
            'manifestSha256':digest(root / 'engine.json'), 'inventoryVerified':True, 'nativeToolsVerified':native,
            'observedVersion':observed, 'honorVerified':False, 'windowsExecutionVerified':False}


def extract_engine(archive, destination):
    entries, seen, total = [], set(), 0
    if zipfile.is_zipfile(archive):
        handle = zipfile.ZipFile(archive)
        items = [(i.filename.rstrip('/'), i.is_dir(), i.file_size, (i.external_attr >> 16), i) for i in handle.infolist()]
    else:
        handle = tarfile.open(archive, 'r:*')
        items = [(i.name.rstrip('/'), i.isdir(), i.size, 0o040755 if i.isdir() else 0o100644 if i.isfile() else 0, i) for i in handle.getmembers()]
    with handle:
        require(len(items) <= MAX_FILES, 'too many archive entries')
        for name, directory, size, mode, obj in items:
            relative_name(name)
            require(name.casefold() not in seen, 'duplicate/colliding archive path'); seen.add(name.casefold())
            kind=stat.S_IFMT(mode)
            require(kind in (0,stat.S_IFREG,stat.S_IFDIR) and (not isinstance(handle,tarfile.TarFile) or mode!=0), 'archive links/special files rejected')
            total += size; require(0 <= total <= MAX_BYTES, 'archive exceeds 1 GiB')
            entries.append((name, directory, size, obj))
        # Preflight file/directory ancestors before writing anything.
        file_names = {n.casefold() for n,d,_,_ in entries if not d}
        for name, _, _, _ in entries:
            require(not any(str(p).casefold() in file_names for p in PurePosixPath(name).parents if str(p) != '.'), 'file used as parent')
        destination.mkdir(mode=0o700)
        for name, directory, size, obj in entries:
            path = destination.joinpath(*PurePosixPath(name).parts)
            if directory: path.mkdir(parents=True, exist_ok=True); continue
            path.parent.mkdir(parents=True, exist_ok=True)
            reader = handle.open(obj) if isinstance(handle, zipfile.ZipFile) else handle.extractfile(obj)
            with reader as src, open(path, 'xb') as dst:
                count = 0
                while block := src.read(1024 * 1024):
                    count += len(block); require(count <= size, 'archive member exceeds declared size'); dst.write(block)
                require(count == size, 'truncated member')
            executable = (obj.external_attr >> 16) & 0o111 if isinstance(handle, zipfile.ZipFile) else obj.mode & 0o111
            path.chmod(0o755 if executable else 0o644)


def installer_main(args):
    p = argparse.ArgumentParser(prog='hap installer')
    if args[:1] == ['inspect']:
        p.add_argument('action'); p.add_argument('--engine', choices=['nsis','wix'], required=True)
        p.add_argument('--bundle'); p.add_argument('--version', default=''); p.add_argument('--json', action='store_true')
        o=p.parse_args(args)
        if o.bundle: return validate_engine(Path(o.bundle), o.engine, o.version)
        entry = shutil.which('makensis' if o.engine == 'nsis' else 'wix')
        return {'ok':True, 'status':'detected-unmanaged' if entry else 'not-installed', 'host':host_id(), 'engine':o.engine,
                'entry':entry, 'managed':False, 'inventoryVerified':False, 'nativeToolsVerified':False,
                'detail':'Unmanaged paths are discovered only; use --bundle to verify and run a trusted engine.'}
    p.add_argument('engine', choices=['nsis','wix']); p.add_argument('--version', required=True)
    source=p.add_mutually_exclusive_group(); source.add_argument('--archive'); source.add_argument('--url')
    p.add_argument('--sha256', required=True); p.add_argument('--install-root', default=str(Path.home()/'.hap'/'engines'))
    p.add_argument('--plan', action='store_true'); p.add_argument('--offline', action='store_true'); p.add_argument('--json', action='store_true')
    o=p.parse_args(args); token(o.version)
    require(re.fullmatch('[0-9a-f]{64}', o.sha256), 'expected lowercase SHA-256')
    if o.url:
        u=urllib.parse.urlsplit(o.url)
        require(u.scheme == 'https' and u.hostname and not u.username and not u.password and not u.fragment, 'HTTPS URL required without credentials/fragment')
    root=safe_root(o.install_root)
    require(root != Path(root.anchor) and root != Path.home(), 'choose a dedicated private tool root')
    if o.plan: return {'ok':True,'status':'planned','host':host_id(),'engine':o.engine,'version':o.version,'networkActionTaken':False,'installed':False}
    root=private_root(root)
    final=root/(o.engine+'-'+o.version+'-'+host_id()+'-'+o.sha256)
    with lock(root,'.install-lock'):
        if final.exists():
            r=validate_engine(final/'bundle',o.engine,o.version)
            old=read_json(final/'receipt.json'); require(old.get('archiveSha256')==o.sha256,'receipt archive mismatch')
            r.update(status='verified-cache-hit',archiveSha256=o.sha256,cacheHit=True,receipt=str(final/'receipt.json'))
            return r
        require(not o.offline or o.archive, 'offline-cache-miss: supply a local --archive and its --sha256 for first import')
        require(o.archive or o.url, 'provide --archive or --url for this fixed, reviewed engine pack')
        stage=Path(tempfile.mkdtemp(prefix='.stage-',dir=root))
        try:
            archive=stage/'archive'
            if o.archive:
                origin=Path(o.archive); require(no_link(origin).st_size<=MAX_BYTES,'archive too large'); shutil.copyfile(origin,archive)
            else:
                command(['curl','--disable','--proto','=https','--proto-redir','=https','--fail','--location','--silent','--show-error','--connect-timeout','10','--max-time','900','--speed-limit','16384','--speed-time','15','--max-filesize',str(MAX_BYTES),'--output',str(archive),o.url],timeout=920)
            require(digest(archive)==o.sha256,'archive SHA-256 mismatch')
            extract_engine(archive,stage/'bundle'); archive.unlink()
            r=validate_engine(stage/'bundle',o.engine,o.version)
            r.update(status='installed',archiveSha256=o.sha256,cacheHit=False,receipt=str(final/'receipt.json'),bundleRoot=str(final/'bundle'),entry=str(final/'bundle'/Path(r['entry']).name))
            atomic_json(stage/'receipt.json',r)
            os.rename(stage,final)
            return r
        finally:
            if stage.exists(): shutil.rmtree(stage)
