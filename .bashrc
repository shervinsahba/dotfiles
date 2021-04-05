## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## bash.rc by Shervin Sahba
## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

[[ $- != *i* ]] && return


[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Change the window title of X terminals

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
	# Enable colors for ls, etc.  Prefer ~/.dir_colors #64489
	if type -P dircolors >/dev/null ; then
		if [[ -f ~/.dir_colors ]] ; then
			eval $(dircolors -b ~/.dir_colors)
		elif [[ -f /etc/DIR_COLORS ]] ; then
			eval $(dircolors -b /etc/DIR_COLORS)
		fi
	fi

	if [[ ${EUID} == 0 ]] ; then
		PS1='\[\033[01;31m\][\h\[\033[01;36m\] \W\[\033[01;31m\]]\$\[\033[00m\] '
	else
		PS1='\[\033[01;32m\][\u@\h\[\033[01;37m\] \W\[\033[01;32m\]]\$\[\033[00m\] '
	fi

	alias ls='ls --color=auto'
	alias grep='grep --colour=auto'
	alias egrep='egrep --colour=auto'
	alias fgrep='fgrep --colour=auto'
else
	if [[ ${EUID} == 0 ]] ; then
		# show root@ when we don't have colors
		PS1='\u@\h \W \$ '
	else
		PS1='\u@\h \w \$ '
	fi
fi

unset use_color safe_term match_lhs sh

xhost +local:root > /dev/null 2>&1

complete -cf sudo

# Bash won't get SIGWINCH if another process is in the foreground.
# Enable checkwinsize so that bash will check the terminal size when
# it regains control.  #65623
# http://cnswww.cns.cwru.edu/~chet/bash/FAQ (E11)
shopt -s checkwinsize

shopt -s expand_aliases

# Enable history appending instead of overwriting.  #139609
shopt -s histappend


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## environment variables
## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

export EDITOR=/usr/bin/nano

export QT_QPA_PLATFORMTHEME=gtk2
#export QT_QPA_PLATFORMTHEME=qt5ct

HOMEBIN=$HOME/bin
HOMESRC=$HOME/src
PATH=$PATH:$HOMEBIN
PATH=$PATH:$HOMESRC
export PATH


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## aliases
## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

alias sudo='sudo '        # permits using sudo with aliased commands

# basic commands
alias cp="cp -i"          # confirm before overwriting something
alias df='df -h'          # human-readable sizes
alias free='free -m'      # show sizes in MB
alias more=less
alias ll='ls -Flh'
alias lll='ls -Flha'
alias cl='clear; echo $(date)'
alias h='head'
alias t='tail'
alias his='history'
alias jobs='jobs -l'

# cd shortcuts
alias cdl='cd; ls'
alias cdtrash='cd $HOME/.local/share/Trash'
alias cdX='cd /etc/X11/xorg.conf.d/; ls -l'

# system
alias journalctl="journalctl --output=short-iso"

# filesystem
alias duh='du -h --max-depth=1'
alias treee='tree -L 3'

# xclip copy and paste
alias c="xclip -selection clipboard"
alias p="xclip -selection clipboard -o"

# cleanup
alias clean-sudo-paccache-u0="confirm 'sudo paccache -ruk 0'"
alias clean-sudo-paccache-3="confirm 'sudo paccache -rk 3'"
alias clean-sudo-pacman-orphans="confirm 'pacman -R $(pacman -Qdtq)'"
alias clean-sudo-journal="confirm 'sudo journalctl --vacuum-size=50M'"
alias clean-garbageremoval="confirm 'rm -rf $HOME/.local/share/Trash/*'"
alias clean-1yearcache="confirm 'find $HOME/.cache/ -type f -atime +365 -delete'"

# refresh and set things
alias plasma="killall plasmashell; plasmashell > /dev/null 2>&1 & disown"
alias picommence="picom --config $HOME/.config/picom/picom.conf"
alias x-antishadow="xcompmgr -c -l0 -t0 -r0 -o.00"
alias capslock-kill="xmodmap -e 'keycode 66 = Hyper_R NoSymbol Caps_Lock Caps_Lock Caps_Lock Caps_Lock Caps_Lock'"
alias capslock-normal="xmodmap -e 'keycode 66 = Caps_Lock Caps_Lock'"
alias remap-keys="xmodmap $HOME/.Xmodmap"
alias remap-keys-i3="xmodmap $HOME/.Xmodmap-i3"
alias spotifyd-restart="systemctl --user restart spotifyd.service"

# quick programs
alias vi="nvim"
alias subl="subl3"
#alias sublime="subl"
#alias sublimetext="subl"
alias sptd="spotifyd-restart; spt"
alias spotify-tui=sptd
alias ytop="ytop -c solarized-dark"

## GPU test
alias DRIglxgears="DRI_PRIME=1 glxgears"
alias DRIglx="DRI_PRIME=1 glxinfo | grep renderer"


## aliases programs to run with doubled font size
## Alternatively edit the corresponding application.desktop
## to have Exec=GDK_SCALE=2 app
alias unityhub="GDK_SCALE=2 unityhub"



## personal cd shortcuts
alias cdR="cd $HOME/ACADEMIA/RESEARCH/"
alias cdbin="cd $HOME/bin"
alias cdsrc="cd $HOME/src"

## networks and SSH
alias hyak="ssh -X ssahba@mox.hyak.uw.edu"
alias sshfs-vergil="sshfs -o allow_other,default_permissions,idmap=user ssahba@vergil.u.washington.edu: /home/shervin/ACADEMIA/UW/vergil/"


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## Powerline and Powerline-fonts for Bash, VIM, etc...
## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

## Powerline-Shell
function _update_ps1() {
    PS1=$(powerline-shell $?)
}

# if [[ $TERM != linux && ! $PROMPT_COMMAND =~ _update_ps1 ]]; then
#     PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
# fi


## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## stderrred-git
## https://github.com/sickill/stderred
## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# colorizes all stderr as red
#export LD_PRELOAD="/usr/lib/libstderred.so${LD_PRELOAD:+:$LD_PRELOAD}"



## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

#export TERM=linux

echo $(date)

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

