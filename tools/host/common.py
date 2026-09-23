"""Shared, bounded host operations embedded in HapCLI."""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import uuid

MAX_BYTES = 1024 ** 3
MAX_FILES = 10000


def require(condition, message):
    if not condition:
        raise ValueError(message)


def emit(**data):
    print(json.dumps(data, ensure_ascii=True), flush=True)


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


class HostCommandError(ValueError):
    def __init__(self, program, code, status='command-failed'):
        self.status = status
        self.program = Path(str(program)).name
        self.code = code
        self.retryable = status in ('command-timeout', 'port-in-use')
        self.next_action = {
            'maintenance-window-required': 'Inspect the existing service and arrange an explicit maintenance window.',
            'existing-service-stopped': 'Inspect the service configuration and dependencies before repair.',
            'port-in-use': 'Select an unused port or inspect the existing listener.',
            'selected-interface-is-not-private': 'Select an interface on an existing private network.',
            'needs-restart': 'Restart the host when convenient, then retry.',
            'jdk-path-encoding-unsupported': 'Choose an ASCII --install-root inside private temporary storage; the current Semeru launcher cannot use this path and no compatible short name exists.',
            'command-timeout': 'Inspect tool health and connectivity before retrying.',
        }.get(status, 'Inspect the selected tool and its local prerequisites before retrying.')
        super().__init__(self.program + ' failed (' + status + ', exit ' + str(code) + ')')


def command(argv, timeout=30, input=None, env=None):
    try:
        p = subprocess.run([str(x) for x in argv], input=input, capture_output=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        raise HostCommandError(argv[0], None, 'command-timeout') from None
    if p.returncode:
        # Extract only fixed diagnostic codes. Never echo argv, wire data or raw stderr.
        known = ('maintenance-window-required', 'existing-service-stopped', 'port-in-use',
                 'selected-interface-is-not-private', 'needs-restart', 'existing-client-unhealthy',
                 'client-verification-failed', 'server-directory-acl-failed', 'host-key-generation-failed',
                 'sshd-config-or-dependency-failed', 'service-start-failed', 'existing-server-data',
                 'component-service-inconsistent', 'existing-firewall-rule')
        detail = p.stderr.decode('utf-8', 'replace')[:8192]
        status = next((x for x in known if re.search(r'(?<![a-z-])'+re.escape(x)+r'(?![a-z-])', detail)), 'command-failed')
        raise HostCommandError(argv[0], p.returncode, status)
    return p.stdout.decode('utf-8', 'replace').strip()


def host_id():
    cpu = {'aarch64':'arm64', 'amd64':'x86_64', 'x64':'x86_64'}.get(platform.machine().lower(), platform.machine().lower())
    return {'Darwin':'darwin', 'Windows':'win32', 'Linux':'linux'}.get(platform.system(), 'unsupported') + '-' + cpu


def no_link(path):
    s = path.lstat()
    require(not stat.S_ISLNK(s.st_mode) and not getattr(s, 'st_file_attributes', 0) & 0x400, 'links/reparse points are not allowed')
    return s


def safe_root(path):
    path = Path(path).expanduser().absolute()
    # These OS-owned aliases are fixed Darwin paths, not arbitrary user links.
    if sys.platform == 'darwin':
        for alias, target in (('/tmp', '/private/tmp'), ('/var', '/private/var')):
            prefix = Path(alias)
            if path == prefix or prefix in path.parents:
                require(prefix.is_symlink() and str(prefix.resolve()) == target, 'unexpected system path alias')
                path = Path(target) / path.relative_to(prefix)
                break
    cur = path
    while True:
        if cur.exists() or cur.is_symlink():
            no_link(cur)
        if cur == cur.parent:
            break
        cur = cur.parent
    return path


def private_root(path):
    path = safe_root(path)
    if path.exists() and os.name != 'nt':
        s = path.stat()
        require(s.st_uid == os.getuid() and s.st_mode & 0o077 == 0, 'private directory must be owned by this user with mode 0700')
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if os.name == 'nt':
        # Limit the new private root to the current account and LocalSystem.
        account = command(['whoami'])
        command(['icacls', str(path), '/inheritance:r', '/grant:r', account + ':(OI)(CI)F', '*S-1-5-18:(OI)(CI)F'])
    return path


def atomic_json(path, data):
    path = Path(path)
    require(not path.is_symlink(), 'receipt is a link')
    temp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        with open(temp, 'x', encoding='utf-8') as f:
            if os.name != 'nt': os.chmod(temp, 0o600)
            json.dump(data, f, ensure_ascii=False, sort_keys=True, indent=2)
            f.flush(); os.fsync(f.fileno())
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


@contextlib.contextmanager
def lock(root, name):
    path = root / name
    try:
        path.mkdir(mode=0o700)
    except FileExistsError:
        raise ValueError('install-lock-busy: inspect owner.json; never remove a lock until its owner has stopped') from None
    owner = path / 'owner.json'
    try:
        atomic_json(owner, {'pid': os.getpid(), 'host': platform.node(), 'createdAt': time.time(),
                            'recovery': 'Confirm the owning process has stopped before removing this lock.'})
        yield
    finally:
        owner.unlink(missing_ok=True)
        path.rmdir()


def read_json(path, limit=4 * 1024 * 1024):
    require(no_link(path).st_size <= limit, 'JSON exceeds size limit')
    def unique(pairs):
        result = {}
        for k, v in pairs:
            require(k not in result, 'duplicate JSON key')
            result[k] = v
        return result
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)


def token(value):
    require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.+-]{0,95}', value) and '..' not in value, 'invalid version or name')
    return value


def relative_name(value):
    require(isinstance(value, str) and 0 < len(value) <= 1024 and '\\' not in value and ':' not in value, 'invalid inventory path')
    require(not any(ord(c) < 32 for c in value), 'control character in path')
    p = PurePosixPath(value)
    require(not p.is_absolute() and all(x not in ('', '.', '..') for x in value.split('/')), 'unsafe relative path')
    require(all(not x.endswith((' ', '.')) and x.split('.')[0].upper() not in {'CON','PRN','AUX','NUL', *('COM'+str(n) for n in range(1,10)), *('LPT'+str(n) for n in range(1,10))} for x in p.parts), 'reserved path')
    return p
