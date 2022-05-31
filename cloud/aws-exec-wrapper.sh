#!/bin/bash
set -x
set -e
set -o pipefail

ShowUsage() {
    printf "This script requires three parameters (AWS Region, Profile as defined in ~/.aws/config, and environment.\n
-p	-- AWS Profile to use (check in ~/.aws/config).\n
-e	-- Environment we wish to use.\n
-r  -- AWS Region to use.\n
-h	-- Help (this text).\n

For example: aws-exec-wrapper.sh -p qa-sso -r us-east-2 -e qa36\n
"
}

while getopts "e:p:r:h" opt; do
    case "$opt" in

    e)
        EnvironmentFlag=1
        AWS_Env=$OPTARG
        ;;
    p)
        ProfileFlag=1
        AWS_Profile=$OPTARG
        ;;
    r)
        RegionFlag=1
        AWS_Region=$OPTARG
        ;;
    h) ShowUsage ;;
    *) ShowUsage ;;
    esac
done

FAMILYFILTER=tbl-${AWS_Env}-DjangoTaskDefinition

CLUSTERFILTER=${AWS_Env}

FAMILY=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-task-definition-families --output text | grep $FAMILYFILTER | cut -f2)
CLUSTER=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-clusters --output text | cut -f2 | sed 's,/, ,g' | cut -d' ' -f2 | grep $CLUSTERFILTER )


TASK=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-tasks --family $FAMILY --cluster $CLUSTER --output text | tail -1 | cut -f2 | sed 's,/, ,g' | cut -d' ' -f3)

CONTAINER=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs describe-task-definition --task-definition $FAMILY | jq -r '.taskDefinition.containerDefinitions[].name' | grep django)

[[ -n "$*" ]] && EXECCOMMAND='--command "'"${*}"'" --interactive' || EXECCOMMAND="--interactive --command sh"

echo aws --region=us-east-1 ecs execute-command --cluster $CLUSTER --task $TASK --container $CONTAINER $EXECCOMMAND
aws --region $AWS_REGION --profile $AWS_PROFILE ecs execute-command --cluster $CLUSTER --task $TASK --container $CONTAINER $EXECCOMMAND
