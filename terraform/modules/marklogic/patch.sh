#!/bin/bash

set -euo pipefail

echo "Starting patch script at $(date --iso-8601=seconds)"

TOKEN=`curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTANCE_ID=`curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id`
AUTOSCALING_GROUP_NAME=`aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --query 'AutoScalingInstances[0].AutoScalingGroupName' --output text`
LIFECYCLE_STATE=`aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --query 'AutoScalingInstances[0].LifecycleState' --output text`

echo "Instance $${INSTANCE_ID}"
echo "Autoscaling group $${AUTOSCALING_GROUP_NAME}; $${LIFECYCLE_STATE}"

ML_USER_PASS=$(aws secretsmanager get-secret-value --secret-id ml-admin-user-${ENVIRONMENT} --region ${AWS_REGION} --query SecretString --output text)
yum install jq -y # This command has been added to marklogic_cf_template.yml but will need to remain here until the instances are re-created
ML_USER=$(echo $ML_USER_PASS | jq -r '.username')
ML_PASS=$(echo $ML_USER_PASS | jq -r '.password')
mkdir -p /patching # Folder for any patching-related files that are copied down

if [[ "InService" == $LIFECYCLE_STATE ]]; then
  echo "Starting to check forest state at $(date --iso-8601=seconds)"
  aws s3 cp --region ${AWS_REGION} s3://${MARKLOGIC_CONFIG_BUCKET}/check_forest_state.xqy /patching/check_forest_state.xqy

  set +e
  response=$(curl --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @/patching/check_forest_state.xqy \
                 -H "Content-type: application/x-www-form-urlencoded" \
                 -H "Accept: text/plain" \
                 http://localhost:8002/v1/eval || echo "output:Connection failed")

  FOREST_STATUS=$(echo "$response" | tr -d '\015' | grep output | cut -d ':' -f2)
  echo "Forest status: $${FOREST_STATUS}"

  if [ "READY_FOR_RESTART" != "$FOREST_STATUS" ]; then
    echo "Waiting for all forests to be in 'open'/'sync replicating' state"
    SECONDS=0
    until [[ "READY_FOR_RESTART" == "$FOREST_STATUS" ]]; do
        if (( SECONDS > 600 )); then
            echo "Error: giving up waiting for forests to enter 'open'/'sync replicating' state"
            exit 1
        fi

        sleep 10
        response=$(curl --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @/patching/check_forest_state.xqy \
                       -H "Content-type: application/x-www-form-urlencoded" \
                       -H "Accept: text/plain" \
                       http://localhost:8002/v1/eval || echo "output:Connection failed")
        FOREST_STATUS=$(echo "$response" | tr -d '\015' | grep output | cut -d ':' -f2)
        echo "Forest status: $${FOREST_STATUS}"
    done
  fi

  set -e
  echo "All forests in 'open'/'sync replicating' state"

  echo "Requesting enter-standby"
  aws autoscaling enter-standby --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALING_GROUP_NAME --should-decrement-desired-capacity
  echo "Waiting for instance to be in standby state"
  SECONDS=0
  until [[ "Standby" == $LIFECYCLE_STATE ]]; do
    if (( SECONDS > 600 )); then
        echo "Error: giving up waiting for instance to enter standby"
        exit 1
    fi

    sleep 10
    LIFECYCLE_STATE=`aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --query 'AutoScalingInstances[0].LifecycleState' --output text`
    echo "Current state: $${LIFECYCLE_STATE}"
  done
  
  echo "Running yum update"
  yum update --security -y
  echo "Updates complete, requesting reboot from SSM agent at $(date --iso-8601=seconds)"
  exit 194 # Reboot and re-run the script https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-reboot.html
fi

if [[ "Standby" == $LIFECYCLE_STATE ]]; then
  echo "Requesting exit-standby"
  aws autoscaling exit-standby --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALING_GROUP_NAME
  echo "Waiting for instance to return to service"
  SECONDS=0
  until [[ "InService" == $LIFECYCLE_STATE ]]; do
    if (( SECONDS > 300 )); then
        echo "Error: giving up waiting for instance to return to service"
        exit 1
    fi

    sleep 10
    LIFECYCLE_STATE=`aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --query 'AutoScalingInstances[0].LifecycleState' --output text`
    echo "Current state: $${LIFECYCLE_STATE}"
  done
  echo "Patching complete at $(date --iso-8601=seconds)"
  exit 0
fi

echo "Unexpected instance state $${LIFECYCLE_STATE}"
exit 1
