# read by the login shell

# set PATH so it includes user's bin and src dirs
if [ -d "$HOME/bin" ]; then PATH="$PATH:$HOME/bin"; fi
if [ -d "$HOME/src" ]; then PATH="$PATH:$HOME/src"; fi
if [ -d "$HOME/src/scripts/" ]; then PATH="$PATH:$HOME/src/scripts"; fi
export PATH

## editor
export EDITOR=vim
export VISUAL="$EDITOR"

## colors for less, man, etc.
[ -f ~/.config/LESS_TERMCAP ] && source ~/.config/LESS_TERMCAP

## history settings
export HISTSIZE=10000
export HISTFILESIZE=100000
