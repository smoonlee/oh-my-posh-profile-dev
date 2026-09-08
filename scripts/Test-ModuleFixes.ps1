[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
foreach ($path in @('src/Invoke-PwshProfileSetup.ps1', 'src/modules/PwshProfile.TlsCertificate/PwshProfile.TlsCertificate.psm1', 'src/modules/PwshProfile.Dns/PwshProfile.Dns.psm1')) {
  $tokens = $null; $errors = $null
  $null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo $path), [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw ($errors | Out-String) }
}
Import-Module (Join-Path $repo 'src/modules/PwshProfile.TlsCertificate/PwshProfile.TlsCertificate.psd1') -Force
Import-Module (Join-Path $repo 'src/modules/PwshProfile.Dns/PwshProfile.Dns.psd1') -Force
$root = Join-Path ([IO.Path]::GetTempPath()) ('module-fixes-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
  try { & $Action; throw 'Expected failure was not raised' }
  catch { if ($_.Exception.Message -notlike $Pattern) { throw } }
}
try {
  $cert = New-SelfSignedTlsCertificate test.invalid -DnsName test.invalid -OutputDirectory $root
  $keyHash = (Get-FileHash $cert.PrivateKeyPath).Hash
  Assert-Throws { New-SelfSignedTlsCertificate test.invalid -OutputDirectory $root } '*Use -Force*'
  if ((Get-FileHash $cert.PrivateKeyPath).Hash -ne $keyHash) { throw 'Key was overwritten' }
  $cert = New-SelfSignedTlsCertificate test.invalid -DnsName test.invalid -OutputDirectory $root -Force
  if ((Get-FileHash $cert.PrivateKeyPath).Hash -eq $keyHash) { throw 'Force did not replace key' }
  $password = ConvertTo-SecureString 'SyntheticRegression42' -AsPlainText -Force
  $pfx = New-PfxCertificate -CertificatePath $cert.CertificatePath -PrivateKeyPath $cert.PrivateKeyPath -Password $password
  $split = Split-PfxCertificate $pfx.OutputPath -Password $password
  $splitHash = (Get-FileHash $split.PrivateKeyPath).Hash
  Assert-Throws { Split-PfxCertificate $pfx.OutputPath -Password $password } '*Use -Force*'
  $wrong = ConvertTo-SecureString 'WrongSyntheticPassword' -AsPlainText -Force
  Assert-Throws { Split-PfxCertificate $pfx.OutputPath -Password $wrong -Force } '*OpenSSL could not*'
  if ((Get-FileHash $split.PrivateKeyPath).Hash -ne $splitHash) { throw 'Failed split changed output' }
  $split = Split-PfxCertificate $pfx.OutputPath -Password $password -Force
  if (-not (Test-CertificateKeyMatch $split.CertificatePath $split.PrivateKeyPath -KeyPassword $password).IsMatch) { throw 'Split key mismatch' }
  $tls = Get-Module PwshProfile.TlsCertificate
  $certificateObject = [Security.Cryptography.X509Certificates.X509Certificate2]::new($pfx.OutputPath, 'SyntheticRegression42')
  try {
    $hash = & $tls { param($cert) Get-TlsCertificateFingerprint $cert } $certificateObject
    if ($hash -ne (Get-TlsCertificate -Path $cert.CertificatePath).Thumbprint) { throw 'Fingerprint mismatch' }
  }
  finally { $certificateObject.Dispose() }
  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  $listener.Start()
  $accept = $listener.AcceptTcpClientAsync()
  $timer = [Diagnostics.Stopwatch]::StartNew()
  try {
    Assert-Throws { Get-TlsCertificate 127.0.0.1 -Port $listener.LocalEndpoint.Port -TimeoutSec 1 } '*timed out*'
    if ($timer.Elapsed.TotalSeconds -gt 5) { throw 'TLS handshake exceeded deadline' }
  }
  finally {
    if ($accept.IsCompleted) { $accept.Result.Dispose() }
    $listener.Stop()
  }
  'PASS: silent TLS endpoint is bounded by timeout.'

  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  $listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = (Get-Command openssl).Source
  $info.UseShellExecute = $false; $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
  foreach ($argument in @('s_server', '-quiet', '-accept', "127.0.0.1:$port", '-cert', $cert.CertificatePath, '-key', $cert.PrivateKeyPath)) { $info.ArgumentList.Add($argument) }
  $server = [Diagnostics.Process]::Start($info)
  $outDrain = $server.StandardOutput.BaseStream.CopyToAsync([IO.Stream]::Null)
  $errDrain = $server.StandardError.BaseStream.CopyToAsync([IO.Stream]::Null)
  try {
    Start-Sleep -Milliseconds 300
    $remote = Get-TlsCertificate 127.0.0.1 -Port $port -ShowChain -TimeoutSec 5
    if ($remote.Thumbprint -ne $hash -or @($remote.Chain).Count -lt 1) { throw 'Live local TLS fingerprint/chain mismatch' }
    'PASS: real loopback TLS handshake, chain data, and matching remote/file fingerprint.'
  }
  finally {
    if (-not $server.HasExited) { $server.Kill(); $null = $server.WaitForExit(1000) }
    $server.Dispose()
  }
  & $tls {
    function script:Get-TlsCertificateFromEndpoint {
      [pscustomobject]@{ Subject = 'test'; Chain = @([pscustomobject]@{ Subject = 'test' }) }
    }
  }
  if (@(Get-TlsCertificate test.invalid -ShowChain).Count -ne 1 -or (Get-TlsCertificate test.invalid -ShowChain).Chain.Count -ne 1) { throw 'Chain not returned' }
  'PASS: overwrite guards, Force, failed split preservation, PFX round trip, SHA256 consistency, chain objects.'
}
finally {
  # This directory contains only this run's synthetic files; never recurse.
  Get-ChildItem -LiteralPath $root -File -Force | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
  Remove-Item -LiteralPath $root
}

Add-Type 'public enum ModuleTestDnsType { A, TXT }'
$dns = Get-Module PwshProfile.Dns
& $dns {
  function script:Get-Command {
    param($Name)
    if ($Name -eq 'Resolve-DnsName') { return [pscustomobject]@{ Parameters = @{ Type = @{ ParameterType = [ModuleTestDnsType] } } } }
    if ($Name -eq 'dig') { return [pscustomobject]@{ Name = 'Invoke-TestDig' } }
  }
  function script:Resolve-DnsName { throw 'Native resolver should not receive CAA' }
  function script:Invoke-TestDig {
    if ($args -notcontains '@192.0.2.53') { throw 'Server was not preserved' }
    $global:LASTEXITCODE = 0
    ';; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1'
    'example.invalid. 300 IN CAA 0 issue "ca.invalid"'
  }
}
$records = @(Get-DnsResult example.invalid -RecordType CAA -Server 192.0.2.53)
if ($records.Count -ne 1 -or $records[0].Type -ne 'CAA') { throw 'CAA fallback failed' }
& $dns {
  function script:Invoke-TestDig {
    $global:LASTEXITCODE = 0
    ';; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 1'
  }
}
Assert-Throws { Get-DnsResult example.invalid -RecordType CAA } '*NXDOMAIN*'
& $dns {
  function script:Get-Command {
    param($Name)
    if ($Name -eq 'Resolve-DnsName') { [pscustomobject]@{ Parameters = @{ Type = @{ ParameterType = [ModuleTestDnsType] } } } }
  }
}
Assert-Throws { Get-DnsResult example.invalid -RecordType CAA } '*requires*dig*'
& $dns { function script:Resolve-DnsRecordSet { throw 'Synthetic resolver failure' } }
$allOutput = @(try { Get-DnsResult example.invalid -All 3>&1 } catch {
  if ($_.Exception.Message -notlike '*queries failed*') { throw }
})
if (@($allOutput | Where-Object { $_ -is [Management.Automation.WarningRecord] }).Count -ne 9) { throw 'DNS All silently hid errors' }
'PASS: CAA fallback preserves selected resolver; All reports query failures.'
