using System;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using Velopack;

namespace GoodbyeDPIManager
{
    public partial class App : System.Windows.Application
    {
        private const string StartupTaskName = "GoodbyeDPIManager_Startup";

        [DllImport("shell32.dll", SetLastError = true)]
        static extern void SetCurrentProcessExplicitAppUserModelID(
            [MarshalAs(UnmanagedType.LPWStr)] string AppID
        );

        [STAThread]
        private static void Main(string[] args)
        {
            VelopackApp.Build()
                .OnBeforeUninstallFastCallback(_ => DeleteStartupTask())
                .Run();

            App app = new();
            app.InitializeComponent();
            app.Run();
        }

        protected override void OnStartup(StartupEventArgs e)
        {
            SetCurrentProcessExplicitAppUserModelID("AtaberkTekin.GoodbyeDPIManager");
            base.OnStartup(e);

            bool startHidden = e.Args.Any(arg =>
                string.Equals(arg, "--hidden", StringComparison.OrdinalIgnoreCase)
            );

            MainWindow window = new MainWindow();
            MainWindow = window;

            if (!startHidden)
            {
                window.Show();
            }
        }

        private static void DeleteStartupTask()
        {
            try
            {
                ProcessStartInfo psi = new()
                {
                    FileName = "schtasks.exe",
                    WindowStyle = ProcessWindowStyle.Hidden,
                    CreateNoWindow = true,
                    UseShellExecute = false
                };

                psi.ArgumentList.Add("/delete");
                psi.ArgumentList.Add("/tn");
                psi.ArgumentList.Add(StartupTaskName);
                psi.ArgumentList.Add("/f");

                using Process? process = Process.Start(psi);
                process?.WaitForExit();
            }
            catch
            {
                // Velopack uninstall hooks must exit quickly and should not block uninstall.
            }
        }
    }
}
