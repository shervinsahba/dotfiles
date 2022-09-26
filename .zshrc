# Lines configured by zsh-newuser-install
HISTFILE=~/.config/zsh/histfile
HISTSIZE=5000
SAVEHIST=5000
setopt autocd
unsetopt beep
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/shervin/.zshrc'
autoload -Uz compinit
compinit
# End of lines added by compinstall

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@a
## Keybinds

# home and end keys
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
# alt+left/right
bindkey "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## fzf settings
source ~/.config/fzf/config-zsh

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@a
### aliases
[[ -f ~/.aliases ]] && source "$HOME"/.aliases

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@a
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/shervin/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/shervin/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/shervin/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/shervin/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## pywal colors in terminal and tty
(/usr/bin/cat ~/.cache/wal/sequences &)  # not needed if pywal included in kitty
source "$HOME"/.cache/wal/colors-tty.sh

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## z.lua autojump with fzf integration
if [[ -f /usr/share/z.lua/z.lua ]]; then
  eval "$(lua /usr/share/z.lua/z.lua --init bash enhanced once fzf)"
  export _Z_DATA=$HOME/.zlua
fi

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## kitty
if test -n "$KITTY_INSTALLATION_DIR"; then
    export KITTY_SHELL_INTEGRATION="enabled"
    autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
    kitty-integration
    unfunction kitty-integration
fi

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@a
## Starship prompt
eval "$(starship init zsh)"
