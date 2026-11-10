using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.InteropServices;
using System.Windows.Forms;

internal static class Launcher
{
    [DllImport("shell32.dll")]
    private static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string appId);

    [STAThread]
    private static int Main(string[] args)
    {
        bool validate = args.Length == 1 && args[0] == "--validate-ui";
        string script = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Start-Switcher.ps1");
        if (!File.Exists(script))
        {
            if (!validate) MessageBox.Show("找不到 Start-Switcher.ps1。请将启动程序与项目文件放在同一目录。", "账号切换器");
            return 1;
        }

        try
        {
            SetCurrentProcessExplicitAppUserModelID("local.chatgpt.account-switcher");
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using (Runspace runspace = RunspaceFactory.CreateRunspace())
            {
                runspace.ApartmentState = System.Threading.ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                using (PowerShell powerShell = PowerShell.Create())
                {
                    powerShell.Runspace = runspace;
                    powerShell.AddCommand(script);
                    if (validate) powerShell.AddParameter("ValidateUi");
                    powerShell.Invoke();
                    if (powerShell.HadErrors)
                    {
                        if (!validate) MessageBox.Show(powerShell.Streams.Error[0].ToString(), "账号切换器启动失败");
                        return 1;
                    }
                }
            }
            return 0;
        }
        catch (Exception error)
        {
            if (!validate) MessageBox.Show(error.Message, "账号切换器启动失败");
            return 1;
        }
    }
}
