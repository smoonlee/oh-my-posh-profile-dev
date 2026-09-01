function Get-DnsRecordDataText {
  # Normalizes the record-specific payload from Resolve-DnsName into a single display string.
  param (
    [Parameter(Mandatory)]
    [object] $Record
  )

  switch ([string]$Record.Type) {
    'A' { return [string]$Record.IPAddress }
    'AAAA' { return [string]$Record.IPAddress }
    'CNAME' { return [string]$Record.NameHost }
    'NS' { return [string]$Record.NameHost }
    'PTR' { return [string]$Record.NameHost }
    'MX' { return "$($Record.NameExchange) (Preference: $($Record.Preference))" }
    'TXT' { return ([string[]]$Record.Strings -join ' ') }
    'SOA' { return "$($Record.PrimaryServer) $($Record.NameAdministrator) (Serial: $($Record.SerialNumber))" }
    'SRV' { return "$($Record.NameTarget):$($Record.Port) (Priority: $($Record.Priority), Weight: $($Record.Weight))" }
    'CAA' { return "$($Record.Tag)=$($Record.Value)" }
    default { return $Record.ToString() }
  }
}

function Get-DnsResultViaDig {
  # Fallback for platforms without the Windows DnsClient module (Resolve-DnsName).
  param (
    [Parameter(Mandatory)]
    [string] $Domain,

    [Parameter(Mandatory)]
    [string] $RecordType,

    [string] $Server
  )

  $digCommand = Get-Command -Name dig -ErrorAction Ignore
  if (-not $digCommand) {
    throw "DNS resolution requires Resolve-DnsName (Windows) or 'dig' (Linux/macOS), and neither was found."
  }

  $digArguments = @('+noall', '+answer')
  if ($Server) {
    $digArguments = @("@$Server") + $digArguments
  }
  $digArguments += @($Domain, $RecordType)

  $output = & $digCommand.Name @digArguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "dig could not resolve '$Domain' ($RecordType). $(($output | Out-String).Trim())"
  }

  foreach ($line in @($output)) {
    if ([string]$line -match '^(?<name>\S+)\s+(?<ttl>\d+)\s+(?<class>\S+)\s+(?<type>\S+)\s+(?<data>.+)$') {
      [pscustomobject][ordered]@{
        PSTypeName = 'PwshProfile.Dns.Result'
        Name = $Matches.name.TrimEnd('.')
        Type = $Matches.type
        TTL = [int]$Matches.ttl
        Section = 'Answer'
        Data = $Matches.data.Trim()
      }
    }
  }
}

function Resolve-DnsRecordSet {
  # Resolves a single record type for a domain, throwing on failure.
  param (
    [Parameter(Mandatory)]
    [string] $Domain,

    [Parameter(Mandatory)]
    [string] $RecordType,

    [string] $Server
  )

  $resolveCommand = Get-Command -Name Resolve-DnsName -ErrorAction Ignore
  if (-not $resolveCommand) {
    return @(Get-DnsResultViaDig -Domain $Domain -RecordType $RecordType -Server $Server)
  }

  $resolveParameters = @{
    Name = $Domain
    Type = $RecordType
    ErrorAction = 'Stop'
  }
  if ($Server) {
    $resolveParameters.Server = $Server
  }

  try {
    $records = Resolve-DnsName @resolveParameters
  }
  catch {
    throw "Unable to resolve '$Domain' ($RecordType). $($_.Exception.Message)"
  }

  @(
    foreach ($record in @($records)) {
      # Resolve-DnsName returns an Authority-section SOA record as a "no data" marker
      # when the requested type doesn't exist; that isn't a real answer, so skip it.
      if ([string]$record.Type -eq 'SOA' -and [string]$record.Section -eq 'Authority' -and $RecordType -ne 'SOA') {
        continue
      }

      [pscustomobject][ordered]@{
        PSTypeName = 'PwshProfile.Dns.Result'
        Name = [string]$record.Name
        Type = [string]$record.Type
        TTL = [int]$record.TTL
        Section = [string]$record.Section
        Data = Get-DnsRecordDataText -Record $record
      }
    }
  )
}

function Get-DnsResult {
  <#
  .SYNOPSIS
      Queries DNS records for a domain.

  .DESCRIPTION
      Resolves DNS records for a domain using Resolve-DnsName on Windows, or
      falls back to 'dig' when Resolve-DnsName is not available (Linux/macOS).
      Use -All to query every common record type and print a grouped
      breakdown, one table per record type that has results.

  .PARAMETER Domain
      Domain name to query, such as example.com.

  .PARAMETER RecordType
      DNS record type to query. Defaults to A.

  .PARAMETER All
      Query every common record type (A, AAAA, CNAME, MX, NS, TXT, SOA, CAA,
      SRV) and print a grouped breakdown, one table per type that has results.
      Cannot be combined with -RecordType.

  .PARAMETER Server
      DNS server to query. When omitted, the system default resolver is used.

  .EXAMPLE
      Get-DnsResult -Domain example.com

  .EXAMPLE
      Get-DnsResult -Domain https://example.com

  .EXAMPLE
      Get-DnsResult -Domain example.com -RecordType MX

  .EXAMPLE
      Get-DnsResult -Domain example.com -RecordType NS -Server 1.1.1.1

  .EXAMPLE
      Get-DnsResult -Domain example.com -All
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $Domain,

    [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'NS', 'PTR', 'SOA', 'SRV', 'TXT', 'CAA')]
    [string] $RecordType = 'A',

    [switch] $All,

    [ValidateNotNullOrEmpty()]
    [string] $Server
  )

  if ($All -and $PSBoundParameters.ContainsKey('RecordType')) {
    throw '-All cannot be combined with -RecordType.'
  }

  $resolvedDomain = $Domain
  if ($resolvedDomain -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
    try {
      $resolvedDomain = ([uri]$resolvedDomain).Host
    }
    catch {
      throw "'$Domain' could not be parsed as a domain name or URL."
    }
  }

  if ($All) {
    $allRecordTypes = @('A', 'AAAA', 'CNAME', 'MX', 'NS', 'TXT', 'SOA', 'CAA', 'SRV')
    $foundAnyRecords = $false
    foreach ($type in $allRecordTypes) {
      $typeRecords = @(
        try {
          Resolve-DnsRecordSet -Domain $resolvedDomain -RecordType $type -Server $Server
        }
        catch {
          @()
        }
      )
      if ($typeRecords.Count -eq 0) {
        continue
      }

      $foundAnyRecords = $true
      Write-Host $type
      $typeRecords | Format-Table | Out-Host
    }

    if (-not $foundAnyRecords) {
      throw "No DNS records were found for '$Domain'. Confirm the domain name is correct."
    }

    return
  }

  Resolve-DnsRecordSet -Domain $resolvedDomain -RecordType $RecordType -Server $Server
}

Export-ModuleMember -Function Get-DnsResult
