FROM debian:bookworm-slim

RUN apt update -y && apt upgrade -y
RUN apt install git curl sudo -y && rm -rf /var/lib/apt/lists/*

RUN curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"

COPY --chmod=644 --chown=root:root ./wsl-distribution.conf /etc/wsl-distribution.conf
COPY --chmod=644 --chown=root:root ./wsl.conf /etc/wsl.conf
COPY --chmod=755 ./oobe.sh /etc/oobe.sh
COPY ./clab_icon.ico /usr/lib/wsl/clab_icon.ico

