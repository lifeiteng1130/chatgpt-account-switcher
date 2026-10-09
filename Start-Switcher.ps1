param([switch]$ValidateUi)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
Import-Module (Join-Path $PSScriptRoot 'AccountSwitcher.psm1') -Force

$authPath = Join-Path $env:USERPROFILE '.codex\auth.json'
$storePath = Join-Path $env:LOCALAPPDATA 'ChatGPTAccountSwitcher\profiles'
$supportedApp = 'C:\Program Files\WindowsApps\OpenAI.Codex_26.1002.7124.0_x64__2p2nqsd0c76g0\app\ChatGPT.exe'
$script:currentLabel = $null
$script:selectedTarget = $null
$script:accountCards = @()
$dark = [Drawing.Color]::FromArgb(32,33,35)
$canvas = [Drawing.Color]::FromArgb(247,247,248)
$ink = [Drawing.Color]::FromArgb(32,33,35)
$muted = [Drawing.Color]::FromArgb(107,114,128)
$accent = [Drawing.Color]::FromArgb(16,163,127)
$paleGreen = [Drawing.Color]::FromArgb(232,247,242)

$form = New-Object Windows.Forms.Form
$form.Text = 'ChatGPT 本地账号切换'
$form.ClientSize = New-Object Drawing.Size(840,560)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = $canvas
$form.Font = New-Object Drawing.Font('Microsoft YaHei UI',10)

$sidebar = New-Object Windows.Forms.Panel
$sidebar.Size = New-Object Drawing.Size(212,560)
$sidebar.BackColor = $dark
$form.Controls.Add($sidebar)

$brand = New-Object Windows.Forms.Label
$brand.Location = New-Object Drawing.Point(22,28)
$brand.Size = New-Object Drawing.Size(174,42)
$brand.Font = New-Object Drawing.Font('Microsoft YaHei UI',15,[Drawing.FontStyle]::Bold)
$brand.ForeColor = [Drawing.Color]::White
$brand.Text = '✦  ChatGPT'
$sidebar.Controls.Add($brand)

$sideCaption = New-Object Windows.Forms.Label
$sideCaption.Location = New-Object Drawing.Point(23,74)
$sideCaption.Size = New-Object Drawing.Size(170,40)
$sideCaption.ForeColor = [Drawing.Color]::Silver
$sideCaption.Font = New-Object Drawing.Font('Microsoft YaHei UI',8)
$sideCaption.Text = "本地账号切换器`r`n仅限当前 Windows 用户"
$sidebar.Controls.Add($sideCaption)

$saveButton = New-Object Windows.Forms.Button
$saveButton.Location = New-Object Drawing.Point(18,142)
$saveButton.Size = New-Object Drawing.Size(176,43)
$saveButton.FlatStyle = 'Flat'
$saveButton.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$saveButton.BackColor = $dark
$saveButton.ForeColor = [Drawing.Color]::White
$saveButton.Text = '＋  保存当前登录'
$sidebar.Controls.Add($saveButton)

$refreshButton = New-Object Windows.Forms.Button
$refreshButton.Location = New-Object Drawing.Point(18,195)
$refreshButton.Size = New-Object Drawing.Size(176,39)
$refreshButton.FlatStyle = 'Flat'
$refreshButton.FlatAppearance.BorderSize = 0
$refreshButton.BackColor = $dark
$refreshButton.ForeColor = [Drawing.Color]::White
$refreshButton.Text = '↻  刷新状态'
$sidebar.Controls.Add($refreshButton)

$addButton = New-Object Windows.Forms.Button
$addButton.Location = New-Object Drawing.Point(18,249)
$addButton.Size = New-Object Drawing.Size(176,43)
$addButton.FlatStyle = 'Flat'
$addButton.FlatAppearance.BorderColor = [Drawing.Color]::Gray
$addButton.BackColor = $dark
$addButton.ForeColor = [Drawing.Color]::White
$addButton.Text = '＋  添加下一个账号'
$sidebar.Controls.Add($addButton)

$restoreButton = New-Object Windows.Forms.Button
$restoreButton.Location = New-Object Drawing.Point(18,303)
$restoreButton.Size = New-Object Drawing.Size(176,39)
$restoreButton.FlatStyle = 'Flat'
$restoreButton.FlatAppearance.BorderSize = 0
$restoreButton.BackColor = $dark
$restoreButton.ForeColor = [Drawing.Color]::White
$restoreButton.Text = '↶  恢复先前账号'
$sidebar.Controls.Add($restoreButton)

$sideNote = New-Object Windows.Forms.Label
$sideNote.Location = New-Object Drawing.Point(22,432)
$sideNote.Size = New-Object Drawing.Size(171,90)
$sideNote.Font = New-Object Drawing.Font('Microsoft YaHei UI',8)
$sideNote.ForeColor = [Drawing.Color]::Silver
$sideNote.Text = "切换前请完全退出`r`nChatGPT / Codex。`r`n本地会话不会被复制或删除。"
$sidebar.Controls.Add($sideNote)

$heading = New-Object Windows.Forms.Label
$heading.Location = New-Object Drawing.Point(244,28)
$heading.Size = New-Object Drawing.Size(550,40)
$heading.Font = New-Object Drawing.Font('Microsoft YaHei UI',18,[Drawing.FontStyle]::Bold)
$heading.ForeColor = $ink
$heading.Text = '选择要使用的账号'
$form.Controls.Add($heading)

$subtitle = New-Object Windows.Forms.Label
$subtitle.Location = New-Object Drawing.Point(246,72)
$subtitle.Size = New-Object Drawing.Size(550,27)
$subtitle.ForeColor = $muted
$subtitle.Text = '邮箱用于辨认；真正的切换校验仍使用账号 ID。'
$form.Controls.Add($subtitle)

$banner = New-Object Windows.Forms.Label
$banner.Location = New-Object Drawing.Point(246,112)
$banner.Size = New-Object Drawing.Size(548,49)
$banner.BackColor = [Drawing.Color]::White
$banner.ForeColor = $ink
$banner.Padding = New-Object Windows.Forms.Padding(13,13,8,8)
$form.Controls.Add($banner)

$listTitle = New-Object Windows.Forms.Label
$listTitle.Location = New-Object Drawing.Point(246,181)
$listTitle.Size = New-Object Drawing.Size(540,26)
$listTitle.Font = New-Object Drawing.Font('Microsoft YaHei UI',11,[Drawing.FontStyle]::Bold)
$listTitle.ForeColor = $ink
$listTitle.Text = '已保存的账号'
$form.Controls.Add($listTitle)

$list = New-Object Windows.Forms.FlowLayoutPanel
$list.Location = New-Object Drawing.Point(246,213)
$list.Size = New-Object Drawing.Size(550,210)
$list.FlowDirection = 'TopDown'
$list.WrapContents = $false
$list.AutoScroll = $true
$list.BackColor = $canvas
$form.Controls.Add($list)

$switchButton = New-Object Windows.Forms.Button
$switchButton.Location = New-Object Drawing.Point(246,442)
$switchButton.Size = New-Object Drawing.Size(187,43)
$switchButton.FlatStyle = 'Flat'
$switchButton.FlatAppearance.BorderSize = 0
$switchButton.BackColor = $accent
$switchButton.ForeColor = [Drawing.Color]::White
$switchButton.Font = New-Object Drawing.Font('Microsoft YaHei UI',10,[Drawing.FontStyle]::Bold)
$switchButton.Text = '切换到所选账号'
$switchButton.Enabled = $false
$form.Controls.Add($switchButton)

$status = New-Object Windows.Forms.Label
$status.Location = New-Object Drawing.Point(246,496)
$status.Size = New-Object Drawing.Size(550,48)
$status.ForeColor = $muted
$status.Font = New-Object Drawing.Font('Microsoft YaHei UI',8)
$form.Controls.Add($status)

function Get-CurrentId {
    if (-not (Test-Path -LiteralPath $authPath)) { return $null }
    try { return (Test-AuthPayload ([IO.File]::ReadAllText($authPath))) }
    catch { return $null }
}

function Update-Preflight {
    $running = @(Get-Process -Name ChatGPT,codex,codex-code-mode-host -ErrorAction SilentlyContinue).Count
    $supported = Test-Path -LiteralPath $supportedApp
    try { $pending = Get-PendingProfile -StorePath $storePath } catch { $pending = $null; $status.Text = '恢复记录无法读取：' + $_.Exception.Message }
    $addButton.Enabled = [bool]($supported -and $running -eq 0 -and $script:currentLabel -and -not $pending)
    $restoreButton.Enabled = [bool]($supported -and $running -eq 0 -and $pending)
    $switchButton.Enabled = [bool]($supported -and $running -eq 0 -and -not $pending -and $script:currentLabel -and $script:selectedTarget -and ($script:currentLabel -ne $script:selectedTarget))
    if ($pending) { $addButton.Text = '✓  完成添加并保存' } else { $addButton.Text = '＋  添加下一个账号' }
    if ($pending -and $supported -and $running -eq 0) { $addButton.Enabled = $true }
    if (-not $supported) {
        $banner.Text = '当前应用版本未通过兼容检查，切换已停用。'
        $banner.BackColor = [Drawing.Color]::FromArgb(255,243,230)
    } elseif ($running -gt 0) {
        $banner.Text = "●  ChatGPT/Codex 仍在运行（$running 个进程），退出后才能切换"
        $banner.BackColor = [Drawing.Color]::FromArgb(255,243,230)
    } elseif ($pending) {
        $banner.Text = '待添加账号：登录新账号后关闭应用，再点击「完成添加并保存」。'
        $banner.BackColor = [Drawing.Color]::FromArgb(255,243,230)
    } elseif (-not $script:currentLabel) {
        $banner.Text = '请先保存当前登录，再选择目标账号。'
        $banner.BackColor = [Drawing.Color]::White
    } else {
        $banner.Text = "●  当前：$($script:currentLabel)    ·    可以选择目标账号"
        $banner.BackColor = $paleGreen
    }
}

function Select-Target([string]$Label) {
    $script:selectedTarget = $Label
    foreach ($card in $script:accountCards) {
        $card.BackColor = if ($card.Tag -eq $Label) { $paleGreen } else { [Drawing.Color]::White }
    }
    Update-Preflight
}

function New-AccountCard([string]$Label,[string]$Email,[bool]$IsCurrent) {
    $card = New-Object Windows.Forms.Panel
    $card.Size = New-Object Drawing.Size(526,67)
    $card.Margin = New-Object Windows.Forms.Padding(0,0,0,9)
    $card.BackColor = [Drawing.Color]::White
    $card.BorderStyle = 'FixedSingle'
    $card.Tag = $Label

    $icon = New-Object Windows.Forms.Label
    $icon.Location = New-Object Drawing.Point(13,14)
    $icon.Size = New-Object Drawing.Size(38,38)
    $icon.BackColor = $accent
    $icon.ForeColor = [Drawing.Color]::White
    $icon.TextAlign = 'MiddleCenter'
    $icon.Font = New-Object Drawing.Font('Microsoft YaHei UI',13,[Drawing.FontStyle]::Bold)
    $icon.Text = if ($Email) { $Email.Substring(0,1).ToUpperInvariant() } else { $Label.Substring(0,1).ToUpperInvariant() }
    $icon.Tag = $Label
    $card.Controls.Add($icon)

    $name = New-Object Windows.Forms.Label
    $name.Location = New-Object Drawing.Point(64,12)
    $name.Size = New-Object Drawing.Size(435,25)
    $name.Font = New-Object Drawing.Font('Microsoft YaHei UI',10,[Drawing.FontStyle]::Bold)
    $name.ForeColor = $ink
    $name.AutoEllipsis = $true
    $name.Text = if ($Email) { "$Email · $Label" } else { $Label }
    $name.Tag = $Label
    $card.Controls.Add($name)

    $hint = New-Object Windows.Forms.Label
    $hint.Location = New-Object Drawing.Point(65,38)
    $hint.Size = New-Object Drawing.Size(390,20)
    $hint.ForeColor = $muted
    $hint.Font = New-Object Drawing.Font('Microsoft YaHei UI',8)
    $hint.Text = if ($IsCurrent) { '当前登录' } elseif ($Email) { '点击选择为目标账号' } else { '邮箱不可用 · 点击选择' }
    $hint.Tag = $Label
    $card.Controls.Add($hint)

    $handler = { Select-Target ([string]$this.Tag) }
    $card.Add_Click($handler)
    $icon.Add_Click($handler)
    $name.Add_Click($handler)
    $hint.Add_Click($handler)
    return $card
}

function Refresh-Accounts {
    $list.Controls.Clear()
    $script:accountCards = @()
    $script:currentLabel = $null
    $currentId = Get-CurrentId
    foreach ($label in (Get-ProfileLabels -StorePath $storePath)) {
        try {
            $payload = Get-SavedProfile -Label $label -StorePath $storePath
            $id = Test-AuthPayload $payload
            $email = Get-AuthEmail -Payload $payload
            $isCurrent = [bool]($currentId -and $currentId -eq $id)
            if ($isCurrent) { $script:currentLabel = $label }
            $card = New-AccountCard $label $email $isCurrent
            $script:accountCards += $card
            [void]$list.Controls.Add($card)
        } catch { $status.Text = "账号 $label 无法读取；请勿切换，先检查本地凭据。" }
    }
    if ($script:accountCards.Count -eq 0) { $status.Text = '还没有保存账号。请先在官方应用登录，再点左侧「保存当前登录」。' }
    else { $status.Text = "已保存 $($script:accountCards.Count) 个账号。邮箱仅用于显示，不参与身份校验。" }
    if ($script:selectedTarget) { Select-Target $script:selectedTarget }
    Update-Preflight
}

$saveButton.Add_Click({
    try {
        $remark = [Microsoft.VisualBasic.Interaction]::InputBox('为当前登录填写备注（例如 work 或 personal；不要输入密码）：','保存当前登录','')
        if ([string]::IsNullOrWhiteSpace($remark)) { return }
        Save-CurrentProfile -Label $remark -AuthPath $authPath -StorePath $storePath
        Refresh-Accounts
        $status.Text = "账号已保存。若登录令牌中有邮箱，卡片会自动显示「邮箱 · $remark」。"
    } catch { $status.Text = '保存失败：' + $_.Exception.Message }
})

$refreshButton.Add_Click({ Refresh-Accounts })

$addButton.Add_Click({
    try {
        Update-Preflight
        if (-not $addButton.Enabled) { throw '请先保存当前账号并完全退出应用。' }
        $pending = Get-PendingProfile -StorePath $storePath
        if ($pending) {
            $remark = [Microsoft.VisualBasic.Interaction]::InputBox('为新账号填写备注（不要输入密码）：','保存新账号','')
            if ([string]::IsNullOrWhiteSpace($remark)) { return }
            Complete-AddProfile -Label $remark -AuthPath $authPath -StorePath $storePath
            Refresh-Accounts
            $status.Text = '新账号已保存。以后可在关闭应用后切换。'
        } else {
            $choice = [Windows.Forms.MessageBox]::Show('将暂时移走当前登录文件，并保留加密恢复记录。随后打开桌面端应出现登录页。若仍自动登录原账号，不要点退出登录，请关闭应用后恢复。继续吗？','添加下一个账号',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning)
            if ($choice -ne [Windows.Forms.DialogResult]::Yes) { return }
            Start-AddProfile -SourceLabel $script:currentLabel -AuthPath $authPath -StorePath $storePath
            Refresh-Accounts
            $status.Text = '现在打开官方应用登录另一个账号。登录后完全退出，再点「完成添加并保存」。'
        }
    } catch { $status.Text = '添加失败：' + $_.Exception.Message }
})

$restoreButton.Add_Click({
    try {
        if (-not $restoreButton.Enabled) { throw '请先完全退出应用。' }
        Restore-PendingProfile -AuthPath $authPath -StorePath $storePath
        Refresh-Accounts
        $status.Text = '原账号登录文件已恢复。请重新打开应用核对账号。'
    } catch { $status.Text = '恢复失败：' + $_.Exception.Message }
})

$switchButton.Add_Click({
    try {
        Update-Preflight
        if (-not $switchButton.Enabled) { throw '当前条件不允许切换。' }
        $from = $script:currentLabel
        $to = $script:selectedTarget
        $choice = [Windows.Forms.MessageBox]::Show("从 $from 切换到 $to？`r`n请确认 ChatGPT/Codex 已完全退出，且没有正在运行的任务。",'确认切换',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning)
        if ($choice -ne [Windows.Forms.DialogResult]::Yes) { return }
        $backup = Switch-SavedProfile -SourceLabel $from -TargetLabel $to -AuthPath $authPath -StorePath $storePath
        Refresh-Accounts
        $status.Text = "登录文件已切换。请从开始菜单打开 ChatGPT 并核对账号。加密恢复副本：$backup"
    } catch { $status.Text = '切换失败：' + $_.Exception.Message }
})

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({ Update-Preflight })
Refresh-Accounts
if ($ValidateUi) {
    "UI_READY cards=$($script:accountCards.Count)"
    $form.Dispose()
    return
}
$timer.Start()
[void]$form.ShowDialog()
$timer.Stop()
$form.Dispose()
