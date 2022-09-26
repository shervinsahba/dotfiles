# set PATH so it includes user's private bin and src dirs
if [ -d "$HOME/bin" ]; then PATH="$PATH:$HOME/bin"; fi
if [ -d "$HOME/src" ]; then PATH="$PATH:$HOME/src"; fi
if [ -d "$HOME/src/scripts/" ]; then PATH="$PATH:$HOME/src/scripts"; fi
export PATH

