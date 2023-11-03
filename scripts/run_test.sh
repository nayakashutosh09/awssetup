#!/bin/bash

. variables_file.sh

aws-sso --version

echo "TASK:1"

echo "-----------------***************** AWS SSO CONFIGURATION FOR '$ACCOUNT2': STARTED *****************-----------------"
aws-sso --username $USERNAME --password $PASSWORD -a $ACCOUNT2
echo "-----------------***************** AWS SSO CONFIGURATION FOR '$ACCOUNT2': COMPLETED *****************-----------------"

echo "TASK:2"

echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT2' : STARTED *****************-----------------"
password=$(aws ecr get-login-password --region us-east-1)
echo "$password" | docker login --username AWS --password-stdin $ACCOUNT2.dkr.ecr.us-east-1.amazonaws.com
echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT2' : COMPLETED *****************-----------------"

echo "TASK:3"
echo "-----------------***************** AWS ECR IMAGE PULLING : STARTED *****************-----------------"
docker pull $ACCOUNT2.dkr.ecr.us-east-1.amazonaws.com/vsr-h2o-model:prod
echo "-----------------***************** AWS ECR IMAGE PULLING : COMPLETED *****************-----------------"

echo "TASK:4"

echo "-----------------***************** AWS MODEL DOWNLOAD : STARTED *****************-------------------"
#wget https://dsso-ss-analytics.s3.amazonaws.com/models/Mod_5.0_QC5
echo "-----------------***************** AWS MODEL DOWNLOAD : COMPLETED *****************-----------------"

echo "TASK:5"

echo "-----------------***************** GENERATE DATA THROUGH h2o IMAGE : STARTED *****************------------------------"
docker run -it --rm -v$(pwd):$(pwd) $ACCOUNT2.dkr.ecr.us-east-1.amazonaws.com/vsr-h2o-model:prod /bin/bash $(pwd)/runh2o.sh
echo "-----------------***************** GENERATE DATA THROUGH h2o IMAGE : COMPLETED *****************----------------------"

echo "TASK:6"

echo "-----------------***************** AWS SSO CONFIGURATION FOR '$ACCOUNT1': STARTED *****************-----------------"
aws-sso --username $USERNAME --password $PASSWORD -a $ACCOUNT1
echo "-----------------***************** AWS SSO CONFIGURATION FOR '$ACCOUNT1': COMPLETED *****************-----------------"

echo "TASK:7"

echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT1' : STARTED *****************-----------------"
password=$(aws ecr get-login-password --region us-east-1)
echo "$password" | docker login --username AWS --password-stdin $ACCOUNT1.dkr.ecr.us-east-1.amazonaws.com
echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT1' : COMPLETED *****************-----------------"

echo "TASK:8"

echo "-----------------***************** AWS ECR IMAGE PULLING : STARTED *****************-----------------"
docker pull $ACCOUNT1.dkr.ecr.us-east-1.amazonaws.com/vsr-pipeline:prod
echo "-----------------***************** AWS ECR IMAGE PULLING : COMPLETED *****************-----------------"

echo "TASK:9"

echo "-----------------***************** GENERATE FINAL DATA FILE : STARTED *****************------------------------"
docker run -it --rm -v$(pwd):$(pwd) $ACCOUNT1.dkr.ecr.us-east-1.amazonaws.com/vsr-pipeline:prod /bin/bash $(pwd)/runpsp.sh
echo "-----------------***************** GENERATE FINAL DATA FILE : COMPLETED *****************------------------------"
