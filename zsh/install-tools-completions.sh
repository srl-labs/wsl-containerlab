#!/usr/bin/env bash
# Generate gnmic, gnoic, and gh completions:
gnmic completion zsh > "/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_gnmic"
gnoic completion zsh > "/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_gnoic"
gh completion -s zsh > "/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_gh"

# Generate containerlab completions and add alias "clab":
containerlab completion zsh > "/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_containerlab"
sed -i 's/compdef _containerlab containerlab/compdef _containerlab containerlab clab/g' "/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_containerlab"
