FROM debian:bookworm-slim

RUN apt update -y && apt upgrade -y
RUN apt install -y \
    git \
    curl \
    sudo \
    wget 

RUN apt install -y  --no-install-recommends \
    direnv \
    btop \
    iputils-ping \
    tcpdump \
    iproute2 \
    qemu-kvm \
    dnsutils \
    telnet \
    zsh && rm -rf /var/lib/apt/lists/*

# Add the netdevops repository
RUN echo "deb [trusted=yes] https://netdevops.fury.site/apt/ /" | \
    tee -a /etc/apt/sources.list.d/netdevops.list

COPY --chmod=644 --chown=root:root ./wsl-distribution.conf /etc/wsl-distribution.conf
COPY --chmod=644 --chown=root:root ./wsl.conf /etc/wsl.conf
COPY --chmod=755 ./oobe.sh /etc/oobe.sh
COPY ./clab_icon.ico /usr/lib/wsl/clab_icon.ico
COPY ./terminal-profile.json /usr/lib/wsl/terminal-profile.json

# Create clab user and add to sudo group
RUN useradd -m -s /bin/zsh clab && \
    echo "clab:clab" | chpasswd && \
    adduser clab sudo && \
    # Add NOPASSWD sudo rights for clab user
    echo "clab ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/clab && \
    chmod 0440 /etc/sudoers.d/clab && \
    # Copy skel files to clab's home
    cp -r /etc/skel/. /home/clab/ && \
    chown -R clab:clab /home/clab/

# Set clab as default user
ENV USER=clab
USER clab
WORKDIR /home/clab

RUN curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"

# Create SSH key for vscode user to enable passwordless SSH to devices
RUN ssh-keygen -t ecdsa -b 256 -N "" -f ~/.ssh/id_ecdsa

# Install pyenv
RUN bash -c "$(curl https://pyenv.run)"

# Install Oh My Zsh
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

COPY --chown=clab:clab ./zsh/.zshrc /home/clab/.zshrc
COPY --chown=clab:clab ./zsh/.p10k.zsh /home/clab/.p10k.zsh
COPY --chown=clab:clab ./zsh/install-zsh-plugins.sh /tmp/install-zsh-plugins.sh
COPY --chown=clab:clab ./zsh/install-tools-completions.sh /tmp/install-tools-completions.sh
RUN chmod +x /tmp/install-zsh-plugins.sh /tmp/install-tools-completions.sh
USER clab
RUN bash -c "/tmp/install-zsh-plugins.sh && /tmp/install-tools-completions.sh"