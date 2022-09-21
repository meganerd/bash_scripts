# Create a /tmp folder structure if it does not already exist.
if [ ! -d  /tmp/gbjohnso/Downloads ]
    then mkdir -p /tmp/$USER/Downloads
    bindfs /tmp/$USER $HOME/tmp
fi

if [ -d ~/bin ]; then
        export PATH="$PATH:~/bin"
fi

if [ -d ~/.cargo/bin ]; then
    export PATH="$PATH:~/.cargo/bin"
fi

if [ -d ~/go/bin ]; then
    export PATH="$PATH:~/go/bin"
    export GOPATH="$HOME/go"
fi

if [ -d /usr/local/go/bin ]; then
    export PATH="$PATH:/usr/local/go/bin"
fi

#eval "(ssh-agent -s)"
#ssh-add ~/.ssh/hostkey

# Ansible vault password file
export ANSIBLE_VAULT_PASSWORD_FILE=$HOME/.ssh/vault.txt
#source $HOME/.cargo/env

export EDITOR=$(which vim)
alias buttons-to-right="gconftool -s /apps/metacity/general/button_layout -t string menu:minimize,maximize,close"
alias ltcp="sudo lsof -i -sTCP:LISTEN -P"
export  PATH=~/bin/android-studio/bin:${PATH}
alias warpspeed='eval "$(starship init bash)"'

# system enhancements
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ls='ls --color=auto'
alias out="cat /etc/motd;logout"
alias lw="ls -CGa --color=auto"
alias l='ls $LS_OPTIONS -lA'
alias stop="/sbin/shutdown -c"
alias getweather="curl wttr.in"

# Disabled as the the geektools proxy seems unresponsive
#alias whois="whois -h whois.geektools.com"
alias dus="du -Pachx --max-depth=1 . | sort -h"
alias sdus="sudo du -Pachx --max-depth=1 . | sort -h"
alias apt-upgrade="sudo aptitude update ; sudo aptitude dist-upgrade"
alias h="history | grep "
alias rdp="rdesktop -g 1280x800 -P -z -r sound:local -r clipboard:PRIMARYCLIPBOARD"
# directory tree - http://www.shell-fu.org/lister.php?id=209
alias dirf='find . -type d | sed -e "s/[^-][^\/]*\//  |/g" -e "s/|\([^ ]\)/|-\1/"'
# count files by type - http://www.shell-fu.org/lister.php?id=173
alias ftype="find ${*-.} -type f | xargs file | awk -F, '\''{print $1}'\'' | awk '\''{$1=NULL;print $0}'\'' | sort | uniq -c | sort -nr"
alias logwatch="tail -f /var/log/messages"
alias buttons-to-right="gconftool -s /apps/metacity/general/button_layout -t string menu:minimize,maximize,close"
alias wget-recursive="wget -r --level=5 -nH -N -np"
alias ggl="git log --all --decorate --oneline --graph"

manopt() {
local cmd=$1 opt=$2
[[ $opt == -* ]] || { (( ${#opt} == 1 )) && opt="-$opt" || opt="--$opt"; }
man "$cmd" | col -b | awk -v opt="$opt" -v RS= '$0 ~ "(^|,)[[:blank:]]+" opt "([[:punct:][:space:]]|$)"'
}

# Put all local system specific aliases into a ~/.bash_aliases_local file
if [ -f ~/.bash_alaises_local ]
then . ~/.bash_aliases_local;
fi

parse_git_branch() {
git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

export PS1="\e[33;1m\u\033[0m\e[32;1m@\e[36;1m\h\e[0m \e[32;1m<\t> \e[33;1m\w\e[0m\e[\033[33m\]\$(parse_git_branch)\[\033[00m\]\n\$ "
export PS2=""
export PS3=""
export PS4=""

    
