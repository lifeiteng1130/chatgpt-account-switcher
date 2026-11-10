$root = Split-Path $PSScriptRoot -Parent
Describe 'GUI launcher' {
    It 'uses a current precompiled glass control assembly' {
        $source = Join-Path $root 'LiquidGlass.Controls.cs'
        $assembly = Join-Path $root 'LiquidGlass.Controls.dll'
        (Test-Path -LiteralPath $assembly) | Should Be $true
        (Get-Item -LiteralPath $assembly).LastWriteTimeUtc -ge (Get-Item -LiteralPath $source).LastWriteTimeUtc | Should Be $true
    }

    It 'constructs glass account and trash cards without a background exception' {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        if (-not ('GlassAccountCard' -as [type])) {
            Add-Type -Path (Join-Path $root 'LiquidGlass.Controls.cs') -ReferencedAssemblies @([Drawing.Color].Assembly.Location, [Windows.Forms.Panel].Assembly.Location)
        }
        $account = New-Object GlassAccountCard
        $trash = New-Object GlassTrashCard
        $account | Should Not BeNullOrEmpty
        $trash | Should Not BeNullOrEmpty
        $account.Dispose()
        $trash.Dispose()
    }

    It 'selects an account when clicking outside its trash action' {
        $card = New-Object GlassAccountCard
        $script:cardClicks = 0
        $card.Add_Click({ $script:cardClicks++ })
        $mouse = [Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left, 1, 80, 35, 0)
        $method = [GlassAccountCard].GetMethod('OnMouseClick', [Reflection.BindingFlags]'Instance,NonPublic')
        $method.Invoke($card, [object[]]@($mouse))
        $script:cardClicks | Should Be 1
        $card.Dispose()
    }

    It 'paints the backdrop in rounded control corners' {
        foreach ($type in @('GlassButton', 'GlassPlatePanel', 'GlassAccountCard', 'GlassTrashCard')) {
            $control = New-Object $type
            $control.Size = New-Object Drawing.Size(120, 44)
            $bitmap = New-Object Drawing.Bitmap 120, 44
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            $graphics.Clear([Drawing.Color]::Black)
            $paint = [Windows.Forms.PaintEventArgs]::new($graphics, [Drawing.Rectangle]::new(0, 0, 120, 44))
            $method = $control.GetType().GetMethod('OnPaintBackground', [Reflection.BindingFlags]'Instance,NonPublic')
            $method.Invoke($control, [object[]]@($paint))
            $bitmap.GetPixel(0, 0).ToArgb() | Should Not Be ([Drawing.Color]::Black.ToArgb())
            $graphics.Dispose()
            $bitmap.Dispose()
            $control.Dispose()
        }
    }

    It 'uses an owner-drawn button without a native rectangular button surface' {
        $button = New-Object GlassButton
        ($button -is [Windows.Forms.Button]) | Should Be $false
        $styleMethod = [Windows.Forms.Control].GetMethod('GetStyle', [Reflection.BindingFlags]'Instance,NonPublic')
        $styleMethod.Invoke($button, [object[]]@([Windows.Forms.ControlStyles]::StandardClick)) | Should Be $false
        $button.Size = New-Object Drawing.Size(120, 44)
        $script:buttonClicks = 0
        $button.Add_Click({ $script:buttonClicks++ })
        $button.CreateControl()
        $mouse = [Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left, 1, 20, 20, 0)
        $flags = [Reflection.BindingFlags]'Instance,NonPublic'
        $button.GetType().GetMethod('OnMouseDown', $flags).Invoke($button, [object[]]@($mouse))
        $button.GetType().GetMethod('OnMouseUp', $flags).Invoke($button, [object[]]@($mouse))
        $script:buttonClicks | Should Be 1
        $button.Dispose()
    }

    It 'loads a replaceable image as the full window backdrop' {
        $path = Join-Path $TestDrive 'background.png'
        $source = New-Object Drawing.Bitmap 20, 10
        $g = [Drawing.Graphics]::FromImage($source)
        $g.Clear([Drawing.Color]::Magenta)
        $g.Dispose()
        $source.Save($path, [Drawing.Imaging.ImageFormat]::Png)
        $source.Dispose()
        [LgPaint]::LoadBackground($path) | Should Be $true
        $rendered = New-Object Drawing.Bitmap 120, 60
        $g = [Drawing.Graphics]::FromImage($rendered)
        [LgPaint]::DrawBackdrop($g, [Drawing.Rectangle]::new(0, 0, 120, 60))
        $rendered.GetPixel(60, 30).ToArgb() | Should Be ([Drawing.Color]::Magenta.ToArgb())
        $g.Dispose()
        $rendered.Dispose()
        [LgPaint]::LoadBackground($null) | Out-Null
    }

    It 'imports a local image as a persistent PNG without using account files' {
        $sourcePath = Join-Path $TestDrive 'picked.jpg'
        $targetPath = Join-Path $TestDrive 'settings\background.png'
        $source = New-Object Drawing.Bitmap 20, 10
        $g = [Drawing.Graphics]::FromImage($source)
        $g.Clear([Drawing.Color]::Cyan)
        $g.Dispose()
        $source.Save($sourcePath, [Drawing.Imaging.ImageFormat]::Jpeg)
        $source.Dispose()
        [LgPaint]::ImportBackground($sourcePath, $targetPath)
        (Test-Path -LiteralPath $targetPath) | Should Be $true
        $imported = [Drawing.Image]::FromFile($targetPath)
        $imported.RawFormat.Guid | Should Be ([Drawing.Imaging.ImageFormat]::Png.Guid)
        $imported.Dispose()
        $replacement = New-Object Drawing.Bitmap 20, 10
        $g = [Drawing.Graphics]::FromImage($replacement)
        $g.Clear([Drawing.Color]::Red)
        $g.Dispose()
        $replacement.Save($sourcePath, [Drawing.Imaging.ImageFormat]::Jpeg)
        $replacement.Dispose()
        [LgPaint]::ImportBackground($sourcePath, $targetPath)
        $updated = New-Object Drawing.Bitmap $targetPath
        $updated.GetPixel(10, 5).R | Should BeGreaterThan 200
        $updated.Dispose()
        $previousHash = (Get-FileHash -LiteralPath $targetPath).Hash
        [IO.File]::WriteAllText($sourcePath, 'not an image')
        { [LgPaint]::ImportBackground($sourcePath, $targetPath) } | Should Throw
        (Get-FileHash -LiteralPath $targetPath).Hash | Should Be $previousHash
        [LgPaint]::LoadBackground($targetPath) | Should Be $true
        [LgPaint]::LoadBackground($null) | Out-Null
    }

    It 'keeps imported backgrounds near the window resolution' {
        $sourcePath = Join-Path $TestDrive 'large.png'
        $targetPath = Join-Path $TestDrive 'background.png'
        $source = New-Object Drawing.Bitmap 2000, 1400
        $g = [Drawing.Graphics]::FromImage($source)
        $g.Clear([Drawing.Color]::Blue)
        $g.Dispose()
        $source.Save($sourcePath, [Drawing.Imaging.ImageFormat]::Png)
        $source.Dispose()
        [LgPaint]::ImportBackground($sourcePath, $targetPath)
        $result = [Drawing.Image]::FromFile($targetPath)
        $result.Width -le 1800 | Should Be $true
        $result.Height -le 1200 | Should Be $true
        $result.Dispose()
    }

    It 'starts the existing UI inside the desktop executable' {
        $exe = Join-Path $root 'ChatGPTAccountSwitcher.exe'
        (Test-Path -LiteralPath $exe) | Should Be $true
        $process = Start-Process -FilePath $exe -ArgumentList '--validate-ui' -Wait -PassThru
        $process.ExitCode | Should Be 0
    }

    It 'parses without syntax errors' {
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Start-Switcher.ps1'), [ref]$null, [ref]$errors)
        $errors.Count | Should Be 0
    }

    It 'constructs the account card UI without switching accounts' {
        $result = & powershell.exe -NoProfile -STA -File (Join-Path $root 'Start-Switcher.ps1') -ValidateUi 2>&1
        ($result -join "`n") | Should Match '^UI_READY cards=\d+$'
    }

    It 'exposes guarded account trash, restore, and permanent delete controls' {
        $source = [IO.File]::ReadAllText((Join-Path $root 'Start-Switcher.ps1'))
        $source | Should Match '\$trashButton'
        $source | Should Match 'New-TrashCard'
        $source | Should Match 'Move-ProfileToTrash'
        $source | Should Match 'Restore-TrashedProfile'
        $source | Should Match 'Remove-TrashedProfile'
    }

    It 'offers a local background image importer' {
        $source = [IO.File]::ReadAllText((Join-Path $root 'Start-Switcher.ps1'))
        $source | Should Match '\$backgroundButton'
        $source | Should Match 'OpenFileDialog'
        $source | Should Match 'ImportBackground'
        $source | Should Match 'ChatGPTAccountSwitcher\\background.png'
    }

    It 'supports one redraw after replacing list cards' {
        $list = New-Object Windows.Forms.FlowLayoutPanel
        $list.Size = New-Object Drawing.Size(200, 180)
        $list.FlowDirection = 'TopDown'
        $list.WrapContents = $false
        $list.CreateControl()
        [GlassFormHelper]::BeginUpdate($list)
        $list.SuspendLayout()
        try {
            $list.Controls.Add((New-Object Windows.Forms.Label)) | Out-Null
            $list.Controls.Clear()
            foreach ($name in @('A', 'B', 'C')) {
                $card = New-Object Windows.Forms.Label
                $card.Name = $name
                $card.Size = New-Object Drawing.Size(120, 30)
                $list.Controls.Add($card) | Out-Null
            }
        } finally {
            [GlassFormHelper]::EndUpdate($list)
        }
        $list.Controls.Count | Should Be 3
        (@($list.Controls | ForEach-Object { $_.Location.Y } | Select-Object -Unique)).Count | Should Be 3
        $list.Dispose()
    }
}
