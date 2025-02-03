(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv export zsh)"
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv hook zsh)"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=40
ZSH_AUTOSUGGEST_HISTORY_IGNORE="?(#c50,)"
export SAVEHIST=1000000000
export HISTFILESIZE=1000000000
setopt inc_append_history
setopt extended_history
setopt hist_ignore_all_dups
setopt hist_ignore_space
zstyle ':autocomplete:tab:*' insert-unambiguous no
zstyle ':autocomplete:*' widget-style menu-select
zstyle ':autocomplete:*' min-input 1
zstyle ':autocomplete:history-search-backward:*' list-lines 20
zstyle ':completion:*'  list-colors '=*=97'
zstyle ':bracketed-paste-magic' active-widgets '.self-*'
plugins=(brew git pip python F-Sy-H zsh-autocomplete zsh-autosuggestions colored-man-pages kubectl)
source $ZSH/oh-my-zsh.sh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH="$HOME/.atuin/bin:$PATH"
eval "$(atuin init zsh)"
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
export PATH=$PATH:/usr/local/go/bin:~/go/bin
cd ~
echo clab | sudo -S mkdir -p /run/docker/netns
