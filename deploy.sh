#!/bin/bash

AWS_S3_REGION="us-west-1"
STAGING_BRANCH="staging"
PRODUCTION_BRANCH="master"

# Determine the environment to deploy to based on the branch
# From that, we'll know:
#   - the S3 bucket to sync assets with
#   - the CloudFront distribution for which to create an invalidation
NODE_ENV=''
CLOUDFRONT_DIST_ID=''
if [[ $TRAVIS_BRANCH == $STAGING_BRANCH ]]; then
  NODE_ENV="staging"
  CLOUDFRONT_DIST_ID=$CLOUDFRONT_DIST_ID_STAGING
  # TODO: Change this to the command that builds your app for staging
  yarn build:staging
elif [[ $TRAVIS_BRANCH == $PRODUCTION_BRANCH ]]; then
  NODE_ENV="production"
  CLOUDFRONT_DIST_ID=$CLOUDFRONT_DIST_ID_PRODUCTION
  # TODO: Change this to the command that builds your app for production
  yarn build:production
else
  # Don't want to deploy if it's not one of the above branches
  echo "Not deploying"
  exit
fi
# Configure AWS credentials for Elastic Beanstalk
mkdir -p ~/.aws
echo '[profile aws-cli]' > ~/.aws/config
echo "AWS_ACCESS_KEY_ID = $AWS_ACCESS_KEY_ID" >> ~/.aws/config
echo "AWS_SECRET_ACCESS_KEY = $AWS_SECRET_ACCESS_KEY" >> ~/.aws/config
echo "AWS_REGION = $AWS_REGION" >> ~/.aws/config

# Build the name of the S3 bucket we want to deploy to
# TODO: Change the prefix of the bucket name to match your bucket's name
S3_BUCKET="micro-react-app-demo"
# S3_BUCKET="mywebapp-react-$NODE_ENV"
echo "Deploying to the $S3_BUCKET bucket"

# Install the AWS CLI so we can publish to S3
pip install awscli --upgrade --user



# Sync our build folder with our S3 bucket
# --acl public-read says deploy the files with public read access
# --delete says to delete files in the bucket that aren't present in the build folder
#   this ensures that old assets built with webpack with hashed names get deleted
#   when a new build of the app is made and the assets get new hash names
aws s3 sync build/ "s3://$S3_BUCKET" --acl public-read --delete

# Force-invalidate the now-outdated assets rather than waiting for them to expire
# Make sure you have the CLOUDFRONT_DIST_ID_* env variables defined for this to work
aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_DIST_ID \
  --paths /*