#!/usr/bin/env bash
# invoke script with bash -x for debugging.
set -e
set -o pipefail

# Setting default EXECCOMMAND.  The sh command will be replaced by whatever is passed to the -c flag.
EXECCOMMAND="--interactive --command sh"

ShowUsage() {
    printf "This script requires three parameters (AWS Region, Profile as defined in ~/.aws/config, and environment.\n
    It also requires your shell session to have already logged into AWS via 'aws sso login'
-c  -- Command to send to the remote end (eg. bash)
-e	-- Environment we wish to use.\n
-p	-- AWS Profile to use (check in ~/.aws/config).\n
-r  -- AWS Region to use (eg. us-east-2).\n
-h	-- Help (this text).\n

For example: aws-exec-wrapper.sh -p qa-sso -r us-east-2 -e qa36\n
"
}

while getopts "c:e:p:r:h" opt; do
    case "$opt" in

    e)
        EnvironmentFlag=1
        AWS_ENV=$OPTARG
        ;;
    p)
        ProfileFlag=1
        AWS_PROFILE=$OPTARG
        ;;
    r)
        RegionFlag=1
        AWS_REGION=$OPTARG
        ;;
    c)
        CommandFlag=1
        EXECCOMMAND="--interactive --command $OPTARG"
        ;;
    h) ShowUsage ;;
    *) ShowUsage ;;
    esac
done

FAMILYFILTER=tbl-${AWS_ENV}-DjangoTaskDefinition

CLUSTERFILTER=${AWS_ENV}

FAMILY=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-task-definition-families --output text | grep $FAMILYFILTER | cut -f2)
CLUSTER=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-clusters --output text | cut -f2 | sed 's,/, ,g' | cut -d' ' -f2 | grep $CLUSTERFILTER )


TASK=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-tasks --family $FAMILY --cluster $CLUSTER --output text | tail -1 | cut -f2 | sed 's,/, ,g' | cut -d' ' -f3)

CONTAINER=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs describe-task-definition --task-definition $FAMILY | jq -r '.taskDefinition.containerDefinitions[].name' | grep django)

#[[ -n "$*" ]] && EXECCOMMAND='--command "'"${*}"'" --interactive' || EXECCOMMAND="--interactive --command sh"

echo aws --region=us-east-1 ecs execute-command --cluster $CLUSTER --task $TASK --container $CONTAINER $EXECCOMMAND
aws --region $AWS_REGION --profile $AWS_PROFILE ecs execute-command --cluster $CLUSTER --task $TASK --container $CONTAINER $EXECCOMMAND
