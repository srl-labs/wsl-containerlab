#!/usr/bin/env bash
# atuin
# bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)
curl -LsSf https://github.com/atuinsh/atuin/releases/download/v18.3.0/atuin-installer.sh | sh

# theme
git clone --depth 1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# zsh-autosuggestions and autocompletions
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autocomplete

# syntax highlighting
git clone --depth 1 https://github.com/z-shell/F-Sy-H.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/F-Sy-H

###
### Shell completions
###

containerlab completion zsh > _containerlab
mv _containerlab ~/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_containerlab

cat ~/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_containerlab

ls -l ~/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/
# add clab alias to the completions
sed -i 's/compdef _containerlab containerlab/compdef _containerlab containerlab clab/g' "/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_containerlab"
