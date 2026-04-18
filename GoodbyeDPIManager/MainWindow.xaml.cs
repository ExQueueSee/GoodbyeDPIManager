using System;
using System.Diagnostics;
using System.ServiceProcess;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;
using Wpf.Ui.Controls;

namespace GoodbyeDPIManager
{
    public partial class MainWindow : FluentWindow
    {
        private readonly string serviceName = "GoodbyeDPI";
        private readonly string registryPath = @"HKEY_CURRENT_USER\Software\GoodbyeDPIManager";
        private DispatcherTimer timer;

        public MainWindow()
        {
            InitializeComponent();
            LoadSettings();
            SetupTimer();
            UpdateStatus();

            // Check if we need to start the service automatically
            if (StartServiceCheckBox.IsChecked == true)
            {
                ExecuteServiceCommand(ServiceControllerStatus.Running);
            }
        }

        private void LoadSettings()
        {
            // Load saved settings from Registry
            int runAtStartup = (int)(Registry.GetValue(registryPath, "RunAtStartup", 0) ?? 0);
            int startOnLaunch = (int)(Registry.GetValue(registryPath, "StartOnLaunch", 0) ?? 0);

            StartupCheckBox.IsChecked = runAtStartup == 1;
            StartServiceCheckBox.IsChecked = startOnLaunch == 1;
        }

        private void Settings_Changed(object sender, RoutedEventArgs e)
        {
            // Save settings to Registry
            bool runAtStartup = StartupCheckBox.IsChecked == true;
            bool startOnLaunch = StartServiceCheckBox.IsChecked == true;

            Registry.SetValue(registryPath, "RunAtStartup", runAtStartup ? 1 : 0);
            Registry.SetValue(registryPath, "StartOnLaunch", startOnLaunch ? 1 : 0);

            ManageStartupTask(runAtStartup);
        }

        private void ManageStartupTask(bool enable)
        {
            try
            {
                string taskName = "GoodbyeDPIManager_Startup";
                string exePath = Process.GetCurrentProcess().MainModule.FileName;

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "schtasks.exe",
                    WindowStyle = ProcessWindowStyle.Hidden,
                    CreateNoWindow = true
                };

                if (enable)
                {
                    // /rl highest is the magic command that bypasses UAC
                    psi.Arguments = $"/create /tn \"{taskName}\" /tr \"\\\"{exePath}\\\"\" /sc onlogon /rl highest /f";
                }
                else
                {
                    psi.Arguments = $"/delete /tn \"{taskName}\" /f";
                }

                Process.Start(psi)?.WaitForExit();
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"Failed to modify startup settings.\nDetails: {ex.Message}", "Settings Error", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
            }
        }

        private void SetupTimer()
        {
            timer = new DispatcherTimer();
            timer.Interval = TimeSpan.FromSeconds(2);
            timer.Tick += (s, e) => UpdateStatus();
            timer.Start();
        }

        private void UpdateStatus()
        {
            try
            {
                using (ServiceController sc = new ServiceController(serviceName))
                {
                    switch (sc.Status)
                    {
                        case ServiceControllerStatus.Running:
                            StatusText.Text = "RUNNING";
                            StatusText.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#4CAF50"));
                            StatusBorder.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#334CAF50"));
                            break;
                        case ServiceControllerStatus.Stopped:
                            StatusText.Text = "STOPPED";
                            StatusText.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#F44336"));
                            StatusBorder.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#33F44336"));
                            break;
                        default:
                            StatusText.Text = sc.Status.ToString().ToUpper();
                            StatusText.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#FFC107"));
                            StatusBorder.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#33FFC107"));
                            break;
                    }
                }
            }
            catch (Exception)
            {
                StatusText.Text = "NOT FOUND";
                StatusText.Foreground = Brushes.Gray;
                StatusBorder.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#33808080"));
            }
        }

        private void Start_Click(object sender, RoutedEventArgs e) => ExecuteServiceCommand(ServiceControllerStatus.Running);
        private void Stop_Click(object sender, RoutedEventArgs e) => ExecuteServiceCommand(ServiceControllerStatus.Stopped);

        private void Restart_Click(object sender, RoutedEventArgs e)
        {
            ExecuteServiceCommand(ServiceControllerStatus.Stopped);
            ExecuteServiceCommand(ServiceControllerStatus.Running);
        }

        private void ExecuteServiceCommand(ServiceControllerStatus targetStatus)
        {
            try
            {
                using (ServiceController sc = new ServiceController(serviceName))
                {
                    if (targetStatus == ServiceControllerStatus.Running && sc.Status != ServiceControllerStatus.Running)
                    {
                        sc.Start();
                        sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(5));
                    }
                    else if (targetStatus == ServiceControllerStatus.Stopped && sc.Status != ServiceControllerStatus.Stopped)
                    {
                        sc.Stop();
                        sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(5));
                    }
                }
                UpdateStatus();
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"Failed to execute command.\nDetails: {ex.Message}", "Error", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
            }
        }

        private void OpenSettings_Click(object sender, RoutedEventArgs e)
        {
            MainView.Visibility = Visibility.Collapsed;
            SettingsView.Visibility = Visibility.Visible;
        }

        private void CloseSettings_Click(object sender, RoutedEventArgs e)
        {
            SettingsView.Visibility = Visibility.Collapsed;
            MainView.Visibility = Visibility.Visible;
        }
    }
}