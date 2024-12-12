docker rm wsl_export

docker build . --tag ghcr.io/kaelemc/clab-wsl-debian

mkdir /mnt/c/Temp/
mv /mnt/c/Temp/clab.wsl /mnt/c/Temp/clab.wsl.old

docker run -t --name wsl_export ghcr.io/kaelemc/clab-wsl-debian ls /

echo "Copying..."
docker export wsl_export > /mnt/c/Temp/clab.wsl

echo "Cleaning up..."
docker rm wsl_export