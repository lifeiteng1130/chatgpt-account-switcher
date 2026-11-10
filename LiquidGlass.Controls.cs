// Compiled via Add-Type in Start-Switcher.ps1 — iOS / FluentWinForms-inspired frost (no Skia).
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class LgPaint
{
    public static Control BackdropSource;
    static Bitmap _backgroundImage;
    static Bitmap _backdropCache;
    static Bitmap _frostCache;
    static readonly object CacheLock = new object();

    public static readonly Color Ink = Color.FromArgb(247, 248, 255);
    public static readonly Color Muted = Color.FromArgb(195, 202, 223);
    public static readonly Color Accent = Color.FromArgb(195, 222, 255);
    public static readonly Color GlassTint = Color.FromArgb(110, 29, 35, 56);
    public static readonly Color GlassInteractiveTint = Color.FromArgb(78, 29, 35, 56);
    public static readonly Color GlassEdge = Color.FromArgb(112, 242, 246, 255);
    public static readonly Color GlassSpec = Color.FromArgb(90, 255, 255, 255);

    public static Font UiFont9 = new Font("Microsoft YaHei UI", 9f);
    public static Font UiFont8 = new Font("Microsoft YaHei UI", 8f);
    public static Font UiFont10Bold = new Font("Microsoft YaHei UI", 10f, FontStyle.Bold);
    public static Font UiFont13Bold = new Font("Microsoft YaHei UI", 13f, FontStyle.Bold);

    public static GraphicsPath RoundRect(Rectangle bounds, int radius)
    {
        int d = radius * 2;
        var path = new GraphicsPath();
        if (radius <= 0) { path.AddRectangle(bounds); return path; }
        var arc = new Rectangle(bounds.Location, new Size(d, d));
        path.AddArc(arc, 180, 90);
        arc.X = bounds.Right - d;
        path.AddArc(arc, 270, 90);
        arc.Y = bounds.Bottom - d;
        path.AddArc(arc, 0, 90);
        arc.X = bounds.Left;
        path.AddArc(arc, 90, 90);
        path.CloseFigure();
        return path;
    }

    public static bool LoadBackground(string path)
    {
        if (string.IsNullOrEmpty(path))
        {
            lock (CacheLock)
            {
                if (_backgroundImage != null) { _backgroundImage.Dispose(); _backgroundImage = null; }
            }
            return false;
        }
        try
        {
            Bitmap loaded;
            using (var stream = new System.IO.FileStream(path, System.IO.FileMode.Open, System.IO.FileAccess.Read, System.IO.FileShare.ReadWrite))
            using (var decoded = Image.FromStream(stream))
                loaded = new Bitmap(decoded);
            lock (CacheLock)
            {
                if (_backgroundImage != null) _backgroundImage.Dispose();
                _backgroundImage = loaded;
            }
            return true;
        }
        catch { return false; }
    }

    public static void ImportBackground(string sourcePath, string targetPath)
    {
        if (string.IsNullOrEmpty(sourcePath) || string.IsNullOrEmpty(targetPath))
            throw new ArgumentException("请选择图片文件。 ");
        string directory = System.IO.Path.GetDirectoryName(targetPath);
        if (string.IsNullOrEmpty(directory)) throw new ArgumentException("背景保存路径无效。 ");
        System.IO.Directory.CreateDirectory(directory);
        string temporary = System.IO.Path.Combine(directory, "background-" + Guid.NewGuid().ToString("N") + ".tmp");
        try
        {
            using (var stream = new System.IO.FileStream(sourcePath, System.IO.FileMode.Open, System.IO.FileAccess.Read, System.IO.FileShare.Read))
            using (var decoded = Image.FromStream(stream))
            {
                if (decoded.Width > 8192 || decoded.Height > 8192)
                    throw new ArgumentException("图片尺寸不能超过 8192 × 8192。 ");
                double scale = Math.Min(1.0, Math.Min(1800.0 / decoded.Width, 1200.0 / decoded.Height));
                int width = Math.Max(1, (int)Math.Round(decoded.Width * scale));
                int height = Math.Max(1, (int)Math.Round(decoded.Height * scale));
                using (var bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb))
                {
                    using (var graphics = Graphics.FromImage(bitmap))
                    {
                        graphics.Clear(Color.Transparent);
                        graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        graphics.DrawImage(decoded, new Rectangle(0, 0, width, height));
                    }
                    bitmap.Save(temporary, ImageFormat.Png);
                }
            }
            System.IO.File.Copy(temporary, targetPath, true);
        }
        finally
        {
            if (System.IO.File.Exists(temporary)) System.IO.File.Delete(temporary);
        }
    }

    public static void DrawBackdrop(Graphics g, Rectangle client)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        lock (CacheLock)
        {
            if (_backgroundImage != null)
            {
                using (var baseFill = new SolidBrush(Color.FromArgb(23, 30, 51)))
                    g.FillRectangle(baseFill, client);
                float scale = Math.Max((float)client.Width / _backgroundImage.Width, (float)client.Height / _backgroundImage.Height);
                float sourceW = client.Width / scale;
                float sourceH = client.Height / scale;
                var source = new RectangleF((_backgroundImage.Width - sourceW) / 2f, (_backgroundImage.Height - sourceH) / 2f, sourceW, sourceH);
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.DrawImage(_backgroundImage, client, source.X, source.Y, source.Width, source.Height, GraphicsUnit.Pixel);
                return;
            }
        }
        using (var bg = new LinearGradientBrush(client, Color.FromArgb(255, 19, 29, 53), Color.FromArgb(255, 43, 32, 63), 40f))
            g.FillRectangle(bg, client);
        DrawOrb(g, -150, -110, 620, 430, Color.FromArgb(120, 58, 113, 182));
        DrawOrb(g, client.Width - 430, client.Height - 350, 600, 510, Color.FromArgb(112, 155, 84, 166));
        DrawOrb(g, client.Width / 2 - 80, 60, 400, 310, Color.FromArgb(72, 56, 162, 179));
    }

    static void DrawOrb(Graphics g, int x, int y, int w, int h, Color center)
    {
        using (var path = new GraphicsPath())
        {
            path.AddEllipse(x, y, w, h);
            using (var brush = new PathGradientBrush(path))
            {
                brush.CenterColor = center;
                brush.SurroundColors = new[] { Color.FromArgb(0, center) };
                g.FillPath(brush, path);
            }
        }
    }

    public static void RefreshBackdropCache(Control src)
    {
        if (src == null || !src.IsHandleCreated) return;
        int w = src.ClientSize.Width;
        int h = src.ClientSize.Height;
        if (w < 2 || h < 2) return;
        try
        {
            var fresh = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(fresh))
                DrawBackdrop(g, new Rectangle(0, 0, w, h));
            var small = new Bitmap(Math.Max(1, w / 12), Math.Max(1, h / 12));
            using (var g = Graphics.FromImage(small))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.DrawImage(fresh, new Rectangle(0, 0, small.Width, small.Height));
            }
            var frost = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(frost))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.DrawImage(small, new Rectangle(0, 0, w, h));
            }
            small.Dispose();
            lock (CacheLock)
            {
                if (_backdropCache != null) _backdropCache.Dispose();
                if (_frostCache != null) _frostCache.Dispose();
                _backdropCache = fresh;
                _frostCache = frost;
            }
        }
        catch
        {
            lock (CacheLock)
            {
                if (_backdropCache != null) { _backdropCache.Dispose(); _backdropCache = null; }
                if (_frostCache != null) { _frostCache.Dispose(); _frostCache = null; }
            }
        }
    }

    public static void ClearBackdropCache()
    {
        lock (CacheLock)
        {
            if (_backdropCache != null) { _backdropCache.Dispose(); _backdropCache = null; }
            if (_frostCache != null) { _frostCache.Dispose(); _frostCache = null; }
        }
    }

    public static void PaintBackdropForControl(Control host, Graphics g, Rectangle bounds)
    {
        if (BackdropSource != null)
        {
            try
            {
                var local = BackdropSource.RectangleToClient(host.RectangleToScreen(bounds));
                var source = new Rectangle(local.X, local.Y, bounds.Width, bounds.Height);
                lock (CacheLock)
                {
                    if (_backdropCache != null && source.X >= 0 && source.Y >= 0 && source.Right <= _backdropCache.Width && source.Bottom <= _backdropCache.Height)
                    {
                        g.DrawImage(_backdropCache, bounds, source, GraphicsUnit.Pixel);
                        return;
                    }
                }
                var saved = g.Save();
                g.TranslateTransform(-local.X, -local.Y);
                DrawBackdrop(g, BackdropSource.ClientRectangle);
                g.Restore(saved);
                return;
            }
            catch { }
        }
        DrawBackdrop(g, bounds);
    }

    static void PaintFrostFinish(Graphics g, Rectangle inset, int radius, Color extraTint, Color border, bool primary, bool hover)
    {
        using (var path = RoundRect(inset, radius))
        {
            Color wash = primary
                ? Color.FromArgb(hover ? 90 : 74, 90, 160, 255)
                : Color.FromArgb(extraTint.A > 0 ? extraTint.A : (hover ? 72 : 58), extraTint.R, extraTint.G, extraTint.B);
            if (wash.A > 0)
            {
                using (var tint = new SolidBrush(wash))
                    g.FillPath(tint, path);
            }

            var spec = new Rectangle(inset.X + 1, inset.Y + 1, inset.Width - 2, Math.Max(3, inset.Height / 7));
            using (var hiPath = RoundRect(spec, Math.Max(0, radius - 2)))
            using (var hi = new LinearGradientBrush(spec, Color.FromArgb(38, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
                g.FillPath(hi, hiPath);

            using (var pen = new Pen(border.A > 0 ? border : GlassEdge, 1f))
                g.DrawPath(pen, path);
        }
    }

    public static void DrawFrostedOverlay(Graphics g, Rectangle bounds, int radius, Color extraTint, Color border, bool hover)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        var inset = new Rectangle(bounds.X, bounds.Y, Math.Max(1, bounds.Width - 1), Math.Max(1, bounds.Height - 1));
        using (var path = RoundRect(inset, radius))
        using (var baseFill = new SolidBrush(Color.FromArgb(hover ? 55 : 40, 18, 24, 40)))
            g.FillPath(baseFill, path);
        PaintFrostFinish(g, inset, radius, extraTint, border, false, hover);
    }

  // Never call DrawToBitmap here — it deadlocks when painting glass children over the backdrop.
    public static void DrawLiquidSurface(Control host, Graphics g, Rectangle bounds, int radius, Color extraTint, Color border, bool primary, bool hover)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        var inset = new Rectangle(bounds.X, bounds.Y, Math.Max(1, bounds.Width - 1), Math.Max(1, bounds.Height - 1));
        using (var sp = RoundRect(new Rectangle(inset.X, inset.Y + 2, inset.Width, inset.Height), radius))
        using (var shadow = new SolidBrush(Color.FromArgb(65, 4, 8, 22)))
            g.FillPath(shadow, sp);

        bool sampled = false;
        Bitmap cache = null;
        lock (CacheLock) { cache = _frostCache; }
        if (cache != null && BackdropSource != null && inset.Width > 4 && inset.Height > 4)
        {
            try
            {
                var screen = host.RectangleToScreen(inset);
                var local = BackdropSource.RectangleToClient(screen);
                var srcRect = new Rectangle(local.X, local.Y, inset.Width, inset.Height);
                var clip = new Rectangle(0, 0, cache.Width, cache.Height);
                srcRect = Rectangle.Intersect(srcRect, clip);
                if (srcRect.Width > 2 && srcRect.Height > 2)
                {
                    using (var path = RoundRect(inset, radius))
                    {
                        g.SetClip(path);
                        g.DrawImage(cache, inset, srcRect, GraphicsUnit.Pixel);
                        g.ResetClip();
                        sampled = true;
                    }
                }
            }
            catch { sampled = false; }
        }

        if (!sampled)
        {
            using (var path = RoundRect(inset, radius))
            using (var fb = new SolidBrush(Color.FromArgb(95, 28, 35, 57)))
                g.FillPath(fb, path);
        }

        PaintFrostFinish(g, inset, radius, extraTint, border, primary, hover);
    }

    public static void DrawAccentPrimary(Graphics g, Rectangle bounds, int radius, bool hover)
    {
        var inset = new Rectangle(bounds.X, bounds.Y, Math.Max(1, bounds.Width - 1), Math.Max(1, bounds.Height - 1));
        using (var path = RoundRect(inset, radius))
        {
            var top = Color.FromArgb(hover ? 175 : 145, 87, 142, 226);
            var bottom = Color.FromArgb(hover ? 160 : 130, 39, 70, 148);
            using (var grad = new LinearGradientBrush(inset, top, bottom, 95f))
                g.FillPath(grad, path);
            var spec = new Rectangle(inset.X + 1, inset.Y + 1, inset.Width - 2, Math.Max(8, inset.Height / 2));
            using (var hi = RoundRect(spec, Math.Max(0, radius - 1)))
            using (var gloss = new LinearGradientBrush(spec, Color.FromArgb(100, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
                g.FillPath(gloss, hi);
            using (var pen = new Pen(Color.FromArgb(150, 221, 238, 255), 1f))
                g.DrawPath(pen, path);
        }
    }

    public static TextFormatFlags AlignFrom(ContentAlignment align)
    {
        TextFormatFlags f = TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding;
        if (align == ContentAlignment.MiddleLeft || align == ContentAlignment.TopLeft || align == ContentAlignment.BottomLeft)
            f |= TextFormatFlags.Left;
        else if (align == ContentAlignment.MiddleRight || align == ContentAlignment.TopRight || align == ContentAlignment.BottomRight)
            f |= TextFormatFlags.Right;
        else
            f |= TextFormatFlags.HorizontalCenter;
        return f;
    }
}

public static class GlassFormHelper
{
    private const int WM_SETREDRAW = 0x000B;

    [DllImport("user32.dll")]
    private static extern IntPtr SendMessage(IntPtr handle, int message, IntPtr wParam, IntPtr lParam);

    public static void BeginUpdate(Control control)
    {
        if (control.IsHandleCreated) SendMessage(control.Handle, WM_SETREDRAW, IntPtr.Zero, IntPtr.Zero);
    }

    public static void EndUpdate(Control control)
    {
        control.ResumeLayout(true);
        if (!control.IsHandleCreated) return;
        SendMessage(control.Handle, WM_SETREDRAW, new IntPtr(1), IntPtr.Zero);
        control.Invalidate(true);
        control.Update();
    }

    public static void EnableDoubleBuffer(Control c)
    {
        try
        {
            var pi = typeof(Control).GetProperty("DoubleBuffered", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
            if (pi != null) pi.SetValue(c, true, null);
        }
        catch { }
    }
}

public class GlassBackdropPanel : Panel
{
    public GlassBackdropPanel()
    {
        DoubleBuffered = true;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer, true);
        BackColor = Color.FromArgb(255, 23, 30, 51);
    }
    protected override void OnPaintBackground(PaintEventArgs e)
    {
        e.Graphics.Clear(BackColor);
        LgPaint.DrawBackdrop(e.Graphics, ClientRectangle);
    }
}

public class GlassPlatePanel : Panel
{
    public Color GlassFill { get; set; }
    public Color GlassBorder { get; set; }
    public int CornerRadius { get; set; }

    public GlassPlatePanel()
    {
        DoubleBuffered = true;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        GlassFill = LgPaint.GlassTint;
        GlassBorder = LgPaint.GlassEdge;
        CornerRadius = 18;
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        LgPaint.PaintBackdropForControl(this, e.Graphics, ClientRectangle);
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        LgPaint.DrawLiquidSurface(this, e.Graphics, ClientRectangle, CornerRadius, GlassFill, GlassBorder, false, false);
        base.OnPaint(e);
    }
}

public class GlassButton : Control
{
    public bool IsPrimary { get; set; }
    public bool IsDangerStyle { get; set; }
    public ContentAlignment TextAlign { get; set; }
    bool _hover;

    public GlassButton()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        SetStyle(ControlStyles.StandardClick | ControlStyles.StandardDoubleClick, false);
        BackColor = Color.Transparent;
        ForeColor = LgPaint.Ink;
        Font = LgPaint.UiFont9;
        Cursor = Cursors.Hand;
        TabStop = false;
        Padding = new Padding(14, 0, 10, 0);
        TextAlign = ContentAlignment.MiddleLeft;
    }

    protected override void OnPaintBackground(PaintEventArgs pevent)
    {
        LgPaint.PaintBackdropForControl(this, pevent.Graphics, ClientRectangle);
    }
    protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); _hover = true; Invalidate(); }
    protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); _hover = false; Invalidate(); }
    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        if (Enabled && e.Button == MouseButtons.Left && ClientRectangle.Contains(e.Location)) OnClick(EventArgs.Empty);
    }
    protected override void OnEnabledChanged(EventArgs e) { base.OnEnabledChanged(e); Invalidate(); }
    protected override void OnTextChanged(EventArgs e) { base.OnTextChanged(e); Invalidate(); }

    protected override void OnPaint(PaintEventArgs pevent)
    {
        var g = pevent.Graphics;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        var hover = Enabled && _hover;
        int r = Math.Min(Height / 2 - 2, Height >= 42 ? 20 : 16);
        if (IsPrimary)
        {
            LgPaint.DrawLiquidSurface(this, g, ClientRectangle, r, Color.FromArgb(80, 53, 104, 183), Color.FromArgb(170, 187, 218, 255), true, hover);
            DrawCaption(g, Color.White);
            return;
        }
        var tint = IsDangerStyle ? Color.FromArgb(72, 96, 45, 58) : LgPaint.GlassInteractiveTint;
        var border = IsDangerStyle ? Color.FromArgb(140, 255, 180, 190) : LgPaint.GlassEdge;
        LgPaint.DrawLiquidSurface(this, g, ClientRectangle, r, tint, border, false, hover);
        var textColor = IsDangerStyle ? Color.FromArgb(255, 206, 212) : (Enabled ? ForeColor : Color.FromArgb(140, ForeColor));
        DrawCaption(g, textColor);
    }

    void DrawCaption(Graphics g, Color color)
    {
        if (string.IsNullOrEmpty(Text)) return;
        var rect = ClientRectangle;
        rect.X += Padding.Left;
        rect.Width -= Padding.Horizontal;
        rect.Y += Padding.Top;
        rect.Height -= Padding.Vertical;
        TextRenderer.DrawText(g, Text, Font, rect, color, LgPaint.AlignFrom(TextAlign));
    }
}

public class GlassAccountCard : Control
{
    public bool CardSelected { get; set; }
    public bool CardCurrent { get; set; }
    public bool MoveEnabled { get; set; }
    public string Title { get; set; }
    public string Hint { get; set; }
    public string AvatarLetter { get; set; }

    readonly Rectangle _moveRect = new Rectangle(412, 20, 124, 34);
    bool _moveHover;

    public event EventHandler MoveToTrash;

    public GlassAccountCard()
    {
        DoubleBuffered = true;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.StandardClick | ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        Margin = new Padding(0, 0, 0, 10);
        Size = new Size(548, 74);
        Cursor = Cursors.Hand;
        Font = LgPaint.UiFont9;
        MoveEnabled = true;
        Title = "";
        Hint = "";
        AvatarLetter = "?";
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        bool hover = MoveEnabled && _moveRect.Contains(e.Location);
        if (hover != _moveHover) { _moveHover = hover; Invalidate(_moveRect); }
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        if (_moveHover) { _moveHover = false; Invalidate(_moveRect); }
    }

    protected override void OnMouseClick(MouseEventArgs e)
    {
        base.OnMouseClick(e);
        if (MoveEnabled && _moveRect.Contains(e.Location))
        {
            if (MoveToTrash != null) MoveToTrash(this, EventArgs.Empty);
        }
        else
        {
            OnClick(EventArgs.Empty);
        }
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        LgPaint.PaintBackdropForControl(this, e.Graphics, ClientRectangle);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        Color tint, border;
        if (CardSelected)
        {
            tint = Color.FromArgb(92, 48, 91, 145);
            border = Color.FromArgb(195, 187, 221, 255);
        }
        else if (CardCurrent)
        {
            tint = Color.FromArgb(78, 33, 94, 87);
            border = Color.FromArgb(155, 162, 236, 219);
        }
        else
        {
            tint = LgPaint.GlassInteractiveTint;
            border = LgPaint.GlassEdge;
        }

        LgPaint.DrawLiquidSurface(this, g, ClientRectangle, 30, tint, border, false, false);

        var avatar = new Rectangle(14, 17, 40, 40);
        using (var ap = LgPaint.RoundRect(avatar, 12))
        {
            using (var ab = new LinearGradientBrush(avatar, Color.FromArgb(175, 125, 165, 222), Color.FromArgb(145, 76, 108, 182), 120f))
                g.FillPath(ab, ap);
            using (var pen = new Pen(Color.FromArgb(180, 255, 255, 255), 1f))
                g.DrawPath(pen, ap);
        }
        var letter = string.IsNullOrEmpty(AvatarLetter) ? "?" : AvatarLetter.Substring(0, 1).ToUpperInvariant();
        TextRenderer.DrawText(g, letter, LgPaint.UiFont13Bold, avatar, Color.White, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);

        var titleRect = new Rectangle(64, 12, 330, 25);
        TextRenderer.DrawText(g, Title ?? "", LgPaint.UiFont10Bold, titleRect, LgPaint.Ink, TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);

        var hintRect = new Rectangle(65, 40, 280, 20);
        TextRenderer.DrawText(g, Hint ?? "", LgPaint.UiFont8, hintRect, LgPaint.Muted, TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);

        if (MoveEnabled || !CardCurrent)
        {
            var fill = MoveEnabled ? (_moveHover ? Color.FromArgb(96, 48, 61, 87) : Color.FromArgb(70, 32, 42, 65)) : Color.FromArgb(50, 30, 38, 58);
            LgPaint.DrawFrostedOverlay(g, _moveRect, 16, fill, LgPaint.GlassEdge, _moveHover && MoveEnabled);
            var moveColor = MoveEnabled ? LgPaint.Muted : Color.FromArgb(120, LgPaint.Muted);
            TextRenderer.DrawText(g, "移到垃圾箱", LgPaint.UiFont8, _moveRect, moveColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
    }
}

public class GlassTrashCard : Control
{
    public string Title { get; set; }
    public string DateText { get; set; }
    public bool ActionsEnabled { get; set; }

    readonly Rectangle _restoreRect = new Rectangle(350, 20, 82, 32);
    readonly Rectangle _removeRect = new Rectangle(440, 20, 92, 32);
    bool _restoreHover, _removeHover;

    public event EventHandler RestoreClicked;
    public event EventHandler RemoveClicked;

    public GlassTrashCard()
    {
        DoubleBuffered = true;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        Margin = new Padding(0, 0, 0, 10);
        Size = new Size(548, 74);
        Font = LgPaint.UiFont9;
        Title = "";
        DateText = "";
        ActionsEnabled = true;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        bool r = ActionsEnabled && _restoreRect.Contains(e.Location);
        bool d = ActionsEnabled && _removeRect.Contains(e.Location);
        if (r != _restoreHover || d != _removeHover) { _restoreHover = r; _removeHover = d; Invalidate(); }
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        _restoreHover = _removeHover = false;
        Invalidate();
    }

    protected override void OnMouseClick(MouseEventArgs e)
    {
        base.OnMouseClick(e);
        if (!ActionsEnabled) return;
        if (_restoreRect.Contains(e.Location)) { if (RestoreClicked != null) RestoreClicked(this, EventArgs.Empty); }
        else if (_removeRect.Contains(e.Location)) { if (RemoveClicked != null) RemoveClicked(this, EventArgs.Empty); }
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        LgPaint.PaintBackdropForControl(this, e.Graphics, ClientRectangle);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        LgPaint.DrawLiquidSurface(this, g, ClientRectangle, 30, LgPaint.GlassInteractiveTint, LgPaint.GlassEdge, false, false);

        TextRenderer.DrawText(g, Title ?? "", LgPaint.UiFont10Bold, new Rectangle(16, 14, 400, 25), LgPaint.Ink, TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        TextRenderer.DrawText(g, DateText ?? "", LgPaint.UiFont8, new Rectangle(16, 42, 400, 18), LgPaint.Muted, TextFormatFlags.Left | TextFormatFlags.VerticalCenter);

        DrawChip(g, _restoreRect, "恢复", LgPaint.Accent, _restoreHover, false);
        DrawChip(g, _removeRect, "永久删除", Color.FromArgb(255, 201, 206), _removeHover, true);
    }

    void DrawChip(Graphics g, Rectangle rect, string text, Color textColor, bool hover, bool danger)
    {
        if (!ActionsEnabled) textColor = Color.FromArgb(120, textColor);
        var tint = danger ? Color.FromArgb(72, 90, 44, 59) : Color.FromArgb(70, 34, 45, 68);
        var border = danger ? Color.FromArgb(130, 255, 180, 180) : LgPaint.GlassEdge;
        LgPaint.DrawFrostedOverlay(g, rect, 15, tint, border, hover && ActionsEnabled);
        TextRenderer.DrawText(g, text, LgPaint.UiFont8, rect, textColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
    }
}

public static class GlassDwm
{
    private const int DWMWA_SYSTEMBACKDROP_TYPE = 38;
    private const int DWMSBT_TRANSIENTWINDOW = 3;
    private const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    public static void TryAcrylic(IntPtr handle)
    {
        try
        {
            int backdrop = DWMSBT_TRANSIENTWINDOW;
            DwmSetWindowAttribute(handle, DWMWA_SYSTEMBACKDROP_TYPE, ref backdrop, sizeof(int));
            int dark = 0;
            DwmSetWindowAttribute(handle, DWMWA_USE_IMMERSIVE_DARK_MODE, ref dark, sizeof(int));
        }
        catch { }
    }
}
