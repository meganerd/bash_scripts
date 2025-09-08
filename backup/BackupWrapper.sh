#!/bin/bash
# BackupWrapper.sh
# written by: Gustin Johnson <gustin@meganerd.ca>
# version: 0.4
#
# Modified to use configuration file

# Default config file location
CONFIG_FILE="/etc/BackupWrapper.cfg"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file $CONFIG_FILE not found!"
    echo "Please create the configuration file or specify an alternative location."
    echo "Usage: $0 [config_file_path]"
    exit 1
fi

# Allow override of config file location via command line argument
if [[ $# -eq 1 ]]; then
    CONFIG_FILE="$1"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Specified configuration file $CONFIG_FILE not found!"
        exit 1
    fi
fi

echo "Using configuration file: $CONFIG_FILE"

# Source the configuration file
source "$CONFIG_FILE"

# Validate required variables are set
required_vars=("BackupFunction" "HOST" "USERNAME" "PORT" "SSH_KEY" "sourcedir" "REMOTE_PATH" "PINGHOST")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "Error: Required variable $var is not set in configuration file!"
        exit 1
    fi
done

## ======== You should not need to edit anything below this line ========= ##

TIMESTAMP=$(date +%F_%H.%M)			# not currently used.  

# number of elements in the array.  Should not need to be changed.
# used to control the number of times the backup loop runs, should be once on every
# path in the array.
elements="${#sourcedir[*]}"

## define functions ##

CheckNet ()
{
  ping -c 1 $PINGHOST  >& /dev/null ; # Checking to see if we have net connectivity to the backup server
}

RsyncRun ()
{
  for (( i = 0  ; i < $elements ; i++ ))
  do
  rsync -t -ruz --progress --delete --inplace --rsh="ssh -p $PORT -i $SSH_KEY" ${sourcedir[$i]} $USERNAME@$HOST:$REMOTE_PATH 
  done
}

RdiffRun ()
{
for (( i = 0  ; i < $elements ; i++ ))
do
 /usr/bin/rdiff-backup -v 4 --no-acl --no-eas --create-full-path --remote-schema "ssh -C -p $PORT -i $SSH_KEY %s rdiff-backup --server" ${sourcedir[$i]} $USERNAME@$HOST::$REMOTE_PATH/${sourcedir[$i]}
done
}

RdiffLocal ()
{
for (( i = 0  ; i < $elements ; i++ ))
do
 /usr/bin/rdiff-backup -v 4 --no-acl --no-eas --create-full-path  ${sourcedir[$i]} $LocalDir/${sourcedir[$i]}
done
}

DuplicityNetRun ()
{

 # This environment variable is passed from duplicity to GnuPG
 export PASSPHRASE=$GPG_PASSPHRASE ;

 for (( i = 0  ; i < $elements ; i++ ))
 do
  duplicity --allow-source-mismatch --ssh-options "-oIdentityFile=$SSH_KEY" --encrypt-key $GPG_KEY ${sourcedir[$i]} scp://$USERNAME@$HOST:$PORT/$REMOTE_PATH

 # clearing the PASSPHRASE environment variable since we don't want this hanging around
 done
 export PASSPHRASE="disabled" ;
}

DuplicityFileRun ()
{

 # This environment variable is passed from duplicity to GnuPG
 export PASSPHRASE=$GPG_PASSPHRASE ;

 for (( i = 0  ; i < $elements ; i++ ))
 do
 duplicity --allow-source-mismatch --encrypt-key $GPG_KEY ${sourcedir[$i]} file://$LocalDir

 # clearing the PASSPHRASE environment variable since we don't want this hanging around
 done
 export PASSPHRASE="disabled" ;
}

CheckSize ()
{
for ((  i = 0  ; i < $elements ; i++ ))
 do
  du -sh ${sourcedir[$i]}
done
}

# Setting the time stamp in the log
 echo "### Starting remote backup at `date` ###"
# Check if available via ping, backup if online
if CheckNet ; then
 echo "### Internet connection is alive and kicking, begin backup. ###"
 # if OK then use rsync or duplicity (depending on the function used) to backup the files

# Check and print out the sizes of the folder we are backing up
CheckSize

# Run the selected backup funtion
$BackupFunction

echo " ### completed backup at `date` ###"
 exit 0

else
  echo "### Your internet connection is probably unwell, cannot backup. ###"
  exit 1
fi
