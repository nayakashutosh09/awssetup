#!/bin/bash

. variables_file.sh

echo "TASK:1"
echo "-----------------***************** AWS CLI INSTALLATION : STARTED *****************-----------------"
sudo yum install awscli
echo "-----------------***************** AWS CLI INSTALLATION : COMPLETED *****************-----------------"
echo "TASK:2"
echo "-----------------***************** AWS VERSION : STARTED *****************-----------------"
sudo aws --version
echo "-----------------***************** AWS VERSION : COMPLETED *****************-----------------"
echo "TASK:3"
echo "-----------------***************** AWS CONFIGURATION : STARTED *****************-----------------"
AWS_ACCESS_KEY_ID="enter"
AWS_SECRET_ACCESS_KEY="enter"
AWS_DEFAULT_REGION="us-east-1"
AWS_OUTPUT_FORMAT="json"

aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region $AWS_DEFAULT_REGION
aws configure set default.output $AWS_OUTPUT_FORMAT
echo "-----------------***************** AWS CONFIGURATION : COMPLETED *****************-----------------"
echo "TASK:4"
echo "-----------------***************** AWS ARTIFACTORY SETTING : STARTED *****************-----------------"
PACKAGE_NAME="bayer-aws-sso"
REPO_URL="https://$USERNAME:AKCp8pRQnKwMczfgg3WqNEAKTJMu7MDxCbb2hHtDeXxpSSmFBzXhyxKMARadKBAd5AG6Dddxa@artifactory.bayer.com/artifactory/aws2-pypi-prod-util/"
TRUSTED_HOST="artifactory.bayer.com"
pip3 install $PACKAGE_NAME --index-url $REPO_URL --trusted-host $TRUSTED_HOST
echo "-----------------***************** AWS ARTIFACTORY SETTING : COMPLETED *****************-----------------"
echo "TASK:5"
echo "-----------------***************** AWS SSO SETTING : STARTED *****************-----------------"
export PATH="/home/ssm-user/.local/bin:$PATH"
aws-sso --username $USERNAME --password $PASSWORD -a $ACCOUNT1
echo "-----------------***************** AWS SSO SETTING : COMPLETED *****************-----------------"
