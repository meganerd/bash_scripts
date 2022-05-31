#!/usr/bin/env bash
set -e
set -o pipefail

ShowUsage() {
    printf "This script requires three parameters (AWS Region, Profile as defined in ~/.aws/config, and environment.\n
It also requires your shell session to have already logged into AWS via 'aws sso login'\n
\n
-c  -- ** OPTIONAL ** Command to send to the remote end (eg. bash)
-d  -- ** OPTIONAL ** Debug (causes set -x to be used to enable bash debugging)
-e  -- ** REQUIRED ** Environment we wish to use.
-p  -- ** REQUIRED ** AWS Profile to use (check in ~/.aws/config).
-r  -- ** REQUIRED ** AWS Region to use (eg. us-east-2).
-h  -- Help (this text).\n

For example: aws-exec-wrapper.sh -p qa-sso -r us-east-2 -e qa36\n
"
}

if [ $# -eq 0 ]; then
    ShowUsage
    exit 1
fi

while getopts "c:e:p:r:dh" opt; do
    case "$opt" in

    c)
    EXECCOMMAND="--interactive --command $OPTARG"
    ;;
    d)
    DEBUGFLAG=1
    ;;
    e)
        AWS_ENV=$OPTARG
        ;;
    p)
        AWS_PROFILE=$OPTARG
        ;;
    r)
        AWS_REGION=$OPTARG
        ;;
    h) ShowUsage
        ;;
    *) ShowUsage
        ;;
    esac
done

if [[ "$DEBUGFLAG" -eq 1 ]]; then
set -x
fi


# Setting default EXECCOMMAND.  The sh command will be replaced by whatever is passed to the -c flag.
EXECCOMMAND="--interactive --command sh"

FAMILYFILTER=tbl-${AWS_ENV}-DjangoTaskDefinition

CLUSTERFILTER=${AWS_ENV}

FAMILY=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-task-definition-families --output text | grep $FAMILYFILTER | cut -f2)
CLUSTER=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-clusters --output text | cut -f2 | sed 's,/, ,g' | cut -d' ' -f2 | grep $CLUSTERFILTER )


TASK=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-tasks --family $FAMILY --cluster $CLUSTER --output text | tail -1 | cut -f2 | sed 's,/, ,g' | cut -d' ' -f3)

CONTAINER=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs describe-task-definition --task-definition $FAMILY | jq -r '.taskDefinition.containerDefinitions[].name' | grep django)

#[[ -n "$*" ]] && EXECCOMMAND='--command "'"${*}"'" --interactive' || EXECCOMMAND="--interactive --command sh"

echo aws --region=us-east-1 ecs execute-command --cluster $CLUSTER --task $TASK --container $CONTAINER $EXECCOMMAND
aws --region $AWS_REGION --profile $AWS_PROFILE ecs execute-command --cluster $CLUSTER --task $TASK --container $CONTAINER $EXECCOMMAND
