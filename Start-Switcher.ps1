param([switch]$ValidateUi)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
Import-Module (Join-Path $PSScriptRoot 'AccountSwitcher.psm1') -Force

$authPath = Join-Path $env:USERPROFILE '.codex\auth.json'
$storePath = Join-Path $env:LOCALAPPDATA 'ChatGPTAccountSwitcher\profiles'
$script:currentLabel = $null
$script:selectedTarget = $null
$script:accountCards = @()
$script:trashActionButtons = @()
$script:showTrash = $false
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

$trashButton = New-Object Windows.Forms.Button
$trashButton.Location = New-Object Drawing.Point(18,356)
$trashButton.Size = New-Object Drawing.Size(176,39)
$trashButton.FlatStyle = 'Flat'
$trashButton.FlatAppearance.BorderSize = 0
$trashButton.BackColor = $dark
$trashButton.ForeColor = [Drawing.Color]::White
$trashButton.Text = '▤  查看垃圾箱'
$sidebar.Controls.Add($trashButton)

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
    $pendingError = $false
    try { $pending = Get-PendingProfile -StorePath $storePath } catch { $pending = $null; $pendingError = $true; $status.Text = '恢复记录无法读取：' + $_.Exception.Message }
    $addButton.Enabled = [bool]($running -eq 0 -and $script:currentLabel -and -not $pending -and -not $pendingError)
    $restoreButton.Enabled = [bool]($running -eq 0 -and $pending)
    $switchButton.Enabled = [bool]($running -eq 0 -and -not $pending -and -not $pendingError -and -not $script:showTrash -and $script:currentLabel -and $script:selectedTarget -and ($script:currentLabel -ne $script:selectedTarget))
    foreach ($button in $script:trashActionButtons) {
        $button.Enabled = [bool]($running -eq 0 -and -not $pending -and -not $pendingError -and
            ($script:showTrash -or ($script:currentLabel -and $button.Tag -ne $script:currentLabel)))
    }
    if ($pending) { $addButton.Text = '✓  完成添加并保存' } else { $addButton.Text = '＋  添加下一个账号' }
    if ($pending -and $running -eq 0) { $addButton.Enabled = $true }
    if ($running -gt 0) {
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
    $name.Size = New-Object Drawing.Size(345,25)
    $name.Font = New-Object Drawing.Font('Microsoft YaHei UI',10,[Drawing.FontStyle]::Bold)
    $name.ForeColor = $ink
    $name.AutoEllipsis = $true
    $name.Text = if ($Email) { "$Email · $Label" } else { $Label }
    $name.Tag = $Label
    $card.Controls.Add($name)

    $hint = New-Object Windows.Forms.Label
    $hint.Location = New-Object Drawing.Point(65,38)
    $hint.Size = New-Object Drawing.Size(340,20)
    $hint.ForeColor = $muted
    $hint.Font = New-Object Drawing.Font('Microsoft YaHei UI',8)
    $hint.Text = if ($IsCurrent) { '当前登录' } elseif ($Email) { '点击选择为目标账号' } else { '邮箱不可用 · 点击选择' }
    $hint.Tag = $Label
    $card.Controls.Add($hint)

    $moveButton = New-Object Windows.Forms.Button
    $moveButton.Location = New-Object Drawing.Point(412,18)
    $moveButton.Size = New-Object Drawing.Size(103,31)
    $moveButton.FlatStyle = 'Flat'
    $moveButton.ForeColor = $muted
    $moveButton.Text = '移到垃圾箱'
    $moveButton.Tag = $Label
    $moveButton.Enabled = -not $IsCurrent
    $moveButton.Add_Click({
        try {
            Update-Preflight
            if (-not $this.Enabled) { throw '当前账号或恢复流程中的账号不能移除。' }
            $label = [string]$this.Tag
            $choice = [Windows.Forms.MessageBox]::Show("将 $label 移到加密垃圾箱？`r`n请先完全退出 ChatGPT/Codex；此操作不会删除聊天记录。",'确认移除账号',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning)
            if ($choice -ne [Windows.Forms.DialogResult]::Yes) { return }
            Move-ProfileToTrash -Label $label -AuthPath $authPath -StorePath $storePath | Out-Null
            if ($script:selectedTarget -eq $label) { $script:selectedTarget = $null }
            Refresh-Accounts
            $status.Text = "账号 $label 已移到垃圾箱，可随时恢复。"
        } catch { $status.Text = '移除失败：' + $_.Exception.Message }
    })
    $card.Controls.Add($moveButton)
    $script:trashActionButtons += $moveButton

    $handler = { Select-Target ([string]$this.Tag) }
    $card.Add_Click($handler)
    $icon.Add_Click($handler)
    $name.Add_Click($handler)
    $hint.Add_Click($handler)
    return $card
}

function New-TrashCard($Entry) {
    $card = New-Object Windows.Forms.Panel
    $card.Size = New-Object Drawing.Size(526,67)
    $card.Margin = New-Object Windows.Forms.Padding(0,0,0,9)
    $card.BackColor = [Drawing.Color]::White
    $card.BorderStyle = 'FixedSingle'

    $name = New-Object Windows.Forms.Label
    $name.Location = New-Object Drawing.Point(15,11)
    $name.Size = New-Object Drawing.Size(305,25)
    $name.Font = New-Object Drawing.Font('Microsoft YaHei UI',10,[Drawing.FontStyle]::Bold)
    $name.ForeColor = $ink
    $name.AutoEllipsis = $true
    $name.Text = [string]$Entry.Label
    $card.Controls.Add($name)

    $date = New-Object Windows.Forms.Label
    $date.Location = New-Object Drawing.Point(15,39)
    $date.Size = New-Object Drawing.Size(300,18)
    $date.ForeColor = $muted
    $date.Font = New-Object Drawing.Font('Microsoft YaHei UI',8)
    $date.Text = '移入时间：' + $Entry.DeletedAt.ToString('yyyy-MM-dd HH:mm')
    $card.Controls.Add($date)

    $restore = New-Object Windows.Forms.Button
    $restore.Location = New-Object Drawing.Point(333,18)
    $restore.Size = New-Object Drawing.Size(78,31)
    $restore.FlatStyle = 'Flat'
    $restore.ForeColor = $accent
    $restore.Text = '恢复'
    $restore.Tag = [string]$Entry.Id
    $restore.Add_Click({
        try {
            Update-Preflight
            if (-not $this.Enabled) { throw '请先退出应用并完成正在添加的账号。' }
            Restore-TrashedProfile -Id ([string]$this.Tag) -StorePath $storePath
            Refresh-Accounts
            $status.Text = '账号已恢复到已保存列表。'
        } catch { $status.Text = '恢复失败：' + $_.Exception.Message }
    })
    $card.Controls.Add($restore)
    $script:trashActionButtons += $restore

    $remove = New-Object Windows.Forms.Button
    $remove.Location = New-Object Drawing.Point(418,18)
    $remove.Size = New-Object Drawing.Size(97,31)
    $remove.FlatStyle = 'Flat'
    $remove.ForeColor = [Drawing.Color]::FromArgb(180,60,60)
    $remove.Text = '永久删除'
    $remove.Tag = [string]$Entry.Id
    $remove.Add_Click({
        try {
            Update-Preflight
            if (-not $this.Enabled) { throw '请先退出应用并完成正在添加的账号。' }
            $id = [string]$this.Tag
            $choice = [Windows.Forms.MessageBox]::Show("永久删除垃圾箱中的账号记录？`r`n此操作不能撤销，之后如需切换到该账号须重新登录并保存。",'确认永久删除',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning)
            if ($choice -ne [Windows.Forms.DialogResult]::Yes) { return }
            Remove-TrashedProfile -Id $id -AuthPath $authPath -StorePath $storePath
            Refresh-Accounts
            $status.Text = '已永久删除该账号的加密保存记录。'
        } catch { $status.Text = '删除失败：' + $_.Exception.Message }
    })
    $card.Controls.Add($remove)
    $script:trashActionButtons += $remove
    return $card
}

function Refresh-Accounts {
    $list.Controls.Clear()
    $script:accountCards = @()
    $script:trashActionButtons = @()
    $script:currentLabel = $null
    $currentId = Get-CurrentId
    $labels = @(Get-ProfileLabels -StorePath $storePath)
    if ($script:selectedTarget -and $labels -notcontains $script:selectedTarget) { $script:selectedTarget = $null }
    foreach ($label in $labels) {
        try {
            $payload = Get-SavedProfile -Label $label -StorePath $storePath
            $id = Test-AuthPayload $payload
            $email = Get-AuthEmail -Payload $payload
            $isCurrent = [bool]($currentId -and $currentId -eq $id)
            if ($isCurrent) { $script:currentLabel = $label }
            if (-not $script:showTrash) {
                $card = New-AccountCard $label $email $isCurrent
                $script:accountCards += $card
                [void]$list.Controls.Add($card)
            }
        } catch { $status.Text = "账号 $label 无法读取；请勿切换，先检查本地凭据。" }
    }
    if ($script:showTrash) {
        $heading.Text = '管理已移除的账号'
        $subtitle.Text = '凭据仍加密保存在本机；恢复后才能再次切换。'
        $listTitle.Text = '垃圾箱'
        $trashButton.Text = '←  返回账号列表'
        try {
            $warnings = $null
            $entries = @(Get-TrashedProfiles -StorePath $storePath -WarningAction SilentlyContinue -WarningVariable warnings)
            foreach ($entry in $entries) { [void]$list.Controls.Add((New-TrashCard $entry)) }
            $status.Text = if ($entries.Count) { "垃圾箱中有 $($entries.Count) 个账号；不会自动清空。" } else { '垃圾箱是空的。' }
            if ($warnings) { $status.Text += ' 另有异常记录已跳过。' }
        } catch { $status.Text = '垃圾箱无法读取：' + $_.Exception.Message }
    } else {
        $heading.Text = '选择要使用的账号'
        $subtitle.Text = '邮箱用于辨认；真正的切换校验仍使用账号 ID。'
        $listTitle.Text = '已保存的账号'
        $trashButton.Text = '▤  查看垃圾箱'
        if ($script:accountCards.Count -eq 0) { $status.Text = '还没有保存账号。请先在官方应用登录，再点左侧「保存当前登录」。' }
        else { $status.Text = "已保存 $($script:accountCards.Count) 个账号。邮箱仅用于显示，不参与身份校验。" }
        if ($script:selectedTarget) { Select-Target $script:selectedTarget }
    }
    Update-Preflight
}

$trashButton.Add_Click({
    $script:showTrash = -not $script:showTrash
    Refresh-Accounts
})

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
