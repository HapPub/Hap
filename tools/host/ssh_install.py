"""Windows optional-component provisioning without implicit elevation."""
WINDOWS_SSH = r'''
$ErrorActionPreference='Stop'
$o=[Console]::In.ReadToEnd() | ConvertFrom-Json
$admin=(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$ssh=Join-Path $env:WINDIR 'System32\OpenSSH\ssh.exe'
$sshd=Join-Path $env:WINDIR 'System32\OpenSSH\sshd.exe'
$service=Get-Service sshd -ErrorAction SilentlyContinue
if ($o.server -and $service -and $service.Status -eq 'Running') {
  $serviceInfo=Get-CimInstance Win32_Service -Filter "Name='sshd'"
  $listeners=@(Get-NetTCPConnection -State Listen -OwningProcess $serviceInfo.ProcessId -ErrorAction SilentlyContinue)
  if (!($listeners | Where-Object LocalPort -eq $o.port)) { throw 'maintenance-window-required: existing service uses another port' }
  $ErrorActionPreference='Continue'
  & $ssh -V 2>&1 | Out-Null
  $nativeExit=$LASTEXITCODE
  $ErrorActionPreference='Stop'
  if ($nativeExit -ne 0) { throw 'existing-client-unhealthy' }
  @{ok=$true;status='existing-service-reused';installReady=$true;pairReady=$false;serviceChanged=$false;firewallChanged=$false;sshAuthenticated=$false;guiSessionVerified=$false} | ConvertTo-Json -Compress
  exit 0
}
if (!$o.server -and (Test-Path $ssh)) {
  $ErrorActionPreference='Continue'
  & $ssh -V 2>&1 | Out-Null
  $nativeExit=$LASTEXITCODE
  $ErrorActionPreference='Stop'
  if ($nativeExit -eq 0) {
    @{ok=$true;status='client-reused';installReady=$true;serverEnabled=$false} | ConvertTo-Json -Compress;exit 0
  }
  throw 'existing-client-unhealthy: inspect dependencies before selecting Microsoft Win32-OpenSSH replacement'
}
if (!$admin) {
  @{ok=$false;status='needs-elevation';scope=$(if($o.server){'OpenSSH component, service and Private LAN firewall rule'}else{'OpenSSH client component'});installReady=$false} | ConvertTo-Json -Compress;exit 0
}
if (!$o.server) {
  $result=Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
  if ($result.RestartNeeded) { @{ok=$false;status='needs-restart';installReady=$false} | ConvertTo-Json -Compress;exit 0 }
  $ErrorActionPreference='Continue'
  & $ssh -V 2>&1 | Out-Null
  $nativeExit=$LASTEXITCODE
  $ErrorActionPreference='Stop'
  if ($nativeExit -ne 0) { throw 'client-verification-failed' }
  @{ok=$true;status='client-installed';installReady=$true;serverEnabled=$false} | ConvertTo-Json -Compress;exit 0
}
$ip=Get-NetIPAddress -AddressFamily IPv4 -IPAddress $o.listen
$profile=Get-NetConnectionProfile -InterfaceIndex $ip.InterfaceIndex
if ($profile.NetworkCategory -ne 'Private') { throw 'selected-interface-is-not-private' }
if (Get-NetTCPConnection -State Listen -LocalPort $o.port -ErrorAction SilentlyContinue) { throw 'port-in-use' }
if (Get-NetTCPConnection -State Established -LocalPort $o.port -ErrorAction SilentlyContinue) { throw 'maintenance-window-required' }
# Existing stopped services may belong to other work. Do not reinstall or reconfigure them.
if ($service) { throw 'existing-service-stopped: inspect service path, sshd -t and dependency health; schedule explicit maintenance' }
$base=Join-Path $env:ProgramData 'ssh'
if (Test-Path $base) { throw 'existing-server-data: preserve configuration and keys; explicit maintenance is required' }
$prior=Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
if ($prior.State -eq 'Installed') { throw 'component-service-inconsistent: diagnose before repair' }
$defaultRule=Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue
if ($defaultRule) { throw 'existing-firewall-rule: explicit maintenance is required' }
$rule='Hap-SSH-'+[Guid]::NewGuid().ToString('N')
$added=$false
try {
  $result=Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
  $added=$true
  # A newly installed optional component creates a broad default rule. No service
  # is started until it is disabled and our interface/subnet-limited rule exists.
  Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue | Disable-NetFirewallRule | Out-Null
  if ($result.RestartNeeded) { throw 'needs-restart' }
  New-Item -ItemType Directory -Path $base -Force | Out-Null
  & icacls.exe $base /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'server-directory-acl-failed' }
  $config=Join-Path $base 'sshd_config'
  @("Port $($o.port)","ListenAddress $($o.listen)",'PubkeyAuthentication yes','PasswordAuthentication no','KbdInteractiveAuthentication no','AllowAgentForwarding no','AllowTcpForwarding no','X11Forwarding no','AuthorizedKeysFile .ssh/authorized_keys','Subsystem sftp sftp-server.exe','Match Group administrators','  AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys') | Set-Content -Encoding ascii $config
  & (Join-Path (Split-Path $sshd) 'ssh-keygen.exe') -A
  if ($LASTEXITCODE -ne 0) { throw 'host-key-generation-failed' }
  & $sshd -t -f $config
  if ($LASTEXITCODE -ne 0) { throw 'sshd-config-or-dependency-failed' }
  New-NetFirewallRule -Name $rule -DisplayName 'Hap SSH private subnet' -Direction Inbound -Protocol TCP -LocalPort $o.port -LocalAddress $o.listen -RemoteAddress LocalSubnet -InterfaceAlias $ip.InterfaceAlias -Profile Private -Action Allow | Out-Null
  Set-Service sshd -StartupType $(if($o.autostart){'Automatic'}else{'Manual'})
  Start-Service sshd
  if ((Get-Service sshd).Status -ne 'Running') { throw 'service-start-failed' }
  @{ok=$true;status='server-installed';installReady=$true;pairReady=$false;sshAuthenticated=$false;guiSessionVerified=$false;firewallRule=$rule;autostart=$o.autostart;listen=$o.listen;port=$o.port;authorization='keys persist until revoked'} | ConvertTo-Json -Compress
} catch {
  $failure=$_.Exception.Message
  Remove-NetFirewallRule -Name $rule -ErrorAction SilentlyContinue
  if ($added) {
    Stop-Service sshd -ErrorAction SilentlyContinue
    Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
    Remove-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue
    # Do not destroy newly generated host keys. Retain a protected failure backup.
    if (Test-Path $base) { Move-Item $base ($base+'.hap-failed-'+[Guid]::NewGuid().ToString('N')) }
  }
  throw $failure
}
'''


def ssh_get(args):
    p=argparse.ArgumentParser(prog='hap get ssh')
    p.add_argument('--server',action='store_true');p.add_argument('--provider',choices=['auto','system'],default='auto')
    p.add_argument('--port',type=int,default=22);p.add_argument('--listen');p.add_argument('--firewall',choices=['private-subnet'],default='private-subnet')
    p.add_argument('--no-autostart',action='store_true');p.add_argument('--plan',action='store_true');p.add_argument('--json',action='store_true')
    o=p.parse_args(args);require(1<=o.port<=65535,'invalid port')
    if o.listen:address(o.listen)
    if o.plan:return {'ok':True,'status':'planned','host':host_id(),'serverRequested':o.server,'networkActionTaken':False,'installed':False,'needsElevation':os.name=='nt','firewall':o.firewall if o.server else None,'autostart':o.server and not o.no_autostart}
    if os.name=='nt':
        require(not o.server or o.listen,'server installation requires --listen <selected private LAN IPv4>')
        script=base64.b64encode(WINDOWS_SSH.encode('utf-16-le')).decode()
        result=command(['powershell.exe','-NoProfile','-NonInteractive','-EncodedCommand',script],timeout=600,input=json.dumps({'server':o.server,'listen':o.listen,'port':o.port,'autostart':not o.no_autostart}).encode())
        return json.loads(result)
    ssh=ssh_tool('ssh');p=subprocess.run([ssh,'-V'],capture_output=True,timeout=10)
    require(p.returncode==0,'existing SSH client is unhealthy')
    require(not o.server,'server setup on this platform requires its native service manager; no service changes made')
    return {'ok':True,'status':'client-reused','entry':ssh,'observedVersion':(p.stderr+p.stdout).decode('utf-8','replace').strip(),'installReady':True,'serverEnabled':False}
