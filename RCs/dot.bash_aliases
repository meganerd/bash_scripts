# Create a /tmp folder structure if it does not already exist.
if [ ! -d  /tmp/$USER/Downloads ] ; then 
    mkdir -p /tmp/$USER/Downloads
    echo Directory does not exit
fi

if [ -f $(which bindfs) ] ; then 
        bindfs /tmp/$USER $HOME/tmp
    else 
    echo "bindfs not found, please install it."
fi

if [ -d $HOME/airflow ]
    then export AIRFLOW_HOME=~/airflow
    else mkdir $HOME/airflow
        export AIRFLOW_HOME=~/airflow
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

if [ -f $(which xclip) ]; then 
    alias pbcopy_linux='xclip -selection clipboard'
    alias pbpaste_linux='xclip -selection clipboard -o'
else 
    echo "xclip not installed, not setting pbcopy alias."
fi

#eval "(ssh-agent -s)"
#ssh-add ~/.ssh/hostkey

# Ansible vault password file
export ANSIBLE_VAULT_PASSWORD_FILE=$HOME/.ssh/vault.txt
#source $HOME/.cargo/env

export EDITOR=$(which vim)
alias apt_reinstall='for each in $(sudo apt list --upgradable |grep -v Listing |cut -f 1 -d "/") ; do sudo apt reinstall -y $each ; done'
alias buttons-to-right="gconftool -s /apps/metacity/general/button_layout -t string menu:minimize,maximize,close"
alias ltcp="sudo lsof -i -sTCP:LISTEN -P +c 0"
export  PATH=~/bin/android-studio/bin:${PATH}
alias warpspeed='eval "$(starship init bash)"'
alias physicaldisks="sudo fsarchiver probe |& grep -v loop | grep -v ram"
alias tss="sudo tailscale status"

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
alias ip='ip -color=auto'
alias tshark='tshark --color'

# Disabled as the the geektools proxy seems unresponsive
#alias whois="whois -h whois.geektools.com"
alias dus="du -Pachx --max-depth=1 . | sort -h"
alias sdus="sudo du -Pachx --max-depth=1 . | sort -h"
alias apt-upgrade="sudo aptitude update ; sudo aptitude dist-upgrade"
alias h="history | grep "
alias rdp="rdesktop -g 1920x1080 -P -z -r sound:local -r clipboard:PRIMARYCLIPBOARD"
# directory tree - http://www.shell-fu.org/lister.php?id=209
alias dirf='find . -type d | sed -e "s/[^-][^\/]*\//  |/g" -e "s/|\([^ ]\)/|-\1/"'
# count files by type - http://www.shell-fu.org/lister.php?id=173
alias ftype="find ${*-.} -type f | xargs file | awk -F, '\''{print $1}'\'' | awk '\''{$1=NULL;print $0}'\'' | sort | uniq -c | sort -nr"
alias logwatch="tail -f /var/log/messages"
alias wget-recursive="wget -r --level=5 -nH -N -np"
alias ggl="git log --all --decorate --oneline --graph"
alias snyktest="snyk container test --severity-threshold=high"
alias trimws="sed -i 's/[[:space:]]*$//'"

manopt() {
local cmd=$1 opt=$2
[[ $opt == -* ]] || { (( ${#opt} == 1 )) && opt="-$opt" || opt="--$opt"; }
man "$cmd" | col -b | awk -v opt="$opt" -v RS= '$0 ~ "(^|,)[[:blank:]]+" opt "([[:punct:][:space:]]|$)"'
}

# Put all local system specific aliases into a ~/.bash_aliases_local file
if [ -f ~/.bash_aliases_local ]
then . ~/.bash_aliases_local;
fi

parse_git_branch() {
git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

export PS1="\e[90;1m\u\033[0m\e[32;1m@\e[34;1m\h\e[0m \e[32;1m<\t> \e[34;1m\w\e[0m\e[\033[33m\]\$(parse_git_branch)\[\033[00m\]\n\$ "
export PS2=""
export PS3=""
export PS4=""

sha256_find() { 
find "$1" -type f -exec sha256sum -b {} + |  grep -F "$2"
} 

waitforit_wrapper() {
 if [ -z "$2" ]
 then SSH_USER="$USER"
 else SSH_USER="$2" 
 fi
    wait-for-it.sh -p 22 -t 180 -h "$1" -- ssh "$1" -l "$SSH_USER"
}
