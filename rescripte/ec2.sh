#!/bin/bash

key_name="deopstest"
check_key=$(sudo aws ec2 describe-key-pairs --filter Name=tag:Name,Values=$key_name-key | grep -oP '(?<="KeyPairId": ")[^"]*')
echo $check_key

# Creating a new key if it is not exist

if [ "$check_key" == "" ]; then

  echo "Creating a new keypair"

  key_result=$(sudo aws ec2 create-key-pair --key-name $key_name \
  --key-format ppk --tag-specification ResourceType=key-pair,Tags="[{Key=Name,Value=$key_name-key}]" \
  --query 'KeyMaterial' --output text > $key_name.ppk)

  echo $key_result

  key_id=$(sudo aws ec2 describe-key-pairs --filter Name=tag:Name,Values=$key_name-key | grep -oP '(?<="KeyPairId": ")[^"]*')

  if [ "$key_id" == "" ]; then
   echo "Failed to create keypair"
   exit 1
  fi
  echo "Keypair created successfully. Key ID: $key_id"
fi 

# Create ec2 instance

if 
