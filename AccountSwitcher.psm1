Set-StrictMode -Version Latest

function Test-AuthPayload {
    param([Parameter(Mandatory)][string]$Payload)
    try { $data = ConvertFrom-Json -InputObject $Payload -ErrorAction Stop } catch { throw '登录文件不是有效 JSON。' }
    if ($data.auth_mode -ne 'chatgpt' -or -not $data.tokens -or
        [string]::IsNullOrWhiteSpace($data.tokens.id_token) -or
        [string]::IsNullOrWhiteSpace($data.tokens.access_token) -or
        [string]::IsNullOrWhiteSpace($data.tokens.refresh_token) -or
        [string]::IsNullOrWhiteSpace($data.tokens.account_id)) {
        throw '登录文件不是受支持的 ChatGPT 登录格式。'
    }
    return [string]$data.tokens.account_id
}

function Get-AuthEmail {
    param([Parameter(Mandatory)][string]$Payload)
    try {
        $data = ConvertFrom-Json -InputObject $Payload -ErrorAction Stop
        $parts = [string]$data.tokens.id_token -split '\.'
        if ($parts.Count -ne 3) { return $null }
        $encoded = $parts[1].Replace('-', '+').Replace('_', '/')
        $encoded = $encoded.PadRight($encoded.Length + ((4 - ($encoded.Length % 4)) % 4), '=')
        $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded)) | ConvertFrom-Json -ErrorAction Stop
        $email = [string]$claims.email
        if ($email.Length -le 254 -and $email -match '^[^@\s]+@[^@\s]+\.[^@\s]+$') { return $email }
    } catch { return $null }
    return $null
}

function Assert-Label([string]$Label) {
    if ($Label -notmatch '^[\p{L}\p{N}_-]{1,32}$') { throw '标签只能包含字母、数字、下划线或连字符，长度 1-32。' }
}

function Assert-RegularFile([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw '拒绝目录或链接路径。' }
}

function Assert-Store([string]$StorePath) {
    if (-not (Test-Path -LiteralPath $StorePath)) { New-Item -ItemType Directory -Path $StorePath -Force | Out-Null }
    $item = Get-Item -LiteralPath $StorePath -Force
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw '账号库路径不可用。' }
}

function Protect-Payload([string]$Payload) {
    Add-Type -AssemblyName System.Security -ErrorAction Stop
    $plain = [Text.Encoding]::UTF8.GetBytes($Payload)
    $sealed = [Security.Cryptography.ProtectedData]::Protect($plain, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    return [Convert]::ToBase64String($sealed)
}

function Unprotect-Payload([string]$Sealed) {
    Add-Type -AssemblyName System.Security -ErrorAction Stop
    $plain = [Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($Sealed), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    return [Text.Encoding]::UTF8.GetString($plain)
}

function Invoke-AtomicReplace([string]$Source, [string]$Destination) {
    $backup = Join-Path (Split-Path $Destination -Parent) ('.replace-backup-' + [guid]::NewGuid().ToString('N'))
    [IO.File]::Move($Destination, $backup)
    try { [IO.File]::Move($Source, $Destination) }
    catch {
        [IO.File]::Move($backup, $Destination)
        throw
    }
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
}

function Write-Profile([string]$Label, [string]$Payload, [string]$StorePath, [bool]$Overwrite) {
    Assert-Label $Label
    Test-AuthPayload $Payload | Out-Null
    Assert-Store $StorePath
    $dest = Join-Path $StorePath "$Label.profile"
    if ((Test-Path -LiteralPath $dest) -and -not $Overwrite) { throw '该标签已经存在。' }
    if (Test-Path -LiteralPath $dest) { Assert-RegularFile $dest }
    $tmp = Join-Path $StorePath ('.pending-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText($tmp, (Protect-Payload $Payload), [Text.Encoding]::ASCII)
        if (Test-Path -LiteralPath $dest) { Invoke-AtomicReplace $tmp $dest }
        else { [IO.File]::Move($tmp, $dest) }
    } finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } }
}

function Save-CurrentProfile {
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$AuthPath, [Parameter(Mandatory)][string]$StorePath)
    Assert-Label $Label
    Assert-RegularFile $AuthPath
    $payload = [IO.File]::ReadAllText($AuthPath)
    Write-Profile $Label $payload $StorePath $false
}

function Get-SavedProfile {
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$StorePath)
    Assert-Label $Label
    $path = Join-Path $StorePath "$Label.profile"
    Assert-RegularFile $path
    $payload = Unprotect-Payload ([IO.File]::ReadAllText($path))
    Test-AuthPayload $payload | Out-Null
    return $payload
}

function Get-ProfileLabels {
    param([Parameter(Mandatory)][string]$StorePath)
    if (-not (Test-Path -LiteralPath $StorePath)) { return @() }
    Assert-Store $StorePath
    return @(Get-ChildItem -LiteralPath $StorePath -File -Filter '*.profile' | ForEach-Object { $_.BaseName })
}

function Switch-SavedProfile {
    param([Parameter(Mandatory)][string]$SourceLabel, [Parameter(Mandatory)][string]$TargetLabel,
          [Parameter(Mandatory)][string]$AuthPath, [Parameter(Mandatory)][string]$StorePath,
          [switch]$SkipProcessCheck)
    Assert-Label $SourceLabel
    Assert-Label $TargetLabel
    if ($SourceLabel -eq $TargetLabel) { throw '源账号和目标账号相同。' }
    if (-not $SkipProcessCheck -and @(Get-Process -Name ChatGPT,codex,codex-code-mode-host -ErrorAction SilentlyContinue).Count -gt 0) {
        throw '请先完全退出 ChatGPT/Codex 桌面应用及正在运行的任务。'
    }
    Assert-RegularFile $AuthPath
    $current = [IO.File]::ReadAllText($AuthPath)
    $currentId = Test-AuthPayload $current
    $savedSource = Get-SavedProfile -Label $SourceLabel -StorePath $StorePath
    if ($currentId -ne (Test-AuthPayload $savedSource)) { throw '当前登录账号与源标签不匹配，已拒绝覆盖。' }
    $target = Get-SavedProfile -Label $TargetLabel -StorePath $StorePath
    $targetId = Test-AuthPayload $target
    if ($currentId -eq $targetId) { throw '两个标签指向同一个账号。' }
    Write-Profile $SourceLabel $current $StorePath $true
    $parent = Split-Path $AuthPath -Parent
    $temp = Join-Path $parent ('.auth-switch-' + [guid]::NewGuid().ToString('N'))
    $backup = Join-Path $StorePath ('recovery-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N') + '.dpapi')
    try {
        [IO.File]::WriteAllText($backup, (Protect-Payload $current), [Text.Encoding]::ASCII)
        [IO.File]::WriteAllText($temp, $target, (New-Object Text.UTF8Encoding($false)))
        Invoke-AtomicReplace $temp $AuthPath
        if ((Test-AuthPayload ([IO.File]::ReadAllText($AuthPath))) -ne $targetId) { throw '切换后校验失败。' }
    } catch {
        $failed = $_
        if (Test-Path -LiteralPath $backup) {
            $restore = Join-Path $parent ('.auth-restore-' + [guid]::NewGuid().ToString('N'))
            try {
                [IO.File]::WriteAllText($restore, (Unprotect-Payload ([IO.File]::ReadAllText($backup))), (New-Object Text.UTF8Encoding($false)))
                Invoke-AtomicReplace $restore $AuthPath
            } finally { if (Test-Path -LiteralPath $restore) { Remove-Item -LiteralPath $restore -Force } }
        }
        throw $failed
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
    return $backup
}

Export-ModuleMember -Function Test-AuthPayload,Get-AuthEmail,Save-CurrentProfile,Get-SavedProfile,Get-ProfileLabels,Switch-SavedProfile
