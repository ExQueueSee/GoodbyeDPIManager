using System.Runtime.InteropServices;
using System.Windows;

namespace GoodbyeDPIManager
{
    public partial class App : System.Windows.Application
    {
        [DllImport("shell32.dll", SetLastError = true)]
        static extern void SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);

        protected override void OnStartup(StartupEventArgs e)
        {
            // This string acts as your app's unique identity in Windows
            SetCurrentProcessExplicitAppUserModelID("AtaberkTekin.GoodbyeDPIManager");
            base.OnStartup(e);
        }
    }
}