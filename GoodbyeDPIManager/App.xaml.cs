using System;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;

namespace GoodbyeDPIManager
{
    public partial class App : System.Windows.Application
    {
        [DllImport("shell32.dll", SetLastError = true)]
        static extern void SetCurrentProcessExplicitAppUserModelID(
            [MarshalAs(UnmanagedType.LPWStr)] string AppID
            
        );

        protected override void OnStartup(StartupEventArgs e)
        {
            SetCurrentProcessExplicitAppUserModelID("AtaberkTekin.GoodbyeDPIManager");
            base.OnStartup(e);

            bool startHidden = e.Args.Any(arg => 
                string.Equals(arg, "--hidden", StringComparison.OrdinalIgnoreCase)
            );

            MainWindow window = new MainWindow();
            MainWindow = window;

            if(!startHidden ) {
                window.Show();
            }
        }
    }
}