#!/bin/bash

ACCOUNT2="559866444233"

REPOSITORY_URI=$ACCOUNT2.dkr.ecr.us-east-1.amazonaws.com/vsr-h2o-model

echo "TASK:2"

echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT2' : STARTED *****************-----------------"
#password=$(aws ecr get-login-password --region us-east-1)
#echo "$password" | docker login --username AWS --password-stdin $ACCOUNT2.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT2.dkr.ecr.us-east-1.amazonaws.com
echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT2' : COMPLETED *****************-----------------"

echo "TASK:3"
echo "-----------------***************** AWS ECR IMAGE PULLING : STARTED *****************-----------------"
docker pull $REPOSITORY_URI:prod
echo "-----------------***************** AWS ECR IMAGE PULLING : COMPLETED *****************-----------------"
