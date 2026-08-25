<#

#>

# PowerShell Modules
Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue

# Oh My Posh - Profile for PowerShell
oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile-dev/main/src/themes/quick-term-cloud.omp.json' | Invoke-Expression

# Force a repaint so the themed prompt shows on the very first render, not just after the first Enter
if (Get-Command -Name Invoke-PoshPromptRepaint -ErrorAction SilentlyContinue) {
  Invoke-PoshPromptRepaint
}

# Azure CLI - IntelliSense Pwsh Support
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli&pivots=winget#enable-tab-completion-on-powershell
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
  param($commandName, $wordToComplete, $cursorPosition)
  $completion_file = New-TemporaryFile
  $env:ARGCOMPLETE_USE_TEMPFILES = 1
  $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
  $env:COMP_LINE = $wordToComplete
  $env:COMP_POINT = $cursorPosition
  $env:_ARGCOMPLETE = 1
  $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
  $env:_ARGCOMPLETE_IFS = "`n"
  $env:_ARGCOMPLETE_SHELL = 'powershell'
  az 2>&1 | Out-Null
  Get-Content $completion_file | Sort-Object | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
  }
  Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}
