# ~/.bashrc
# read by interactive non-login bash shells

## if not running interactively, then return and do nothing below
[[ $- != *i* ]] && return

## allow local X connections from root
xhost +local:root > /dev/null 2>&1

## shell options
shopt -s cdspell		# minor errors during cd command are corrected
shopt -s expand_aliases # expand aliases
shopt -s histappend		# history appending instead of overwriting

## tab size in spaces
tabs 4

## bash auto-completion
[ -r /usr/share/bash-completion/bash_completion ] && source /usr/share/bash-completion/bash_completion
complete -cf sudo # sudo completion may not include filenames

## PS1 prompt
if command -v starship &>/dev/null; then
	eval "$(starship init bash)"
fi

## pywal coloring
[[ -f ~/.cache/wal/sequences ]] && (/usr/bin/cat ~/.cache/wal/sequences &)  # terminal colors, not needed for kitty
[[ -f ~/.cache/wal/colors-tty.sh ]] && source ~/.cache/wal/colors-tty.sh    # tty colors

## aliases
[[ -f ~/.aliases ]] && source "$HOME"/.aliases

## stderrred-git (https://github.com/sickill/stderred)
if [ -f /usr/lib/libstderred.so"${LD_PRELOAD:+:$LD_PRELOAD}" ]; then
  export LD_PRELOAD="/usr/lib/libstderred.so${LD_PRELOAD:+:$LD_PRELOAD}"
fi

## fzf settings
[[ -f ~/.config/fzf/config ]] && source ~/.config/fzf/config

## z.lua autojump with fzf integration
if [[ -f /usr/share/z.lua/z.lua ]]; then
  eval "$(lua /usr/share/z.lua/z.lua --init bash enhanced once fzf)"
  export _Z_DATA=$HOME/.zlua
fi

## ruby rbenv
if command -v rbenv &> /dev/null; then 
	eval "$(rbenv init -)"
fi

## nvm (node version manager) 
[[ -f /usr/share/nvm/init-nvm.sh ]] && source /usr/share/nvm/init-nvm.sh
## set nvm global directory
#mkdir -p "${HOME}/.npm-packages"
#npm config set prefix "${HOME}/.npm-packages"
#export PATH="$PATH:$NPM_PACKAGES/bin"
#export MANPATH="${MANPATH-$(manpath)}:$NPM_PACKAGES/share/man"

## yazi wrapper (cd after yazi)
function ya() {
	tmp="$(mktemp -t "yazi-cwd.XXXXX")"
	yazi --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## integrations handled by outside software

## kitty
# BEGIN_KITTY_SHELL_INTEGRATION
if test -n "$KITTY_INSTALLATION_DIR" -a -e "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"; then 
	source "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"
fi
# END_KITTY_SHELL_INTEGRATION

## conda/mamba
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/shervin/mambaforge/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/shervin/mambaforge/etc/profile.d/conda.sh" ]; then
        . "/home/shervin/mambaforge/etc/profile.d/conda.sh"
    else
        export PATH="/home/shervin/mambaforge/bin:$PATH"
    fi
fi
unset __conda_setup

if [ -f "/home/shervin/mambaforge/etc/profile.d/mamba.sh" ]; then
    . "/home/shervin/mambaforge/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<

## guild.ai
[ -s ~/.guild/bash_completion ] && . ~/.guild/bash_completion  # Enable completion for guild

