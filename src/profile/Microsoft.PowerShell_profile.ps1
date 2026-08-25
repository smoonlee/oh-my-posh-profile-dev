<#
.SYNOPSIS
    PowerShell profile configuration.
#>

& {
  # PowerShell Modules
  foreach ($moduleName in @('PSReadLine', 'Terminal-Icons')) {
    Import-Module -Name $moduleName -Global -ErrorAction Ignore
  }

  # PSReadLine Configuration
  $setOptionCommand = Get-Command -Name Set-PSReadLineOption -ErrorAction Ignore
  if ($setOptionCommand) {
    $desiredOptions = [ordered]@{
      EditMode = 'Windows'
      PredictionSource = 'History'
      PredictionViewStyle = 'ListView'
      HistoryNoDuplicates = $true
      HistorySearchCursorMovesToEnd = $true
      HistorySaveStyle = 'SaveIncrementally'
      MaximumHistoryCount = 10000
      BellStyle = 'None'
      ShowToolTips = $true
    }

    $options = @{}
    foreach ($name in $desiredOptions.Keys) {
      if ($setOptionCommand.Parameters.ContainsKey($name)) {
        $options[$name] = $desiredOptions[$name]
      }
    }

    Set-PSReadLineOption @options -ErrorAction Ignore

    $keyHandlers = [ordered]@{
      'Tab'            = 'MenuComplete'
      'Shift+Tab'      = 'TabCompletePrevious'
      'UpArrow'        = 'HistorySearchBackward'
      'DownArrow'      = 'HistorySearchForward'
      'Ctrl+r'         = 'ReverseSearchHistory'
      'Ctrl+l'         = 'ClearScreen'
      'Ctrl+f'         = 'AcceptSuggestion'
      'Alt+RightArrow' = 'AcceptNextSuggestionWord'
      'F2'             = 'SwitchPredictionView'
    }

    $setKeyHandlerCommand = Get-Command -Name Set-PSReadLineKeyHandler -ErrorAction Ignore
    if ($setKeyHandlerCommand) {
      $supportedFunctions = @(
        $setKeyHandlerCommand.Parameters['Function'].Attributes |
          Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
          Select-Object -ExpandProperty ValidValues
      )

      foreach ($key in $keyHandlers.Keys) {
        if ($supportedFunctions.Count -eq 0 -or $supportedFunctions -contains $keyHandlers[$key]) {
          Set-PSReadLineKeyHandler -Key $key -Function $keyHandlers[$key] -ErrorAction Ignore
        }
      }
    }
  }

  # Azure CLI Tab Completion
  $argumentCompleterCommand = Get-Command -Name Register-ArgumentCompleter -ErrorAction Ignore
  if ($argumentCompleterCommand -and
    (Get-Command -Name az -ErrorAction Ignore) -and
    $argumentCompleterCommand.Parameters.ContainsKey('Native')) {
    Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
      param($wordToComplete, $commandAst, $cursorPosition)

      $completionFile = New-TemporaryFile
      $variables = @{
        ARGCOMPLETE_USE_TEMPFILES = '1'
        _ARGCOMPLETE_STDOUT_FILENAME = $completionFile.FullName
        COMP_LINE = $commandAst.ToString()
        COMP_POINT = [string]$cursorPosition
        _ARGCOMPLETE = '1'
        _ARGCOMPLETE_SUPPRESS_SPACE = '0'
        _ARGCOMPLETE_IFS = "`n"
        _ARGCOMPLETE_SHELL = 'powershell'
      }

      $previousValues = @{}

      try {
        foreach ($name in $variables.Keys) {
          $previousValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
          [Environment]::SetEnvironmentVariable($name, $variables[$name], 'Process')
        }

        az 2>$null | Out-Null

        Get-Content -LiteralPath $completionFile.FullName -ErrorAction Ignore |
          Sort-Object -Unique |
          ForEach-Object {
          [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
      }
      finally {
        foreach ($name in $previousValues.Keys) {
          [Environment]::SetEnvironmentVariable($name, $previousValues[$name], 'Process')
        }

        Remove-Item -LiteralPath $completionFile.FullName -Force -ErrorAction Ignore
      }
    }
  }
}

# Oh My Posh Configuration
if (Get-Command -Name oh-my-posh -ErrorAction Ignore) {
  $pwshProfileThemePath = Join-Path $env:APPDATA 'PwshProfile\themes\quick-term-cloud.omp.json'

  if (-not (Test-Path -LiteralPath $pwshProfileThemePath -PathType Leaf)) {
    $pwshProfileThemePath = 'https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile-dev/main/src/themes/quick-term-cloud.omp.json'
  }

  oh-my-posh init pwsh --config $pwshProfileThemePath | Invoke-Expression
  Remove-Variable -Name pwshProfileThemePath -ErrorAction Ignore
}
