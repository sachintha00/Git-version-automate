#!/bin/bash

BRANCH_NAME=$1

SHA=$(git rev-list ^master "$BRANCH_NAME" | tail -n 1) 
MESSAGE=$(git log --format=%B -n 1 $SHA)

echo "First commit SHA: $SHA"
echo "Message: $MESSAGE"

