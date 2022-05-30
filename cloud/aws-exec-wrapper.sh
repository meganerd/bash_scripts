#!/bin/bash
set -x
set -e
set -o pipefail

AWS_PROFILE=qa-sso
AWS_REGION=us-east-2

QAENV=qa19

FAMILYFILTER=tbl-${QAENV}-DjangoTaskDefinition

CLUSTERFILTER=${QAENV}

FAMILY=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-task-definition-families --output text | grep $FAMILYFILTER | cut -f2)
CLUSTER=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-clusters --output text | cut -f2 | sed 's,/, ,g' | cut -d' ' -f2 | grep $CLUSTERFILTER )


TASK=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs list-tasks --family $FAMILY --cluster $CLUSTER --output text | tail -1 | cut -f2 | sed 's,/, ,g' | cut -d' ' -f3)

CONTAINER=$(aws --region $AWS_REGION --profile $AWS_PROFILE ecs describe-task-definition --task-definition $FAMILY | jq -r '.taskDefinition.containerDefinitions[].name' | grep django)

[[ -n "$*" ]] && EXECCOMMAND='--command "'"${*}"'" --interactive' || EXECCOMMAND="--interactive --command sh"

echo aws --region=us-east-1 ecs execute-command --cluster $CLUSTER --task $TASK --container $CONTAINER $EXECCOMMAND
aws --region $AWS_REGION --profile $AWS_PROFILE ecs execute-command --cluster $CLUSTER --task $TASK --container $CONTAINER $EXECCOMMAND
