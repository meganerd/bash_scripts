#!/bin/bash
NUsers=${1:-15}

# This script requires you to provide the number of users you are interested in.  It will default to 15 if no parameter is provided.

TopUsers()
{
pflogsumm --iso_date_time  /var/log/mail.log | grep -A "$NUsers" "Senders by message count"
}

TopUsers
