#!/usr/bin/env bash
gnmic completion zsh > "/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_gnmic"
# generate gnoic completions
gnoic completion zsh > "/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_gnoic"
# generate gh
gh completion -s zsh > "/home/clab/.oh-my-zsh/custom/plugins/zsh-autocomplete/Completions/_gh"
