using System;
using System.ComponentModel;
using System.Diagnostics;
using System.ServiceProcess;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;
using Velopack;
using Velopack.Sources;
using Wpf.Ui.Controls;
using WinForms = System.Windows.Forms;

namespace GoodbyeDPIManager
{
    public partial class MainWindow : FluentWindow
    {
        private readonly string serviceName = "GoodbyeDPI";
        private readonly string registryPath = @"HKEY_CURRENT_USER\Software\GoodbyeDPIManager";
        private const string UpdateRepositoryUrl = "https://github.com/ExQueueSee/GoodbyeDPIManager";

        private DispatcherTimer? timer;

        private WinForms.NotifyIcon? _notifyIcon;
        private bool _isExplicitExit = false;

        public MainWindow()
        {
            InitializeComponent();
            LoadSettings();
            SetupTrayIcon();
            SetupTimer();
            UpdateStatus();
            Loaded += MainWindow_Loaded;

            if (StartupCheckBox.IsChecked == true)
            {
                ManageStartupTask(enable: true, startHidden: HideOnStartupCheckBox.IsChecked == true);
            }

            if (StartServiceCheckBox.IsChecked == true)
            {
                _ = ExecuteServiceCommandAsync(ServiceControllerStatus.Running);
            }
        }

        private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            Loaded -= MainWindow_Loaded;
            await CheckForUpdatesAsync(showNoUpdateMessage: false);
        }

        private void SetupTrayIcon()
        {
            _notifyIcon = new WinForms.NotifyIcon
            {
                Text = "GoodbyeDPI Manager",
                Visible = true,
                Icon = System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath!)
            };

            var contextMenu = new WinForms.ContextMenuStrip();
            contextMenu.Items.Add("Open GoodbyeDPI Manager", null, (s, e) => ShowWindow());
            contextMenu.Items.Add(new WinForms.ToolStripSeparator());
            contextMenu.Items.Add("Exit", null, (s, e) => ExitApplication());

            _notifyIcon.ContextMenuStrip = contextMenu;
            _notifyIcon.MouseClick += (s, e) =>
            {
                if (e.Button == WinForms.MouseButtons.Left) ShowWindow();
            };
        }

        private void ShowWindow()
        {
            this.Show();
            this.WindowState = WindowState.Normal;
            this.Activate();
        }

        private void ExitApplication()
        {
            _isExplicitExit = true;
            System.Windows.Application.Current.Shutdown();
        }

        protected override void OnClosing(CancelEventArgs e)
        {
            if (BackgroundCheckBox.IsChecked == true && !_isExplicitExit)
            {
                e.Cancel = true;
                this.Hide();
            }
            else
            {
                if (_notifyIcon != null)
                {
                    _notifyIcon.Visible = false;
                    _notifyIcon.Dispose();
                }
                base.OnClosing(e);
            }
        }

        private void LoadSettings()
        {
            int runAtStartup = (int)(Registry.GetValue(registryPath, "RunAtStartup", 0) ?? 0);
            int hideOnStartup = (int)(Registry.GetValue(registryPath, "HideOnStartup", 0) ?? 0);
            int startOnLaunch = (int)(Registry.GetValue(registryPath, "StartOnLaunch", 0) ?? 0);
            int runInBackground = (int)(Registry.GetValue(registryPath, "RunInBackground", 0) ?? 0);

            StartupCheckBox.IsChecked = runAtStartup == 1;
            HideOnStartupCheckBox.IsChecked = runAtStartup == 1 && hideOnStartup == 1;
            StartServiceCheckBox.IsChecked = startOnLaunch == 1;
            BackgroundCheckBox.IsChecked = runInBackground == 1;

            UpdateDependentSettingsState();
        }

        private void UpdateDependentSettingsState()
        {
            bool startupEnabled = StartupCheckBox.IsChecked == true;

            HideOnStartupCheckBox.IsEnabled = startupEnabled;
            HideOnStartupContainer.Opacity = startupEnabled ? 1.0 : 0.45;

            if (!startupEnabled)
            {
                HideOnStartupCheckBox.IsChecked = false;
            }
        }

        private void Settings_Changed(object sender, RoutedEventArgs e)
        {
            UpdateDependentSettingsState();

            bool runAtStartup = StartupCheckBox.IsChecked == true;
            bool hideOnStartup = runAtStartup && HideOnStartupCheckBox.IsChecked == true;
            bool startOnLaunch = StartServiceCheckBox.IsChecked == true;
            bool runInBackground = BackgroundCheckBox.IsChecked == true;

            Registry.SetValue(registryPath, "RunAtStartup", runAtStartup ? 1 : 0);
            Registry.SetValue(registryPath, "HideOnStartup", hideOnStartup ? 1 : 0);
            Registry.SetValue(registryPath, "StartOnLaunch", startOnLaunch ? 1 : 0);
            Registry.SetValue(registryPath, "RunInBackground", runInBackground ? 1 : 0);

            ManageStartupTask(runAtStartup, hideOnStartup);
        }

        private void ManageStartupTask(bool enable, bool startHidden)
        {
            try
            {
                string taskName = "GoodbyeDPIManager_Startup";
                string exePath = Environment.ProcessPath!;

                string taskRunCommand = startHidden
                    ? $"\"{exePath}\" --hidden"
                    : $"\"{exePath}\"";

                ProcessStartInfo psi = new()
                {
                    FileName = "schtasks.exe",
                    WindowStyle = ProcessWindowStyle.Hidden,
                    CreateNoWindow = true,
                    UseShellExecute = false
                };

                if (enable)
                {
                    psi.ArgumentList.Add("/create");
                    psi.ArgumentList.Add("/tn");
                    psi.ArgumentList.Add(taskName);
                    psi.ArgumentList.Add("/tr");
                    psi.ArgumentList.Add(taskRunCommand);
                    psi.ArgumentList.Add("/sc");
                    psi.ArgumentList.Add("onlogon");
                    psi.ArgumentList.Add("/rl");
                    psi.ArgumentList.Add("highest");
                    psi.ArgumentList.Add("/f");
                }
                else
                {
                    psi.ArgumentList.Add("/delete");
                    psi.ArgumentList.Add("/tn");
                    psi.ArgumentList.Add(taskName);
                    psi.ArgumentList.Add("/f");
                }

                using Process? process = Process.Start(psi);
                if (process == null)
                {
                    throw new InvalidOperationException("Could not start schtasks.exe.");
                }

                process.WaitForExit();

                if (enable && process.ExitCode != 0)
                {
                    throw new InvalidOperationException($"schtasks.exe exited with code {process.ExitCode}.");
                }
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show(
                    $"Failed to modify startup settings.\nDetails: {ex.Message}",
                    "Settings Error",
                    System.Windows.MessageBoxButton.OK,
                    System.Windows.MessageBoxImage.Error
                );
            }
        }

        private void SetupTimer()
        {
            timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
            timer.Tick += (s, e) => UpdateStatus();
            timer.Start();
        }

        private void UpdateStatus()
        {
            try
            {
                using (ServiceController sc = new (serviceName))
                {
                    switch (sc.Status)
                    {
                        case ServiceControllerStatus.Running:
                            StatusText.Text = "RUNNING";
                            StatusText.Foreground = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#4CAF50"));
                            StatusBorder.Background = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#334CAF50"));
                            break;
                        case ServiceControllerStatus.Stopped:
                            StatusText.Text = "STOPPED";
                            StatusText.Foreground = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#F44336"));
                            StatusBorder.Background = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#33F44336"));
                            break;
                        default:
                            StatusText.Text = sc.Status.ToString().ToUpper();
                            StatusText.Foreground = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#FFC107"));
                            StatusBorder.Background = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#33FFC107"));
                            break;
                    }
                }
            }
            catch
            {
                StatusText.Text = "NOT FOUND";
                StatusText.Foreground = System.Windows.Media.Brushes.Gray;
                StatusBorder.Background = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#33808080"));
            }
        }

        private async void Start_Click(object sender, RoutedEventArgs e) => await ExecuteServiceCommandAsync(ServiceControllerStatus.Running);
        private async void Stop_Click(object sender, RoutedEventArgs e) => await ExecuteServiceCommandAsync(ServiceControllerStatus.Stopped);

        private async void CheckUpdates_Click(object sender, RoutedEventArgs e) => await CheckForUpdatesAsync(showNoUpdateMessage: true);

        private async void Restart_Click(object sender, RoutedEventArgs e)
        {
            var btn = sender as Wpf.Ui.Controls.Button;
            string originalText = btn?.Content?.ToString() ?? "Restart";

            try
            {
                this.IsEnabled = false;

                if (btn != null)
                {
                    btn.Content = "Restarting...";
                    btn.Icon = new Wpf.Ui.Controls.SymbolIcon { Symbol = Wpf.Ui.Controls.SymbolRegular.Clock24 };
                }

                await ExecuteServiceCommandAsync(ServiceControllerStatus.Stopped);

                await Task.Delay(2000);

                await ExecuteServiceCommandAsync(ServiceControllerStatus.Running);
            }
            finally
            {
                if (btn != null)
                {
                    btn.Content = originalText;
                    btn.Icon = new Wpf.Ui.Controls.SymbolIcon { Symbol = Wpf.Ui.Controls.SymbolRegular.ArrowClockwise24 };
                }

                this.IsEnabled = true;
                UpdateStatus();
            }
        }

        private async Task ExecuteServiceCommandAsync(ServiceControllerStatus targetStatus)
        {
            try
            {
                await Task.Run(() =>
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
                });

                UpdateStatus();
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"Failed to execute command.\nDetails: {ex.Message}", "Error", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
            }
        }

        private async Task CheckForUpdatesAsync(bool showNoUpdateMessage)
        {
            object? originalToolTip = CheckUpdatesButton.ToolTip;
            bool originalEnabled = CheckUpdatesButton.IsEnabled;

            try
            {
                CheckUpdatesButton.IsEnabled = false;
                CheckUpdatesButton.ToolTip = "Checking for updates";
                CheckUpdatesButton.Icon = new Wpf.Ui.Controls.SymbolIcon { Symbol = Wpf.Ui.Controls.SymbolRegular.Clock24 };

                UpdateManager updateManager = new(new GithubSource(UpdateRepositoryUrl, "", false));

                if (!updateManager.IsInstalled)
                {
                    if (showNoUpdateMessage)
                    {
                        System.Windows.MessageBox.Show(
                            "Update checks will work after this app is installed with the Velopack installer.",
                            "Updates",
                            System.Windows.MessageBoxButton.OK,
                            System.Windows.MessageBoxImage.Information
                        );
                    }

                    return;
                }

                VelopackAsset? pendingUpdate = updateManager.UpdatePendingRestart;
                if (pendingUpdate != null)
                {
                    var restartChoice = System.Windows.MessageBox.Show(
                        $"An update to GoodbyeDPI Manager v{pendingUpdate.Version} is ready.\n\nRestart now to finish installing it?",
                        "Update ready",
                        System.Windows.MessageBoxButton.YesNo,
                        System.Windows.MessageBoxImage.Information
                    );

                    if (restartChoice == System.Windows.MessageBoxResult.Yes)
                    {
                        updateManager.ApplyUpdatesAndRestart(pendingUpdate);
                    }

                    return;
                }

                UpdateInfo? updateInfo = await updateManager.CheckForUpdatesAsync();
                if (updateInfo == null)
                {
                    if (showNoUpdateMessage)
                    {
                        System.Windows.MessageBox.Show(
                            "You are already using the latest version.",
                            "Updates",
                            System.Windows.MessageBoxButton.OK,
                            System.Windows.MessageBoxImage.Information
                        );
                    }

                    return;
                }

                string latestVersion = updateInfo.TargetFullRelease.Version.ToString();
                var updateChoice = System.Windows.MessageBox.Show(
                    $"GoodbyeDPI Manager v{latestVersion} is available.\n\nDownload and install it now?",
                    "Update available",
                    System.Windows.MessageBoxButton.YesNo,
                    System.Windows.MessageBoxImage.Information
                );

                if (updateChoice != System.Windows.MessageBoxResult.Yes)
                {
                    return;
                }

                CheckUpdatesButton.ToolTip = "Downloading update";

                await updateManager.DownloadUpdatesAsync(updateInfo, progress =>
                {
                    Dispatcher.Invoke(() => CheckUpdatesButton.ToolTip = $"Downloading {progress}%");
                });

                System.Windows.MessageBox.Show(
                    "The update is ready. GoodbyeDPI Manager will restart to finish installing it.",
                    "Update ready",
                    System.Windows.MessageBoxButton.OK,
                    System.Windows.MessageBoxImage.Information
                );

                updateManager.ApplyUpdatesAndRestart(updateInfo.TargetFullRelease);
            }
            catch (Exception ex)
            {
                if (showNoUpdateMessage)
                {
                    System.Windows.MessageBox.Show(
                        $"Failed to check for updates.\nDetails: {ex.Message}",
                        "Update Error",
                        System.Windows.MessageBoxButton.OK,
                        System.Windows.MessageBoxImage.Error
                    );
                }
                else
                {
                    Debug.WriteLine($"Update check failed: {ex}");
                }
            }
            finally
            {
                CheckUpdatesButton.ToolTip = originalToolTip;
                CheckUpdatesButton.Icon = new Wpf.Ui.Controls.SymbolIcon { Symbol = Wpf.Ui.Controls.SymbolRegular.ArrowClockwise24 };
                CheckUpdatesButton.IsEnabled = originalEnabled;
            }
        }

        private void OpenSettings_Click(object sender, RoutedEventArgs e) { MainView.Visibility = Visibility.Collapsed; SettingsView.Visibility = Visibility.Visible; }
        private void CloseSettings_Click(object sender, RoutedEventArgs e) { SettingsView.Visibility = Visibility.Collapsed; MainView.Visibility = Visibility.Visible; }
    }
}
