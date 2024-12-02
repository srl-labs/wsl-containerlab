docker rm wsl_export

docker build . --tag ghcr.io/kaelemc/clab-wsl-debian

mkdir /mnt/c/temp/
mv /mnt/c/temp/clab.wsl /mnt/c/temp/clab.wsl.old

docker run -t --name wsl_export ghcr.io/kaelemc/clab-wsl-debian ls /

echo "Copying..."
docker export wsl_export > /mnt/c/temp/clab.wsl

echo "Cleaning up..."
docker rm wsl_export