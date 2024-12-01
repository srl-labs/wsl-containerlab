docker rm wsl_export

docker build . --tag ghcr.io/kaelemc/clab-wsl-debian

docker run -t --name wsl_export ghcr.io/kaelemc/clab-wsl-debian ls /

sudo rm /mnt/c/temp/clab.wsl.old
sudo mv /mnt/c/temp/clab.wsl /mnt/c/temp/clab.wsl.old

echo "Exporting to clab.wsl"

docker export wsl_export > /mnt/c/temp/clab.wsl

echo "Cleaning up"

docker rm wsl_export
