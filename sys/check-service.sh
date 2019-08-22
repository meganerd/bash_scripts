#!/bin/bash
# Found at: https://www.cyberciti.biz/faq/bash-check-if-process-is-running-or-notonlinuxunix/
SERVICE="haproxy"
if pgrep -x "$SERVICE" >/dev/null
then
    echo "$SERVICE is running"
else
    echo "$SERVICE stopped"
    # uncomment to start SERVICE if stopped
     systemctl start $SERVICE
    # mail  
fi