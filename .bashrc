# ~/.bashrc

[[ $- != *i* ]] && return  # if not an interactive shell, return without doing anything


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# auto-completion
[ -r /usr/share/bash-completion/bash_completion ] && source /usr/share/bash-completion/bash_completion

complete -cf sudo  # option specified by sudo may not be followed by a filename


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# window title of X terminals
case ${TERM} in
	xterm*|rxvt*|Eterm*|aterm|alacritty|kterm|gnome*|interix|konsole*)
		PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\007"'	;;
	screen*)
		PROMPT_COMMAND='echo -ne "\033_${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\033\\"'	;;
esac


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Set colorful PS1 only on colorful terminals.
# dircolors --print-database uses its own built-in database
# instead of using /etc/DIR_COLORS.  Try to use the external file
# first to take advantage of user additions.  Use internal bash
# globbing instead of external grep binary.

use_color=true
safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
match_lhs=""
[[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
[[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
[[ -z ${match_lhs}    ]] \
	&& type -P dircolors >/dev/null \
	&& match_lhs=$(dircolors --print-database)
[[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true
if ${use_color} ; then
	# colors for ls, grep.  Prefer ~/.dir_colors #64489
	if type -P dircolors >/dev/null ; then
		if [[ -f ~/.dir_colors ]] ; then
			eval $(dircolors -b ~/.dir_colors)
		elif [[ -f /etc/DIR_COLORS ]] ; then
			eval $(dircolors -b /etc/DIR_COLORS)
		fi
	fi

	if [[ ${EUID} == 0 ]] ; then
		PS1='\[\033[01;31m\][   \h\[\033[01;36m\] \W\[\033[01;31m\]]\$\[\033[00m\] '
	else
		PS1='\[\033[01;32m\][\u@\h\[\033[01;37m\] \W\[\033[01;32m\]]\$\[\033[00m\] '
	fi
else
	if [[ ${EUID} == 0 ]] ; then
		# show root@ when we don't have colors
		PS1='\u@\h \W \$ '
	else
		PS1='\u@\h \w \$ '
	fi
fi
unset safe_term match_lhs sh


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# shell options
shopt -s cdspell		# minor errors during cd command are corrected
shopt -s checkwinsize	# check terminal window size. update if needed
shopt -s expand_aliases # expand aliases
shopt -s histappend		# history appending instead of overwriting

xhost +local:root > /dev/null 2>&1	# allow local connections from root


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# # ex - archive extractor, usage: ex <file>
ex ()
{
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1   ;;
      *.tar.gz)    tar xzf $1   ;;
      *.bz2)       bunzip2 $1   ;;
      *.rar)       unrar x $1     ;;
      *.gz)        gunzip $1    ;;
      *.tar)       tar xf $1    ;;
      *.tbz2)      tar xjf $1   ;;
      *.tgz)       tar xzf $1   ;;
      *.zip)       unzip $1     ;;
      *.Z)         uncompress $1;;
      *.7z)        7z x $1      ;;
      *)           echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## environment variables
export EDITOR=/usr/bin/nano
export QT_QPA_PLATFORMTHEME=gtk2 #gtk2, qt5ct


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## aliases

alias sudo='sudo '        # permits using sudo with aliased commands
alias cp='cp -i'          # confirm before overwriting something

alias grep='grep --colour=auto'
alias egrep='grep -E'	  # extended grep
alias fgrep='grep -F'	  # fixed grep
alias less='less -R'	  # allow colorized pipes to less
alias more='less'
alias h='head'
alias t='tail'
alias his='history'

alias ls='ls --color=auto'
alias ll='ls -Flh'
alias lll='ls -Flha'
alias tree1='tree -L 1 -hFC'
alias tree2='tree -L 2 -hFC'
alias tree3='tree -L 3 -hFC'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cl='clear; echo $(date)'

alias c="xclip -selection clipboard"	  # xclip copy
alias p="xclip -selection clipboard -o"   # xclip paste

alias df='df -h'          		# disk space in human-readable sizes
alias free='free -m'      		# shows free memory in MB
alias duh='du -h --max-depth=1' # disk space in human-readable sizes

alias journalctl="journalctl --output=short-iso"	# ISO timestamps

# cd shortcuts
alias cdX='cd /etc/X11/xorg.conf.d/; ll'
alias cdtrash='cd $HOME/.local/share/Trash'
alias cdbin="cd $HOME/bin"
alias cdsrc="cd $HOME/src"
alias cdD="cd $HOME/Downloads"

# cleanup
alias clean-all-uninstalled-packages="paccache -ruk 0"
alias clean-paccache-keep3versions="paccache -rk 3"
alias clean-pacman-orphans="pacman -Qdtq; echo; echo Choose packages to remove manually."
alias clean-journal="journalctl --vacuum-size=50M"
alias clean-garbageremoval="rm -rf $HOME/.local/share/Trash/*"
alias clean-1yearcache="find $HOME/.cache/ -type f -atime +365 -delete"

alias capslock-kill="xmodmap -e 'keycode 66 = Hyper_R NoSymbol Caps_Lock Caps_Lock Caps_Lock Caps_Lock Caps_Lock'"
alias capslock-normal="xmodmap -e 'keycode 66 = Caps_Lock Caps_Lock'"

command -v vim >/dev/null 2>&1 && alias vi=vim
alias subl="subl3"
alias sptd="spotifyd-restart; spt"
alias spotify-tui=sptd
alias spotifyd-restart="systemctl --user restart spotifyd.service"

## GPU test
alias DRIglxgears="DRI_PRIME=1 glxgears"
alias DRIglx="DRI_PRIME=1 glxinfo | grep renderer"

## personal cd and ssh shortcuts
alias cdR="cd $HOME/ACADEMIA/RESEARCH/"
alias cdUW="cd $HOME/ACADEMIA/UW/"
alias hyak="ssh -X ssahba@mox.hyak.uw.edu"
alias sshfs-vergil="sshfs -o allow_other,default_permissions,idmap=user ssahba@vergil.u.washington.edu: /home/shervin/ACADEMIA/UW/vergil/"


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## stderrred-git
## https://github.com/sickill/stderred
# export LD_PRELOAD="/usr/lib/libstderred.so${LD_PRELOAD:+:$LD_PRELOAD}"


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/shervin/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
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
echo $(date)
