function Get-AksVersion {
  <#
  .SYNOPSIS
      Gets Kubernetes versions currently available for Azure Kubernetes Service in a region.

  .DESCRIPTION
      Uses Azure CLI to return structured version information from
      `az aks get-versions`. Preview versions are excluded by default. Use
      -IncludePreview to include them. Use -OpenReleaseTracker to open the AKS
      release tracker instead of querying Azure CLI.

  .PARAMETER Location
      Azure region name, such as eastus or australiaeast.

  .PARAMETER Subscription
      Azure subscription name or ID used for this query. When omitted, Azure CLI
      uses its active subscription.

  .PARAMETER IncludePreview
      Include Kubernetes versions marked as preview by AKS.

  .PARAMETER OpenReleaseTracker
      Open the AKS Kubernetes version release tracker in the default browser.

  .EXAMPLE
      Get-AksVersion -Location eastus

  .EXAMPLE
      Get-AksVersion -Location australiaeast -IncludePreview

  .EXAMPLE
      Get-AksVersion -OpenReleaseTracker
  #>
  [CmdletBinding(DefaultParameterSetName = 'Versions')]
  [OutputType([pscustomobject])]
  param (
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Versions')]
    [ValidateNotNullOrEmpty()]
    [string] $Location,

    [Parameter(ParameterSetName = 'Versions')]
    [ValidateNotNullOrEmpty()]
    [string] $Subscription,

    [Parameter(ParameterSetName = 'Versions')]
    [switch] $IncludePreview,

    [Parameter(Mandatory, ParameterSetName = 'ReleaseTracker')]
    [switch] $OpenReleaseTracker
  )

  if ($OpenReleaseTracker) {
    try {
      Start-Process 'https://releases.aks.azure.com/KubernetesVersions' -ErrorAction Stop
    }
    catch {
      Write-Warning "Could not open the AKS release tracker. $($_.Exception.Message)"
    }
    return
  }

  $azCommand = Get-Command -Name az -ErrorAction Ignore
  if (-not $azCommand) {
    throw 'Azure CLI (az) was not found. Install Azure CLI, sign in with az login, then run the command again.'
  }

  $arguments = @(
    'aks', 'get-versions',
    '--location', $Location,
    '--output', 'json',
    '--only-show-errors'
  )
  if ($PSBoundParameters.ContainsKey('Subscription')) {
    $arguments += @('--subscription', $Subscription)
  }

  $output = & $azCommand.Name @arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    $details = ($output | Out-String).Trim()
    if (-not $details) {
      $details = 'Azure CLI did not return an error message.'
    }
    throw "Could not retrieve AKS versions for '$Location'. $details"
  }

  try {
    $result = ($output | Out-String) | ConvertFrom-Json -ErrorAction Stop
  }
  catch {
    throw "Azure CLI returned invalid JSON for AKS versions in '$Location'. $($_.Exception.Message)"
  }

  foreach ($version in @($result.orchestrators)) {
    $isPreview = [bool]$version.isPreview
    if ($isPreview -and -not $IncludePreview) {
      continue
    }

    [pscustomobject][ordered]@{
      Location = $Location
      KubernetesVersion = [string]$version.orchestratorVersion
      IsDefault = [bool]$version.default
      IsPreview = $isPreview
    }
  }
}

Export-ModuleMember -Function Get-AksVersion
