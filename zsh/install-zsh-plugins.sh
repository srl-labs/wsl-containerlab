#!/usr/bin/env bash
# Install atuin
curl -LsSf https://github.com/atuinsh/atuin/releases/download/v18.3.0/atuin-installer.sh | sh

# Install Powerlevel10k theme
git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# Install zsh-autosuggestions and zsh-autocomplete plugins
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete"
# Patch zsh-autocomplete to remove unsupported "-P" option:
sed -i 's/local -P/local/g' "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

# Install syntax highlighting plugin
git clone --depth 1 https://github.com/z-shell/F-Sy-H.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/F-Sy-H"

# Install containerlab completions via the tools completions script:
bash -c "/tmp/install-tools-completions.sh"