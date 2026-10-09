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
