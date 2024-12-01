# wsl-clab

# Steps

1. Build the container

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

# Usage of the distro

Enter the distro with `wsl -d clabWSL`

Uninstall with `wsl --unregister clabWSL`

# Sources

https://learn.microsoft.com/en-us/windows/wsl/use-custom-distro#export-the-tar-from-a-container
https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro
