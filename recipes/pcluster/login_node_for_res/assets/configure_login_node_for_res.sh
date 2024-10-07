#!/bin/bash

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <SSM_DOCUMENT> <PCLUSTER_STACK_NAME>"
    exit 1
fi

SSM_DOCUMENT="$1"
PCLUSTER_STACK_NAME="$2"

# Verify the parameters are valid
aws ssm describe-document --name "$SSM_DOCUMENT" >/dev/null 2>&1 || {
    echo "[!] Invalid SSM_DOCUMENT: '$SSM_DOCUMENT'"
    exit 1
}

aws cloudformation describe-stacks --stack-name "$PCLUSTER_STACK_NAME" >/dev/null 2>&1 || {
    echo "[!] Invalid PCLUSTER_STACK_NAME: '$PCLUSTER_STACK_NAME'"
    exit 1
}    

# Execute the automation document
EXECUTION_ID=$(aws ssm start-automation-execution \
    --document-version \$DEFAULT \
    --parameters pclusterStackName="$PCLUSTER_STACK_NAME" \
    --document-name "$SSM_DOCUMENT" \
    --query 'AutomationExecutionId' \
    --output text)

echo "$(date +%Y%m%d-%H:%M:%S) [-] Automation execution started with ID: $EXECUTION_ID"

# Timeout after 30 minutes
TIMEOUT=1800

# Set the initial start time
START_TIME=$(date +%s)
ELAPSED_TIME=0
WAITING_STATUS=("InProgress" "Pending" "Waiting")

while [[ $ELAPSED_TIME -le $TIMEOUT ]]; do
    AUTOMATION_STATUS=$(aws ssm get-automation-execution \
        --automation-execution-id "$EXECUTION_ID" \
        --query 'AutomationExecution.AutomationExecutionStatus' \
        --output text)

    # Check if automation status is not InProgress, Pending, Waiting

    if [[ ! "${WAITING_STATUS[@]}" =~ "$AUTOMATION_STATUS" ]]; then
        break
    fi

    echo "$(date +%Y%m%d-%H:%M:%S) [-] Waiting for automation execution to complete... Retrying in 60s"
    sleep 60
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
done

if [ "$ELAPSED_TIME" -ge $TIMEOUT ]; then
    echo "[!] Maximum wait time reached!"  
    echo "[!] Check SSM Execution ID: '${EXECUTION_ID}' for more details."
    exit 1
fi

if [ "$AUTOMATION_STATUS" != "Success" ]; then
    echo "[!] Automation execution failed with status: '$AUTOMATION_STATUS'"
    FAILURE_MSG=$(aws ssm get-automation-execution \
        --automation-execution-id "$EXECUTION_ID" \
        --query 'AutomationExecution.FailureMessage' \
        --output text)
    echo "[!] Failure message: $FAILURE_MSG"
    exit 1
fi

OUTPUTS=$(aws ssm get-automation-execution \
    --automation-execution-id "$EXECUTION_ID" \
    --query 'AutomationExecution.Outputs."createAMI.AMIImageId"[0]' \
    --output text)

echo "$(date +%Y%m%d-%H:%M:%S) [-] Automation execution completed successfully."
echo "$(date +%Y%m%d-%H:%M:%S) [-] Outputs: $OUTPUTS"
echo "Done!"
