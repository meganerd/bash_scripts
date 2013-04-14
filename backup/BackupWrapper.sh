#!/bin/bash
# BackupWrapper.sh
# written by: Gustin Johnson <gustin@meganerd.ca>
# version: 0.3
#
## Begin variables section: 
##
# Must be one of: RsyncRun  RdiffRun RdiffLocal DuplicityNetRun or DuplicityFileRun
BackupFunction="RdiffLocal"

# HOST may also be an Amazon S3 container name  
HOST=localhost
LocalDir="/opt/backup/rdiff_dir"
USERNAME=userid
PORT=22
# Deprecated
#SSH_CIPHER="blowfish"
SSH_KEY="/usr/local/lib/mykey.id_rsa"	# this is the path to the rsa/dsa key

# local_path is an array.  Put the directories to be backed up inside double quotes
# be sure to not use a trailing '/' as this messes up directory creation for some methods like rsync.
declare -a  sourcedir=( "/etc" "/usr/local" "/home" )

REMOTE_PATH="/remote/path"	# path on the remote host to save files to
					# duplicty creates a lot of files, this is 
					# recommended to be set.

# Duplicity Specific Options

# Valid options for DUPLICITY_TRANSPORT might be: "scp" "s3-http" "hsi" see duplicity --help for more
DUPLICITY_TRANSPORT="ssh"

# GPG key to use (the secret key must be in the root user's keyring), Duplicity only option.
GPG_KEY=""
GPG_PASSPHRASE=""

PINGHOST=$HOST	# if we cannot ping the backup server, change this value to something we can ping, to test for network connectivity.

## End variables section:

## ======== You should not need to edit anything below this line ========= ##

TIMESTAMP=`date +%F.%M`			# not currently used.  

# number of elements in the array.  Should not need to be changed.
# used to control the number of times the backup loop runs, should be once on every
# path in the array.
elements="${#sourcedir[*]}"

## define functions ##

CheckNet ()
{
  ping -c 1 $HOST  >& /dev/null ; # Checking to see if we have net connectivity to the backup server
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
