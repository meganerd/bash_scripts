#!/bin/bash
# Check for IPv6 connectivity, and restart the aiccu daemon
# if this check fails

# remote host used to test IPv6 connectivity
REMOTE_HOST=""

# name and path for ssh key if using scp to test connectivity
SSH_KEY=""

# remote_check functions
CheckNet_TCP ()
{
   touch ~/null.bin
   scp -c -i $SSH_KEY ~/null.bin $REMOTE_HOST:
}

CheckNet_ICMP ()
{
  ping6 -c 1 $REMOTE_HOST  >& /dev/null ; 
}
 # Check if available via ping or SCP, then transfer archive file if remote location is online.
if CheckNet_ICMP ; then
        echo "### Internet connection is alive and kicking, Nothing to be done. ###"
        exit 0

else
  echo "### IPv6 connectivity test failed.  Restarting the aiccu daemon. ###"
  service aiccu restart
    exit 1
fi