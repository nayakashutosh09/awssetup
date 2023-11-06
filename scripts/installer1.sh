#!/bin/bash

DIRECTORY_PATH="/Users/efzqd/Downloads/installer"
USERNAME="ashutosh.nayak.ext@bayer.com"
PASSWORD="ByrAshNa22!"
ACCOUNT2="559866444233"
ACCOUNT1="374898892977"

REPOSITORY_URI=$ACCOUNT1.dkr.ecr.us-east-1.amazonaws.com/vsr-h2o-model

echo "-----------------***************** AWS SSO CONFIGURATION FOR '$ACCOUNT1': STARTED *****************-----------------"
yum install awscli
pip install dnspython>=2.2.1
pip install tzlocal>=4.2
pip install boto>=2.49.0
pip install lxml>=4.3.4
pip install msal>=1.17.0

aws --version
AWS_ACCESS_KEY_ID="enter"
AWS_SECRET_ACCESS_KEY="enter"
AWS_DEFAULT_REGION="us-east-1"
AWS_OUTPUT_FORMAT="json"

aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region $AWS_DEFAULT_REGION
aws configure set default.output $AWS_OUTPUT_FORMAT

echo "TASK:4"
echo "-----------------***************** AWS ARTIFACTORY SETTING : STARTED *****************-----------------"
PACKAGE_NAME="bayer-aws-sso"
REPO_URL="https://$USERNAME:AKCp8pRQnKwMczfgg3WqNEAKTJMu7MDxCbb2hHtDeXxpSSmFBzXhyxKMARadKBAd5AG6Dddxa@artifactory.bayer.com/artifactory/aws2-pypi-prod-util/"
TRUSTED_HOST="artifactory.bayer.com"
pip3 install $PACKAGE_NAME --index-url $REPO_URL --trusted-host $TRUSTED_HOST
echo "-----------------***************** AWS ARTIFACTORY SETTING : COMPLETED *****************-----------------"

aws-sso --username $USERNAME --password $PASSWORD -a $ACCOUNT1
echo "-----------------***************** AWS SSO CONFIGURATION FOR '$ACCOUNT1': COMPLETED *****************-----------------"

echo "TASK:2"

echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT1' : STARTED *****************-----------------"
#password=$(aws ecr get-login-password --region us-east-1)
#echo "$password" | docker login --username AWS --password-stdin $ACCOUNT2.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT1.dkr.ecr.us-east-1.amazonaws.com
echo "-----------------***************** AWS ECR LOGIN '$ACCOUNT1' : COMPLETED *****************-----------------"

echo "TASK:3"
echo "-----------------***************** AWS ECR IMAGE PULLING : STARTED *****************-----------------"
docker pull $REPOSITORY_URI:prod
echo "-----------------***************** AWS ECR IMAGE PULLING : COMPLETED *****************-----------------"
