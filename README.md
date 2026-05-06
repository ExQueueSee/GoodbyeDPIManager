# GoodbyeDPI Manager

Lightweight Windows GUI for managing the GoodbyeDPI background service. This application provides an intuitive way to start/stop/restart/configure GoodbyeDPI without needing to interact with the command line after it was installed on your computer. Visit [this link](https://github.com/ValdikSS/GoodbyeDPI) for GoodbyeDPI service source code and installation instructions. If you are from Turkiye and the combination of your ISP + GoodbyeDPI are acting funny, you can visit [this link](https://github.com/cagritaskn/GoodbyeDPI-Turkey) for the version of GoodbyeDPI altered for Turkish users.

## Features

* **Easy Service Management:** Start, stop, and restart the GoodbyeDPI service with a single click.
* **A few quality-of-life options:** The app can start with Windows, start hidden, and stay in the tray if you want it to.
* **Lightweight:** Built with C# and WPF on modern .NET, ensuring minimal RAM and CPU usage.

## Installation

1. Go to the [Releases](../../releases/latest) page.
2. Download the latest `GoodbyeDPIManager-win-Setup.exe` file.
3. Run the installer and follow the standard setup wizard.
4. Once installed, you can launch **GoodbyeDPI Manager** directly from your Windows Start Menu.

## Building from Source

If you want to compile the application yourself, you will need:

* [Visual Studio 2022](https://visualstudio.microsoft.com/)
* [.NET 10.0 SDK](https://dotnet.microsoft.com/) (or the relevant .NET version the project is currently targeting)

1. Clone the repository:
   ```powershell
   git clone https://github.com/ExQueueSee/GoodbyeDPIManager.git
   cd GoodbyeDPIManager
   ```
2. Open `GoodbyeDPIManager.slnx` in Visual Studio.
3. Ensure your target framework is set correctly in the project properties.
4. Build the solution.

If you want to create the same kind of release build that is used for the installer, you can also run:

```powershell
.\scripts\build-release.ps1
```

This publishes the app to `publish/win-x64` and creates the Velopack release files under `Releases`.

## Releases

The installer and update packages are built from the files pushed to GitHub, not from whatever random local publish folder happens to exist on my computer. When a new version tag such as `v1.4` is pushed, GitHub Actions builds the app, creates Velopack packages, and attaches the setup/update files to the GitHub Release.

Velopack is also what lets the app check GitHub Releases and tell the user when a newer version is available. If the user wants the update right then, the app can download and apply it without making them hunt down the release page manually.

For a new release, the general idea is:

```powershell
git tag v1.4
git push origin v1.4
```

## Contributing

Pull requests are welcome. This was a project idea that was very easy to come up with and also develop. I just wanted to have a proper GUI to start, stop, or restart the service because the service was acting funny from time to time which resulted in many websites requiring DPI bypass not loading properly unless I restarted the service.

If you ever have an idea to further expand this project in any way (which I don't think is possible because the projects main idea is pretty straightforward), as I said, I am open to consider pull requests.

## License

This project is open-source and available under the [MIT License](LICENSE.txt).

---
