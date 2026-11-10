param([switch]$ValidateUi)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
Import-Module (Join-Path $PSScriptRoot 'AccountSwitcher.psm1') -Force

if (-not ('GlassAccountCard' -as [type])) {
    $glassCs = Join-Path $PSScriptRoot 'LiquidGlass.Controls.cs'
    if (-not (Test-Path -LiteralPath $glassCs)) { throw '缺少 LiquidGlass.Controls.cs，请与 Start-Switcher.ps1 放在同一目录。' }
    $glassDll = Join-Path $PSScriptRoot 'LiquidGlass.Controls.dll'
    $loaded = $false
    if ((Test-Path -LiteralPath $glassDll) -and ((Get-Item -LiteralPath $glassDll).LastWriteTimeUtc -ge (Get-Item -LiteralPath $glassCs).LastWriteTimeUtc)) {
        try { Add-Type -Path $glassDll -ErrorAction Stop; $loaded = $true } catch { }
    }
    if (-not $loaded) {
        $refDrawing = [Drawing.Color].Assembly.Location
        $refForms = [Windows.Forms.Panel].Assembly.Location
        Add-Type -Path $glassCs -ReferencedAssemblies @($refDrawing, $refForms)
    }
}

$authPath = Join-Path $env:USERPROFILE '.codex\auth.json'
$storePath = Join-Path $env:LOCALAPPDATA 'ChatGPTAccountSwitcher\profiles'
$defaultBackgroundPath = Join-Path $PSScriptRoot 'assets\background.png'
$customBackgroundPath = Join-Path $env:LOCALAPPDATA 'ChatGPTAccountSwitcher\background.png'
$script:backgroundPath = if (Test-Path -LiteralPath $customBackgroundPath) { $customBackgroundPath } else { $defaultBackgroundPath }
if (-not [LgPaint]::LoadBackground($script:backgroundPath)) {
    $script:backgroundPath = $defaultBackgroundPath
    [LgPaint]::LoadBackground($script:backgroundPath) | Out-Null
}
$script:currentLabel = $null
$script:selectedTarget = $null
$script:accountCards = @()
$script:trashCards = @()
$script:showTrash = $false
$ink = [LgPaint]::Ink
$muted = [LgPaint]::Muted
$accent = [LgPaint]::Accent
$glassWarnFill = [Drawing.Color]::FromArgb(120, 111, 71, 40)
$glassWarnBorder = [Drawing.Color]::FromArgb(156, 255, 210, 158)
$glassOkFill = [Drawing.Color]::FromArgb(108, 36, 92, 84)
$glassOkBorder = [Drawing.Color]::FromArgb(150, 164, 231, 212)
$glassNeutralFill = [LgPaint]::GlassTint
$glassNeutralBorder = [LgPaint]::GlassEdge

function New-LiquidGlassButton {
    param(
        [string]$Text,
        [int]$X, [int]$Y, [int]$W, [int]$H,
        [switch]$Primary,
        [switch]$DangerStyle
    )
    $b = New-Object GlassButton
    $b.Location = New-Object Drawing.Point($X, $Y)
    $b.Size = New-Object Drawing.Size($W, $H)
    $b.Text = $Text
    $b.IsPrimary = [bool]$Primary
    $b.IsDangerStyle = [bool]$DangerStyle
    $b.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    if ($Primary) {
        $b.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9, [Drawing.FontStyle]::Bold)
        $b.Padding = New-Object Windows.Forms.Padding(12, 0, 8, 0)
    }
    return $b
}

function Set-TransparentLabel($Label) {
    $Label.BackColor = [Drawing.Color]::Transparent
    $Label.ForeColor = $ink
}

$form = New-Object Windows.Forms.Form
$form.Text = 'ChatGPT 本地账号切换'
$form.ClientSize = New-Object Drawing.Size(900, 600)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'None'
$form.MaximizeBox = $false
$form.Opacity = 0
$form.BackColor = [Drawing.Color]::FromArgb(255, 23, 30, 51)
$form.Font = New-Object Drawing.Font('Microsoft YaHei UI', 10)

$backdrop = New-Object GlassBackdropPanel
$backdrop.Dock = 'Fill'
$form.Controls.Add($backdrop)
[LgPaint]::BackdropSource = $backdrop

$root = New-Object Windows.Forms.Panel
$root.Dock = 'Fill'
$root.BackColor = [Drawing.Color]::Transparent
$backdrop.Controls.Add($root)

$titleBar = New-Object Windows.Forms.Panel
$titleBar.Dock = 'Top'
$titleBar.Height = 44
$titleBar.BackColor = [Drawing.Color]::Transparent
$root.Controls.Add($titleBar)

$titleLabel = New-Object Windows.Forms.Label
$titleLabel.Location = New-Object Drawing.Point(20, 12)
$titleLabel.AutoSize = $true
$titleLabel.Font = New-Object Drawing.Font('Microsoft YaHei UI', 10, [Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = $ink
$titleLabel.BackColor = [Drawing.Color]::Transparent
$titleLabel.Text = 'ChatGPT 账号切换器'
$titleBar.Controls.Add($titleLabel)

$closeBtn = New-LiquidGlassButton '✕' 0 8 36 30
$closeBtn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$closeBtn.Padding = New-Object Windows.Forms.Padding(0)
$closeBtn.ForeColor = $muted
$closeBtn.Add_Click({ $form.Close() })
$titleBar.Controls.Add($closeBtn)
$null = $titleBar.Add_Resize({ $closeBtn.Location = New-Object Drawing.Point(($titleBar.Width - 48), 7) })

$script:dragOrigin = $null
foreach ($dragCtl in @($titleBar, $titleLabel)) {
    $dragCtl.Add_MouseDown({ param($s, $e) if ($e.Button -eq 'Left') { $script:dragOrigin = $s.PointToScreen($e.Location) - $form.Location } })
    $dragCtl.Add_MouseMove({ param($s, $e) if ($e.Button -eq 'Left' -and $script:dragOrigin) { $p = $s.PointToScreen($e.Location); $form.Location = New-Object Drawing.Point(($p.X - $script:dragOrigin.X), ($p.Y - $script:dragOrigin.Y)) } })
    $dragCtl.Add_MouseUp({ $script:dragOrigin = $null })
}

$body = New-Object Windows.Forms.Panel
$body.Location = New-Object Drawing.Point(14, 50)
$body.Size = New-Object Drawing.Size(872, 536)
$body.BackColor = [Drawing.Color]::Transparent
$root.Controls.Add($body)

$sidebar = New-Object Windows.Forms.Panel
$sidebar.Location = New-Object Drawing.Point(0, 0)
$sidebar.Size = New-Object Drawing.Size(220, 536)
$sidebar.BackColor = [Drawing.Color]::Transparent
$body.Controls.Add($sidebar)

$brand = New-Object Windows.Forms.Label
$brand.Location = New-Object Drawing.Point(20, 22)
$brand.Size = New-Object Drawing.Size(180, 32)
$brand.Font = New-Object Drawing.Font('Microsoft YaHei UI', 13, [Drawing.FontStyle]::Bold)
$brand.ForeColor = $ink
$brand.BackColor = [Drawing.Color]::Transparent
$brand.Text = '控制台'
$sidebar.Controls.Add($brand)

$sideCaption = New-Object Windows.Forms.Label
$sideCaption.Location = New-Object Drawing.Point(22, 54)
$sideCaption.Size = New-Object Drawing.Size(176, 42)
$sideCaption.ForeColor = $muted
$sideCaption.BackColor = [Drawing.Color]::Transparent
$sideCaption.Font = New-Object Drawing.Font('Microsoft YaHei UI', 8)
$sideCaption.Text = "本地账号切换器`r`n仅限当前 Windows 用户"
$sidebar.Controls.Add($sideCaption)

$saveButton = New-LiquidGlassButton '＋  保存当前登录' 8 108 204 46
$sidebar.Controls.Add($saveButton)

$refreshButton = New-LiquidGlassButton '↻  刷新状态' 8 164 204 42
$sidebar.Controls.Add($refreshButton)

$addButton = New-LiquidGlassButton '＋  添加下一个账号' 8 216 204 46
$sidebar.Controls.Add($addButton)

$restoreButton = New-LiquidGlassButton '↶  恢复先前账号' 8 270 204 42
$sidebar.Controls.Add($restoreButton)

$trashButton = New-LiquidGlassButton '▤  查看垃圾箱' 8 320 204 42
$sidebar.Controls.Add($trashButton)

$backgroundButton = New-LiquidGlassButton '▧  切换背景' 8 374 204 42
$sidebar.Controls.Add($backgroundButton)

$sideNote = New-Object Windows.Forms.Label
$sideNote.Location = New-Object Drawing.Point(20, 430)
$sideNote.Size = New-Object Drawing.Size(180, 88)
$sideNote.Font = New-Object Drawing.Font('Microsoft YaHei UI', 8)
$sideNote.ForeColor = $muted
$sideNote.BackColor = [Drawing.Color]::Transparent
$sideNote.Text = "切换前请完全退出`r`nChatGPT / Codex。`r`n本地会话不会被复制或删除。"
$sidebar.Controls.Add($sideNote)

$main = New-Object Windows.Forms.Panel
$main.Location = New-Object Drawing.Point(228, 0)
$main.Size = New-Object Drawing.Size(644, 536)
$main.BackColor = [Drawing.Color]::Transparent
$body.Controls.Add($main)

$heading = New-Object Windows.Forms.Label
$heading.Location = New-Object Drawing.Point(24, 22)
$heading.Size = New-Object Drawing.Size(560, 36)
$heading.Font = New-Object Drawing.Font('Microsoft YaHei UI', 17, [Drawing.FontStyle]::Bold)
$heading.ForeColor = $ink
$heading.BackColor = [Drawing.Color]::Transparent
$heading.Text = '选择要使用的账号'
$main.Controls.Add($heading)

$subtitle = New-Object Windows.Forms.Label
$subtitle.Location = New-Object Drawing.Point(26, 58)
$subtitle.Size = New-Object Drawing.Size(560, 24)
$subtitle.ForeColor = $muted
$subtitle.BackColor = [Drawing.Color]::Transparent
$subtitle.Text = '邮箱用于辨认；真正的切换校验仍使用账号 ID。'
$main.Controls.Add($subtitle)

$bannerPlate = New-Object GlassPlatePanel
$bannerPlate.Location = New-Object Drawing.Point(22, 92)
$bannerPlate.Size = New-Object Drawing.Size(592, 48)
$bannerPlate.CornerRadius = 14
$bannerPlate.GlassFill = $glassNeutralFill
$bannerPlate.GlassBorder = $glassNeutralBorder
$main.Controls.Add($bannerPlate)

$banner = New-Object Windows.Forms.Label
$banner.Dock = 'Fill'
$banner.ForeColor = $ink
$banner.BackColor = [Drawing.Color]::Transparent
$banner.Padding = New-Object Windows.Forms.Padding(14, 13, 10, 8)
$banner.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9)
$bannerPlate.Controls.Add($banner)

$listTitle = New-Object Windows.Forms.Label
$listTitle.Location = New-Object Drawing.Point(26, 152)
$listTitle.Size = New-Object Drawing.Size(540, 24)
$listTitle.Font = New-Object Drawing.Font('Microsoft YaHei UI', 11, [Drawing.FontStyle]::Bold)
$listTitle.ForeColor = $ink
$listTitle.BackColor = [Drawing.Color]::Transparent
$listTitle.Text = '已保存的账号'
$main.Controls.Add($listTitle)

$list = New-Object Windows.Forms.FlowLayoutPanel
$list.Location = New-Object Drawing.Point(24, 182)
$list.Size = New-Object Drawing.Size(600, 258)
$list.FlowDirection = 'TopDown'
$list.WrapContents = $false
$list.AutoScroll = $true
$list.BackColor = [Drawing.Color]::Transparent
$main.Controls.Add($list)

$switchButton = New-LiquidGlassButton '切换到所选账号' 24 458 590 48 -Primary
$switchButton.Font = New-Object Drawing.Font('Microsoft YaHei UI', 10, [Drawing.FontStyle]::Bold)
$switchButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$switchButton.Enabled = $false
$main.Controls.Add($switchButton)

$status = New-Object Windows.Forms.Label
$status.Location = New-Object Drawing.Point(24, 512)
$status.Size = New-Object Drawing.Size(588, 20)
$status.ForeColor = $muted
$status.BackColor = [Drawing.Color]::Transparent
$status.Font = New-Object Drawing.Font('Microsoft YaHei UI', 8)
$main.Controls.Add($status)

$form.Add_Load({
    [GlassDwm]::TryAcrylic($form.Handle) | Out-Null
    [LgPaint]::BackdropSource = $backdrop
    [GlassFormHelper]::EnableDoubleBuffer($form)
    [GlassFormHelper]::EnableDoubleBuffer($root)
    [GlassFormHelper]::EnableDoubleBuffer($body)
    [GlassFormHelper]::EnableDoubleBuffer($list)
    [LgPaint]::RefreshBackdropCache($backdrop)
    $path = [LgPaint]::RoundRect((New-Object Drawing.Rectangle 0, 0, $form.Width, $form.Height), 18)
    $form.Region = New-Object Drawing.Region($path)
    $path.Dispose()
})

$fadeTimer = New-Object Windows.Forms.Timer
$fadeTimer.Interval = 30
$fadeTimer.Add_Tick({
    $form.Opacity = [Math]::Min(1.0, $form.Opacity + 0.2)
    if ($form.Opacity -ge 1.0) { $fadeTimer.Stop() }
})
$form.Add_Shown({
    $form.Refresh()
    $fadeTimer.Start()
})

$form.Add_ResizeEnd({
    [LgPaint]::RefreshBackdropCache($backdrop)
    $body.Invalidate($true)
})

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
    foreach ($card in $script:accountCards) {
        $moveEnabled = [bool](-not $card.CardCurrent -and $running -eq 0 -and -not $pending -and -not $pendingError -and $script:currentLabel)
        if ($card.MoveEnabled -ne $moveEnabled) {
            $card.MoveEnabled = $moveEnabled
            $card.Invalidate()
        }
    }
    foreach ($card in $script:trashCards) {
        $actionsEnabled = [bool]($running -eq 0 -and -not $pending -and -not $pendingError)
        if ($card.ActionsEnabled -ne $actionsEnabled) {
            $card.ActionsEnabled = $actionsEnabled
            $card.Invalidate()
        }
    }
    if ($pending) { $addButton.Text = '✓  完成添加并保存' } else { $addButton.Text = '＋  添加下一个账号' }
    if ($pending -and $running -eq 0) { $addButton.Enabled = $true }
    $oldFill = $bannerPlate.GlassFill.ToArgb()
    $oldBorder = $bannerPlate.GlassBorder.ToArgb()
    if ($running -gt 0) {
        $banner.Text = "●  ChatGPT/Codex 仍在运行（$running 个进程），退出后才能切换"
        $bannerPlate.GlassFill = $glassWarnFill
        $bannerPlate.GlassBorder = $glassWarnBorder
    } elseif ($pending) {
        $banner.Text = '待添加账号：登录新账号后关闭应用，再点击「完成添加并保存」。'
        $bannerPlate.GlassFill = $glassWarnFill
        $bannerPlate.GlassBorder = $glassWarnBorder
    } elseif (-not $script:currentLabel) {
        $banner.Text = '请先保存当前登录，再选择目标账号。'
        $bannerPlate.GlassFill = $glassNeutralFill
        $bannerPlate.GlassBorder = $glassNeutralBorder
    } else {
        $banner.Text = "●  当前：$($script:currentLabel)    ·    可以选择目标账号"
        $bannerPlate.GlassFill = $glassOkFill
        $bannerPlate.GlassBorder = $glassOkBorder
    }
    if ($oldFill -ne $bannerPlate.GlassFill.ToArgb() -or $oldBorder -ne $bannerPlate.GlassBorder.ToArgb()) { $bannerPlate.Invalidate() }
}

function Select-Target([string]$Label) {
    $script:selectedTarget = $Label
    foreach ($card in $script:accountCards) {
        $selected = ($card.Tag -eq $Label)
        if ($card.CardSelected -ne $selected) {
            $card.CardSelected = $selected
            $card.Invalidate()
        }
    }
    Update-Preflight
}

function New-AccountCard([string]$Label,[string]$Email,[bool]$IsCurrent) {
    $card = New-Object GlassAccountCard
    $card.Tag = $Label
    $card.CardCurrent = $IsCurrent
    $card.Title = if ($Email) { "$Email · $Label" } else { $Label }
    $card.Hint = if ($IsCurrent) { '当前登录' } elseif ($Email) { '点击选择为目标账号' } else { '邮箱不可用 · 点击选择' }
    $card.AvatarLetter = if ($Email) { $Email.Substring(0, 1) } else { $Label.Substring(0, 1) }
    $card.MoveEnabled = -not $IsCurrent

    $card.Add_Click({ Select-Target ([string]$this.Tag) })
    $card.Add_MoveToTrash({
        try {
            Update-Preflight
            $label = [string]$this.Tag
            if ($this.CardCurrent -or -not $this.MoveEnabled) { throw '当前账号不能移除。' }
            $choice = [Windows.Forms.MessageBox]::Show("将 $label 移到加密垃圾箱？`r`n请先完全退出 ChatGPT/Codex；此操作不会删除聊天记录。", '确认移除账号', [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
            if ($choice -ne [Windows.Forms.DialogResult]::Yes) { return }
            Move-ProfileToTrash -Label $label -AuthPath $authPath -StorePath $storePath | Out-Null
            if ($script:selectedTarget -eq $label) { $script:selectedTarget = $null }
            Refresh-Accounts
            $status.Text = "账号 $label 已移到垃圾箱，可随时恢复。"
        } catch { $status.Text = '移除失败：' + $_.Exception.Message }
    })
    return $card
}

function New-TrashCard($Entry) {
    $card = New-Object GlassTrashCard
    $card.Tag = [string]$Entry.Id
    $card.Title = [string]$Entry.Label
    $card.DateText = '移入时间：' + $Entry.DeletedAt.ToString('yyyy-MM-dd HH:mm')

    $card.Add_RestoreClicked({
        try {
            Update-Preflight
            if (-not $this.ActionsEnabled) { throw '请先退出应用并完成正在添加的账号。' }
            Restore-TrashedProfile -Id ([string]$this.Tag) -StorePath $storePath
            Refresh-Accounts
            $status.Text = '账号已恢复到已保存列表。'
        } catch { $status.Text = '恢复失败：' + $_.Exception.Message }
    })
    $card.Add_RemoveClicked({
        try {
            Update-Preflight
            if (-not $this.ActionsEnabled) { throw '请先退出应用并完成正在添加的账号。' }
            $id = [string]$this.Tag
            $choice = [Windows.Forms.MessageBox]::Show("永久删除垃圾箱中的账号记录？`r`n此操作不能撤销，之后如需切换到该账号须重新登录并保存。", '确认永久删除', [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
            if ($choice -ne [Windows.Forms.DialogResult]::Yes) { return }
            Remove-TrashedProfile -Id $id -AuthPath $authPath -StorePath $storePath
            Refresh-Accounts
            $status.Text = '已永久删除该账号的加密保存记录。'
        } catch { $status.Text = '删除失败：' + $_.Exception.Message }
    })
    $script:trashCards += $card
    return $card
}

function Refresh-Accounts {
    [GlassFormHelper]::BeginUpdate($list)
    $list.SuspendLayout()
    try {
    $list.Controls.Clear()
    $script:accountCards = @()
    $script:trashCards = @()
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
    } finally {
        [GlassFormHelper]::EndUpdate($list)
    }
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

$refreshButton.Add_Click({
    $backgroundLoaded = [LgPaint]::LoadBackground($script:backgroundPath)
    [LgPaint]::RefreshBackdropCache($backdrop)
    $backdrop.Invalidate($true)
    Refresh-Accounts
    if (-not $backgroundLoaded) { $status.Text = '背景图片无法读取；请重新导入或检查图片文件。' }
})

$backgroundButton.Add_Click({
    $picker = New-Object Windows.Forms.OpenFileDialog
    try {
        $picker.Title = '选择背景图片'
        $picker.Filter = '图片文件 (*.png;*.jpg;*.jpeg;*.bmp;*.gif)|*.png;*.jpg;*.jpeg;*.bmp;*.gif'
        $picker.CheckFileExists = $true
        $picker.Multiselect = $false
        $pictures = [Environment]::GetFolderPath('MyPictures')
        if (Test-Path -LiteralPath $pictures) { $picker.InitialDirectory = $pictures }
        if ($picker.ShowDialog($form) -ne [Windows.Forms.DialogResult]::OK) { return }
        [LgPaint]::ImportBackground($picker.FileName, $customBackgroundPath)
        if (-not [LgPaint]::LoadBackground($customBackgroundPath)) { throw '导入后无法读取图片。' }
        $script:backgroundPath = $customBackgroundPath
        [LgPaint]::RefreshBackdropCache($backdrop)
        $backdrop.Invalidate($true)
        $status.Text = '背景已更换；图片仅保存在当前 Windows 用户的本地目录。'
    } catch { $status.Text = '背景导入失败：' + $_.Exception.Message }
    finally { $picker.Dispose() }
})

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
    $fadeTimer.Dispose()
    $form.Dispose()
    return
}
$timer.Start()
[void]$form.ShowDialog()
$timer.Stop()
$fadeTimer.Stop()
$fadeTimer.Dispose()
$form.Dispose()
