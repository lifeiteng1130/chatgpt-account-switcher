$root = Split-Path $PSScriptRoot -Parent
Describe 'GUI launcher' {
    It 'parses without syntax errors' {
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Start-Switcher.ps1'), [ref]$null, [ref]$errors)
        $errors.Count | Should Be 0
    }

    It 'constructs the account card UI without switching accounts' {
        $result = & powershell.exe -NoProfile -STA -File (Join-Path $root 'Start-Switcher.ps1') -ValidateUi 2>&1
        ($result -join "`n") | Should Match '^UI_READY cards=\d+$'
    }
}
