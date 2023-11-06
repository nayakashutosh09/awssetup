#!/bin/bash

REGION="ZAF"
REGION_COUNT="us-east-1"
DIRECTORY_PATH="/Users/efzqd/Downloads/installer"
USERNAME="ashutosh.nayak.ext@bayer.com"
PASSWORD="ByrAshNa22!"
ACCOUNT1="374898892977"
ACCOUNT2="559866444233"

echo "TASK:2"

echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT2' : STARTED *****************-----------------"
password=$(aws ecr get-login-password --region us-east-1)
echo "$password" | docker login --username AWS --password-stdin $ACCOUNT2.dkr.ecr.us-east-1.amazonaws.com
echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT2' : COMPLETED *****************-----------------"

echo "TASK:3"
echo "-----------------***************** AWS ECR IMAGE PULLING : STARTED *****************-----------------"
docker pull $ACCOUNT2.dkr.ecr.us-east-1.amazonaws.com/vsr-h2o-model:prod
echo "-----------------***************** AWS ECR IMAGE PULLING : COMPLETED *****************-----------------"
