# GoodbyeDPI Manager

Lightweight Windows GUI for managing the GoodbyeDPI background service. This application provides an intuitive way to start/stop/restart/configure GoodbyeDPI without needing to interact with the command line after it was installed om your computer. Visit [this link](github.com/ValdikSS/GoodbyeDPI) for GoodbyeDPI service source code and installation instructions. If you are from Turkiye and the combination of your ISP + GoodbyeDPI are acting funny, you can visit [this link](github.com/cagritaskn/GoodbyeDPI-Turkey) for the version of GoodbyeDPI altered for Turkish users. 

## Features

* **Easy Service Management:** Start and stop the GoodbyeDPI service with a single click.
* **Lightweight:** Built with C# and WPF on modern .NET, ensuring minimal RAM and CPU usage.

## Installation

1. Go to the [Releases](../../releases/latest) page.
2. Download the latest `setup.exe` file.
3. Run the installer and follow the standard setup wizard.
4. Once installed, you can launch **GoodbyeDPI Manager** directly from your Windows Start Menu.

## Building from Source

If you want to compile the application yourself, you will need:

* [Visual Studio 2022](https://visualstudio.microsoft.com/)
* [.NET 10.0 SDK](https://dotnet.microsoft.com/) (or the relevant .NET version you are currently targeting)
* [Inno Setup Compiler](https://jrsoftware.org/isdl.php) (Only required if you want to build the installer executable)

1. Clone the repository:
   ```bash
   git clone https://github.com/YourUsername/GoodbyeDPIManager.git
   ```
2. Open `GoodbyeDPIManager.sln` in Visual Studio.
3. Ensure your target framework is set correctly in the project properties.
4. Build the solution.

## Contributing

Pull requests are welcome. This was a project idea that was very easy to come up with and also develop. I just wanted to have a proper GUI to start, stop, or restart the service because the service was acting funny from time to time which resulted in many websites requiring DPI bypass not loading properly unless I restarted the service. 

If you ever have an idea to further expand this project in any way (which I don't think is possible because the projects main idea is pretty straightforward), as I said, I am open to consider pull requests. 

## License

This project is open-source and available under the [MIT License](LICENSE).

---
