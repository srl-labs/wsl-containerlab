# wsl-clab

Ensure [WSL 2.4.4](https://github.com/microsoft/WSL/releases/tag/2.4.4) is installed.

Clnoe the repo and build use the build script 

```
./build.sh
```

This will place `clab.wsl` in `C:\temp`. Doubleclick to install the distribution.

- Manual build instructions are below. 

To uninstall execute `wsl --unregister Containerlab` from powershell.

Enter the distribution with `wsl -d Containerlab`

# Manual steps

1. From inside a WSL distro Build the container

```bash
 docker build . --tag ghcr.io/kaelemc/clab-wsl-debian
```

2. Run it and export the filesystem to a tar.gz

```bash
docker run -t --name wsl_export ghcr.io/kaelemc/clab-wsl-debian ls /
docker export wsl_export > /mnt/c/temp/clab.wsl
```

> Create the 'temp' directory on your C: drive if it doesn't exist.

Remove the container to ease with rebuilding
```bash
docker rm wsl_export
```

3. Use it
  
In your windows filesystem at `C:\Temp` should be a file `clab.tar`, ensure the extension is `.wsl`. 

As of [WSL 2.4.4](https://github.com/microsoft/WSL/releases/tag/2.4.4) you can either doubleclick the file, or from powershell type

```powershell
wsl --install --from-file clab.wsl
```

After installation, close and reopen your terminal to ensure proper font rendering and appearance settings are applied correctly. This step is necessary for the terminal to recognize and use the newly installed WSL distribution's display configurations.

We recommend using Windows Terminal for the best experience:
- Windows 11 users: Windows Terminal is installed by default
- Windows 10 users: Download Windows Terminal from the Microsoft Store: [Terminal](https://aka.ms/terminal)




# Sources

https://learn.microsoft.com/en-us/windows/wsl/use-custom-distro#export-the-tar-from-a-container
https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro