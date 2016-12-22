# system enhancements
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ls='ls --color=auto'
alias out="cat /etc/motd;logout"
alias lw="ls -CGa --color=auto"
alias l='ls $LS_OPTIONS -lA'
alias stop="/sbin/shutdown -c"
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
alias restart-nautilus='kill -HUP `ps axf |grep nautilus |grep -v pts | cut -f2 -d " "`'
alias logwatch="tail -f /var/log/messages"
alias buttons-to-right="gconftool -s /apps/metacity/general/button_layout -t string menu:minimize,maximize,close"
alias wget-recursive="wget -r --level=5 -nH -N -np"
alias aptitude-search="aptitude --disable-columns search"



# Put all local system specific aliases into a ~/.bash_aliases_local file
if [ -f ~/.bash_alaises_local ] 
  then include ~/.bash_aliases_local;
  fi

