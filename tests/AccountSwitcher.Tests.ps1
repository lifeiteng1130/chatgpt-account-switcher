$module = Join-Path (Split-Path $PSScriptRoot -Parent) 'AccountSwitcher.psm1'
Import-Module $module -Force

Describe 'Account profile store' {
    BeforeEach {
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $root = Join-Path $caseRoot 'codex'
        $store = Join-Path $caseRoot 'store'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $auth = Join-Path $root 'auth.json'
        $script:payloadA = '{"auth_mode":"chatgpt","tokens":{"id_token":"a","access_token":"b","refresh_token":"c","account_id":"one"}}'
        $script:payloadB = '{"auth_mode":"chatgpt","tokens":{"id_token":"d","access_token":"e","refresh_token":"f","account_id":"two"}}'
        [IO.File]::WriteAllText($auth, $payloadA)
    }

    It 'rejects malformed auth' {
        { Test-AuthPayload '{"tokens":{}}' } | Should Throw
    }

    It 'rejects unsafe labels' {
        { Save-CurrentProfile -Label '../bad' -AuthPath $auth -StorePath $store } | Should Throw
    }

    It 'encrypts and restores profile under current Windows user' {
        Save-CurrentProfile -Label 'one' -AuthPath $auth -StorePath $store
        $bytes = [IO.File]::ReadAllText((Join-Path $store 'one.profile'))
        $bytes.Contains('access_token') | Should Be $false
        (Get-SavedProfile -Label 'one' -StorePath $store) | Should Be $payloadA
    }

    It 'rejects duplicate labels' {
        Save-CurrentProfile -Label 'one' -AuthPath $auth -StorePath $store
        { Save-CurrentProfile -Label 'one' -AuthPath $auth -StorePath $store } | Should Throw
    }

    It 'switches auth while preserving the departing refreshed profile' {
        Save-CurrentProfile -Label 'one' -AuthPath $auth -StorePath $store
        [IO.File]::WriteAllText($auth, $payloadB)
        Save-CurrentProfile -Label 'two' -AuthPath $auth -StorePath $store
        [IO.File]::WriteAllText($auth, '{"auth_mode":"chatgpt","tokens":{"id_token":"x","access_token":"y","refresh_token":"z","account_id":"one"}}')
        Switch-SavedProfile -SourceLabel 'one' -TargetLabel 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck
        [IO.File]::ReadAllText($auth) | Should Be $payloadB
        [IO.File]::ReadAllBytes($auth)[0] | Should Be 123
        (Get-SavedProfile -Label 'one' -StorePath $store).Contains('"access_token":"y"') | Should Be $true
    }

    It 'rejects source account mismatch' {
        Save-CurrentProfile -Label 'one' -AuthPath $auth -StorePath $store
        [IO.File]::WriteAllText($auth, $payloadB)
        Save-CurrentProfile -Label 'two' -AuthPath $auth -StorePath $store
        { Switch-SavedProfile -SourceLabel 'one' -TargetLabel 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck } | Should Throw
        [IO.File]::ReadAllText($auth) | Should Be $payloadB
    }

    It 'prepares another login without losing the first account' {
        Save-CurrentProfile -Label 'one' -AuthPath $auth -StorePath $store
        Start-AddProfile -SourceLabel 'one' -AuthPath $auth -StorePath $store -SkipProcessCheck
        (Test-Path $auth) | Should Be $false
        (Get-SavedProfile -Label 'one' -StorePath $store) | Should Be $payloadA
        (Get-PendingProfile -StorePath $store).SourceLabel | Should Be 'one'
    }

    It 'rejects completing with the original account and restores it' {
        Save-CurrentProfile -Label 'one' -AuthPath $auth -StorePath $store
        Start-AddProfile -SourceLabel 'one' -AuthPath $auth -StorePath $store -SkipProcessCheck
        [IO.File]::WriteAllText($auth, $payloadA)
        { Complete-AddProfile -Label 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck } | Should Throw
        Restore-PendingProfile -AuthPath $auth -StorePath $store -SkipProcessCheck
        [IO.File]::ReadAllText($auth) | Should Be $payloadA
        (Get-PendingProfile -StorePath $store) | Should BeNullOrEmpty
    }

    It 'saves the second account only after a different login' {
        Save-CurrentProfile -Label 'one' -AuthPath $auth -StorePath $store
        Start-AddProfile -SourceLabel 'one' -AuthPath $auth -StorePath $store -SkipProcessCheck
        [IO.File]::WriteAllText($auth, $payloadB)
        Complete-AddProfile -Label 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck
        (Get-SavedProfile -Label 'two' -StorePath $store) | Should Be $payloadB
        (Get-PendingProfile -StorePath $store) | Should BeNullOrEmpty
    }
}

Describe 'Account email display' {
    function New-FakeToken([string]$Email) {
        $json = '{"email":"' + $Email + '"}'
        $part = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json)).TrimEnd('=').Replace('+','-').Replace('/','_')
        return 'header.' + $part + '.signature'
    }

    It 'reads email from the ID token for display' {
        $payload = '{"auth_mode":"chatgpt","tokens":{"id_token":"' + (New-FakeToken 'person@example.com') + '","access_token":"x","refresh_token":"y","account_id":"one"}}'
        Get-AuthEmail -Payload $payload | Should Be 'person@example.com'
    }

    It 'falls back when the ID token has no usable email' {
        $payload = '{"auth_mode":"chatgpt","tokens":{"id_token":"invalid","access_token":"x","refresh_token":"y","account_id":"one"}}'
        Get-AuthEmail -Payload $payload | Should BeNullOrEmpty
    }

    It 'does not accept an invalid email claim' {
        $payload = '{"auth_mode":"chatgpt","tokens":{"id_token":"' + (New-FakeToken 'not-an-email') + '","access_token":"x","refresh_token":"y","account_id":"one"}}'
        Get-AuthEmail -Payload $payload | Should BeNullOrEmpty
    }
}

Describe 'Account trash' {
    BeforeEach {
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $store = Join-Path $caseRoot 'store'
        $auth = Join-Path $caseRoot 'auth.json'
        $script:accountA = '{"auth_mode":"chatgpt","tokens":{"id_token":"a","access_token":"b","refresh_token":"c","account_id":"one"}}'
        $script:accountB = '{"auth_mode":"chatgpt","tokens":{"id_token":"d","access_token":"e","refresh_token":"f","account_id":"two"}}'
        New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
        [IO.File]::WriteAllText($auth, $accountA)
        Save-CurrentProfile -Label 'one' -AuthPath $auth -StorePath $store
        [IO.File]::WriteAllText($auth, $accountB)
        Save-CurrentProfile -Label 'two' -AuthPath $auth -StorePath $store
        [IO.File]::WriteAllText($auth, $accountA)
    }

    It 'moves only the encrypted saved profile and restores it' {
        $encrypted = [IO.File]::ReadAllText((Join-Path $store 'two.profile'))
        $id = Move-ProfileToTrash -Label 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck
        (Get-ProfileLabels -StorePath $store) -contains 'two' | Should Be $false
        @((Get-TrashedProfiles -StorePath $store)).Count | Should Be 1
        [IO.File]::ReadAllText($auth) | Should Be $accountA
        Restore-TrashedProfile -Id $id -StorePath $store -SkipProcessCheck
        [IO.File]::ReadAllText((Join-Path $store 'two.profile')) | Should Be $encrypted
        @((Get-TrashedProfiles -StorePath $store)).Count | Should Be 0
    }

    It 'refuses the active account or an unreadable current login' {
        { Move-ProfileToTrash -Label 'one' -AuthPath $auth -StorePath $store -SkipProcessCheck } | Should Throw
        [IO.File]::Delete($auth)
        { Move-ProfileToTrash -Label 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck } | Should Throw
        (Get-ProfileLabels -StorePath $store) -contains 'two' | Should Be $true
    }

    It 'blocks deletion while another account is being added' {
        Start-AddProfile -SourceLabel 'one' -AuthPath $auth -StorePath $store -SkipProcessCheck
        { Move-ProfileToTrash -Label 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck } | Should Throw
        (Get-ProfileLabels -StorePath $store) -contains 'two' | Should Be $true
    }

    It 'refuses restore collisions without overwriting either copy' {
        $id = Move-ProfileToTrash -Label 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck
        [IO.File]::WriteAllText($auth, $accountB)
        Save-CurrentProfile -Label 'two' -AuthPath $auth -StorePath $store
        $replacement = [IO.File]::ReadAllText((Join-Path $store 'two.profile'))
        { Restore-TrashedProfile -Id $id -StorePath $store -SkipProcessCheck } | Should Throw
        [IO.File]::ReadAllText((Join-Path $store 'two.profile')) | Should Be $replacement
        @((Get-TrashedProfiles -StorePath $store)).Count | Should Be 1
    }

    It 'permanently removes only the selected trash item' {
        $id = Move-ProfileToTrash -Label 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck
        Remove-TrashedProfile -Id $id -AuthPath $auth -StorePath $store -SkipProcessCheck
        @((Get-TrashedProfiles -StorePath $store)).Count | Should Be 0
        (Get-ProfileLabels -StorePath $store) -contains 'one' | Should Be $true
        [IO.File]::ReadAllText($auth) | Should Be $accountA
        { Remove-TrashedProfile -Id '../one' -AuthPath $auth -StorePath $store -SkipProcessCheck } | Should Throw
    }

    It 'refuses permanent deletion if that account is now the active login' {
        $id = Move-ProfileToTrash -Label 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck
        [IO.File]::WriteAllText($auth, $accountB)
        { Remove-TrashedProfile -Id $id -AuthPath $auth -StorePath $store -SkipProcessCheck } | Should Throw
        @((Get-TrashedProfiles -StorePath $store)).Count | Should Be 1
    }

    It 'keeps valid trash entries visible when one file is malformed' {
        $id = Move-ProfileToTrash -Label 'two' -AuthPath $auth -StorePath $store -SkipProcessCheck
        [IO.File]::WriteAllText((Join-Path (Join-Path $store 'trash') 'broken.profile'), 'invalid')
        $entries = @(Get-TrashedProfiles -StorePath $store -WarningAction SilentlyContinue)
        $entries.Count | Should Be 1
        $entries[0].Id | Should Be $id
    }
}
