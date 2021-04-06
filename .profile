# set PATH so it includes user's private bin and src dirs

if [ -d "$HOME/bin" ] ; then
    PATH="$PATH:$HOME/bin"
fi

if [ -d "$HOME/src" ] ; then
    PATH="$PATH:$HOME/src"
fi

export PATH