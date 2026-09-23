# Launch one explicitly selected GUI executable in the current account's logged-in
# desktop. Each task has its own directory, scheduler entry, logs and stop marker.
[CmdletBinding()]
param(
  [ValidateSet('launch','status','stop')][string]$Action='status',
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_-]{0,47}$')][string]$TaskId,
  [string]$Executable,
  [ValidateRange(5,3600)][int]$TimeoutSeconds=120
)
$ErrorActionPreference='Stop'
$base=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Hap\desktop'
$root=Join-Path $base $TaskId
$receipt=Join-Path $root 'receipt.json'
$name='HapDesktop-'+$TaskId
$identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name
function Read-Receipt {
  if (!(Test-Path -LiteralPath $receipt)) { return @{taskId=$TaskId;status='pending';guiSessionVerified=$false} }
  return (Get-Content -Raw -LiteralPath $receipt | ConvertFrom-Json)
}
if ($Action -eq 'status') { Read-Receipt | ConvertTo-Json -Depth 5; exit 0 }
if ($Action -eq 'stop') {
  $r=Read-Receipt
  if ($r.owner -ne $identity -or $r.taskId -ne $TaskId) { throw 'task ownership mismatch' }
  New-Item -ItemType File -Path (Join-Path $root 'stop') -Force | Out-Null
  Read-Receipt | ConvertTo-Json -Depth 5
  exit 0
}
if (!(Test-Path -LiteralPath $Executable -PathType Leaf)) { throw 'select an existing GUI executable' }
$Executable=(Resolve-Path -LiteralPath $Executable).Path
if ([IO.Path]::GetExtension($Executable) -ne '.exe') { throw 'only an explicit native .exe is accepted' }
# Require an existing Explorer desktop owned by this account. No logon credentials
# are collected and no autologon setting is changed.
$desktop=@(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" | Where-Object {
  $owner=Invoke-CimMethod -InputObject $_ -MethodName GetOwner
  ($owner.Domain+'\'+$owner.User) -eq $identity
})
if ($desktop.Count -ne 1) { throw 'pending: one logged-in desktop for this account is required' }
if ((Test-Path -LiteralPath $root) -or (Get-ScheduledTask -TaskName $name -TaskPath '\Hap\' -ErrorAction SilentlyContinue)) { throw 'task id already owned; select a fresh id' }
if (Test-Path $base) {
  if ((Get-Item -LiteralPath $base).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'task root cannot be a reparse point' }
}
New-Item -ItemType Directory -Path $root -Force | Out-Null
& icacls.exe $root /inheritance:r /grant:r ($identity+':(OI)(CI)F') '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'private task ACL failed' }
$config=@{taskId=$TaskId;owner=$identity;executable=$Executable;timeout=$TimeoutSeconds;sessionId=$desktop[0].SessionId}
$config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'config.json') -Encoding UTF8
$job=@'
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$c=Get-Content -Raw -LiteralPath (Join-Path $root 'config.json') | ConvertFrom-Json
function Save($data) {
  $tmp=Join-Path $root 'receipt.new.json'
  $data | ConvertTo-Json | Set-Content -LiteralPath $tmp -Encoding UTF8
  Move-Item -LiteralPath $tmp -Destination (Join-Path $root 'receipt.json') -Force
}
$r=@{taskId=$c.taskId;owner=$c.owner;status='starting';guiSessionVerified=$false;sessionId=[Diagnostics.Process]::GetCurrentProcess().SessionId}
Save $r
if ($r.sessionId -ne $c.sessionId) { $r.status='session-mismatch';Save $r;exit 2 }
$p=$null
try {
  $p=Start-Process -FilePath $c.executable -WorkingDirectory ([IO.Path]::GetDirectoryName($c.executable)) -PassThru -RedirectStandardOutput (Join-Path $root 'stdout.log') -RedirectStandardError (Join-Path $root 'stderr.log')
  $started=$p.StartTime.ToUniversalTime().Ticks
  $r.pid=$p.Id;$r.startedTicks=$started;$r.status='running';Save $r
  $deadline=[DateTime]::UtcNow.AddSeconds($c.timeout)
  while (!$p.HasExited -and [DateTime]::UtcNow -lt $deadline -and !(Test-Path -LiteralPath (Join-Path $root 'stop'))) { Start-Sleep -Milliseconds 250;$p.Refresh() }
  if (!$p.HasExited) {
    $current=Get-Process -Id $p.Id -ErrorAction SilentlyContinue
    if ($current -and $current.StartTime.ToUniversalTime().Ticks -eq $started -and $current.Path -eq $c.executable) { Stop-Process -Id $p.Id;$r.status='stopped-owned-process' }
    else { $r.status='ownership-changed-no-kill' }
  } else { $r.status='exited';$r.exitCode=$p.ExitCode }
  Save $r
} catch { $r.status='failed';$r.error=$_.Exception.Message;Save $r;exit 2 }
'@
$jobPath=Join-Path $root 'run.ps1'
$job | Set-Content -LiteralPath $jobPath -Encoding UTF8
$actionSpec=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -NonInteractive -File "'+$jobPath+'"')
$principal=New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Seconds ($TimeoutSeconds+60)) -MultipleInstances IgnoreNew
@{taskId=$TaskId;owner=$identity;status='scheduled';guiSessionVerified=$false} | ConvertTo-Json | Set-Content -LiteralPath $receipt -Encoding UTF8
Register-ScheduledTask -TaskName $name -TaskPath '\Hap\' -Action $actionSpec -Principal $principal -Settings $settings -Description ('Hap desktop task '+$TaskId) | Out-Null
Start-ScheduledTask -TaskName $name -TaskPath '\Hap\'
@{taskId=$TaskId;status='scheduled';owner=$identity;receipt=$receipt;guiSessionVerified=$false;cleanup='After terminal status, unregister only this task under \Hap\; retain logs for review.'} | ConvertTo-Json
