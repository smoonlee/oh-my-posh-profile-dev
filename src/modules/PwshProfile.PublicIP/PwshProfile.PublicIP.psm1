function Get-PublicIP {
  <#
  .SYNOPSIS
      Gets public IP and location information reported by ipinfo.io.

  .DESCRIPTION
      Queries ipinfo.io over HTTPS and returns an object containing the public
      IP address, hostname, ISP, city, region, and country.

  .EXAMPLE
      Get-PublicIP

      Gets public IP information using the default three-second timeout.

  .EXAMPLE
      Get-PublicIP | Format-List

      Displays the returned public IP information as a list.
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    [ValidateRange(1, 60)]
    [int] $TimeoutSec = 3
  )

  try {
    $ipInfo = Invoke-RestMethod `
      -Uri 'https://ipinfo.io' `
      -TimeoutSec $TimeoutSec `
      -ErrorAction Stop
  }
  catch {
    throw "Unable to retrieve public IP information from ipinfo.io. $($_.Exception.Message)"
  }

  $address = $null
  if (-not $ipInfo -or
    -not $ipInfo.ip -or
    -not [System.Net.IPAddress]::TryParse([string]$ipInfo.ip, [ref]$address)) {
    throw 'ipinfo.io returned an invalid IP address.'
  }

  [pscustomobject][ordered]@{
    'Public IP' = $address.ToString()
    'Host Name' = [string]$ipInfo.hostname
    'ISP' = [string]$ipInfo.org
    'City' = [string]$ipInfo.city
    'Region' = [string]$ipInfo.region
    'Country' = [string]$ipInfo.country
  }
}

Export-ModuleMember -Function Get-PublicIP
