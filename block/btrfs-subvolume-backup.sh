#!/bin/bash

# By Marc MERLIN <marc_soft@merlins.org>
# License: Apache-2.0

# Source: http://marc.merlins.org/linux/scripts/
# $Id: btrfs-subvolume-backup 993 2014-05-04 07:42:19Z svnuser $
#
# Documentation and details at
# http://marc.merlins.org/perso/btrfs/2014-03.html#Btrfs-Tips_-Doing-Fast-Incremental-Backups-With-Btrfs-Send-and-Receive

# cron jobs might not have /sbin in their path.
export PATH="$PATH:/sbin"

set -o nounset
set -o errexit
set -o pipefail

# From https://btrfs.wiki.kernel.org/index.php/Incremental_Backup


# bash shortcut for `basename $0`
PROG=${0##*/}
lock=/var/run/$PROG

usage() {
    cat <<EOF
Usage: 
cd /mnt/source_btrfs_pool
$PROG [--init] [--keep|-k num] [--dest hostname] volume_name /mnt/backup_btrfs_pool

Options:
    --init:          Print this help message and exit.
    --keep num:      Keep the last snapshots for local backups (5 by default)
    --dest hostname: If present, ssh to that machine to make the copy.

This will snapshot volume_name in a btrfs pool, and send the diff
between it and the previous snapshot (volume_name.last) to another btrfs
pool (on other drives)

If your backup destination is another machine, you'll need to add a few
ssh commands this script

The num sanpshots to keep is to give snapshots you can recover data from 
and they get deleted after num runs. Set to 0 to disable (one snapshot will
be kept since it's required for the next diff to be computed).
EOF
    exit 0
}

die () {
    msg=${1:-}
    # don't loop on ERR
    trap '' ERR

    rm "$lock"

    echo "$msg" >&2
    echo >&2

    # This is a fancy shell core dumper
    if echo "$msg" | grep -q 'Error line .* with status'; then
	line=$(echo "$msg" | sed 's/.*Error line \(.*\) with status.*/\1/')
	echo " DIE: Code dump:" >&2
	nl -ba "$0" | grep -3 "\b$line\b" >&2
    fi
    
    exit 1
}

# Trap errors for logging before we die (so that they can be picked up
# by the log checker)
trap 'die "Error line $LINENO with status $?"' ERR


init=""
# Keep the last 5 snapshots by default
keep=5
TEMP=$(getopt --longoptions help,usage,init,keep:,dest: -o h,k:,d: -- "$@") || usage
dest=localhost
ssh=""

# getopt quotes arguments with ' We use eval to get rid of that
eval set -- "$TEMP"

while :
do
    case "$1" in
        -h|--help|--usage)
            usage
            shift
            ;;

	--keep|-k)
	    shift
	    keep=$1
	    shift
	    ;;

	--dest|-d)
	    shift
	    dest=$1
	    ssh="ssh $dest"
	    shift
	    ;;

	--init)
	    init=1
	    shift
	    ;;

	--)
	    shift
	    break
	    ;;

        *) 
	    echo "Internal error!"
	    exit 1
	    ;;
    esac
done
[[ $keep -lt 1 ]] && die "Must keep at least one snapshot for things to work ($keep given)"

DATE="$(date '+%Y%m%d_%H:%M:%S')"

[[ $# != 2 ]] && usage
vol="$1"
dest_pool="$2"

# shlock (from inn) does the right thing and grabs a lock for a dead process
# (it checks the PID in the lock file and if it's not there, it
# updates the PID with the value given to -p)
if ! shlock -p $$ -f "$lock"; then
    echo "$lock held for $PROG, quitting" >&2
    exit
fi

if [[ -z "$init" ]]; then
    test -e "${vol}_last" \
	|| die "Cannot sync $vol, ${vol}_last missing. Try --init?"
    src_snap="$(readlink -e "${vol}_last")"
fi
src_newsnap="${vol}_ro.$DATE"
src_newsnaprw="${vol}_rw.$DATE"

$ssh test -d "$dest_pool/" || die "ABORT: $dest_pool not a directory (on $dest)"

btrfs subvolume snapshot -r "$vol" "$src_newsnap"

# There is currently an issue that the snapshots to be used with "btrfs send"
# must be physically on the disk, or you may receive a "stale NFS file handle"
# error. This is accomplished by "sync" after the snapshot
sync

if [[ -n "$init" ]]; then
    btrfs send "$src_newsnap" | $ssh btrfs receive "$dest_pool/"
else
    btrfs send -p "$src_snap" "$src_newsnap" | $ssh btrfs receive "$dest_pool/"
fi

# We make a read-write snapshot in case you want to use it for a chroot
# and some testing with a writeable filesystem or want to boot from a
# last good known snapshot.
btrfs subvolume snapshot "$src_newsnap" "$src_newsnaprw"
$ssh btrfs subvolume snapshot "$dest_pool/$src_newsnap" "$dest_pool/$src_newsnaprw"

# Keep track of the last snapshot to send a diff against.
ln -snf "$src_newsnap" "${vol}_last"
# The rw version can be used for mounting with subvol=vol_last_rw
ln -snf "$src_newsnaprw" "${vol}_last_rw"
$ssh ln -snf "$src_newsnaprw" "$dest_pool/${vol}_last_rw"

# How many snapshots to keep on the source btrfs pool (both read
# only and read-write).
ls -rd "${vol}"_ro* | tail -n +$(( keep + 1 ))| while read -r snap
do
    btrfs subvolume delete "$snap"
done
ls -rd "${vol}"_rw* | tail -n +$(( keep + 1 ))| while read -r snap
do
    btrfs subvolume delete "$snap"
done

# Same thing for destination (assume the same number of snapshots to keep,
# you can change this if you really want).
$ssh ls -rd "$dest_pool/${vol}_ro*" | tail -n +$(( keep + 1 ))| while read -r snap
do
    $ssh btrfs subvolume delete "$snap"
done
$ssh ls -rd "$dest_pool/${vol}_rw*" | tail -n +$(( keep + 1 ))| while read -r snap
do
    $ssh btrfs subvolume delete "$snap"
done

rm "$lock"
