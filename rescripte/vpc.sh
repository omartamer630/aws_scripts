#!/bin/bash

# Create vpc 10.0.0.0/16

check_vpc=$(sudo aws ec2 describe-vpcs --region eu-north-1 --filter Name=tag:Name,Values=devops90-vpc | grep -oP '(?<="VpcId": ")[^"]*')

if [ "$check_vpc" == "" ]; then
  
  echo "Creating VPC"

  vpc_result=$(sudo aws ec2 create-vpc \
        --cidr-block 10.0.0.0/16 --region eu-north-1 \
        --tag-specification ResourceType=vpc,Tags="[{Key=Name,Value=devops90-vpc}]" \
        --output json)

  vpc_id=$(echo $vpc_result | grep -oP '(?<="VpcId": ")[^"]*')
  echo $vpc_id

  if [ "$vpc_id" == "" ]; then
      echo "Error in creating the vpc"
      exit 1
  fi

  echo "VPC Created successfully"
else
  echo "VPC already exists"
  vpc_id=$check_vpc
  echo $vpc_id
fi

# create public subnet 10.0.1.0/24 in first az
# create public subnet 10.0.2.0/24 in second az
# create private subnet 10.0.3.0/24 in first az
# create private subnet 10.0.4.0/24 in second az

create_subnet()
{

  #$1 subnet number, $2 az, $3 public or private
  check_subnet=$(sudo aws ec2 describe-subnets --region eu-north-1 --filters Name=tag:Name,Values=sub-$3-$1-devops90 | grep -oP '(?<="SubnetId": ")[^"]*')
  if [ "$check_subnet" == "" ]; then
    echo "subnet $1 will be created"

    subnet_result=$(sudo aws ec2 create-subnet \
            --vpc-id $vpc_id --availability-zone eu-north-1$2 \
            --cidr-block 10.0.$1.0/24 \
            --tag-specifications ResourceType=subnet,Tags="[{Key=Name,Value=sub-$3-$1-devops90}]" --output json)

    subnet_id=$(echo $subnet_result | grep -oP '(?<="SubnetId": ")[^"]*')
    echo $subnet_id
    if [ "$subnet_id" == "" ]; then
      echo "Error in creating the subnet $1"
      exit 1
    fi

    echo "Subnet $1 Created successfully"
  else
    echo "subnet $1 already exists"
    subnet_id=$check_subnet
    echo $subnet_id
  fi
}

create_subnet 1 a public
sub1_id=$subnet_id

create_subnet 2 b public
sub2_id=$subnet_id

create_subnet 3 a private
sub3_id=$subnet_id

create_subnet 4 b private
sub4_id=$subnet_id

# create internet gateway

check_igw=$(sudo aws ec2 describe-internet-gateways  --filters Name=tag:Name,Values=devops90-igw | grep -oP '(?<="InternetGatewayId": ")[^"]*')
if [ "$check_igw" == "" ]; then
  echo "Creating internet gateway"
  
  igw_id=$(sudo aws ec2 create-internet-gateway --region eu-north-1 \
        --tag-specifications ResourceType=internet-gateway,Tags="[{Key=Name,Value=devops90-igw}]" --output json | grep -oP '(?<="InternetGatewayId": ")[^"]*')
  if [ "$igw_id" == "" ]; then
   echo "Error in creating the internet gateway"
   exit 1
  fi
  
  echo "Internet Gateway Created successfully"
else
  echo "Internet Gateway already exists"
  igw_id=$check_igw
  echo $igw_id
fi

echo $igw_id

# attach internet gateway to vpc

igw_attach=$(sudo aws ec2 describe-internet-gateways --internet-gateway-ids $igw_id | grep -oP '(?<="VpcId": ")[^"]*')
if [ "$igw_attach" != "$vpc_id" ]; then
  attach_result=$(sudo aws ec2 attach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id)
  echo $attach_result
  if [ "attach_result" == "" ]; then
     echo "internet gateway is attached to the vpc"
  else
     echo "internet gateway already associated"
  fi
else

 echo "internet gateway is already associated with the vpc"

fi

# create public rout table

check_rtb=$(sudo aws ec2 describe-route-tables --filters Name=tag:Name,Values=public-devops90-rtb | grep -oP '(?<="RouteTableId": ")[^"]*' | uniq)

if [ "$check_rtb" == "" ]; then
  echo "Public route table will be created"
  public_rtb_id=$(sudo aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications ResourceType=route-table,Tags="[{Key=Name,Value=public-devops90-rtb}]"  --output json | grep -oP '(?<="RouteTableId": ")[^"]*'  | uniq)
  if [ "$public_rtb_id" == "" ]; then
   echo "Error in creating the public route table"
   exit 1
  fi
  
  echo "Public Route Table Created successfully"
  # create public route 
  route_result=$(sudo aws ec2 create-route --route-table-id $public_rtb_id \
        --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id --region eu-north-1 | grep -oP '(?<="Return": )\w+')
  echo $route_result
  if [ "$route_result" != "true" ]; then
    echo "Public route creation failed with response: $route_result"
    exit 1
  fi

  echo "Public route created successfully"

else
  echo "Public route table already exists"
  public_rtb_id=$check_rtb
fi

echo $public_rtb_id

# associate public route table to the public subnets
sudo aws ec2 associate-route-table --route-table-id $public_rtb_id --subnet-id $sub1_id
sudo aws ec2 associate-route-table --route-table-id $public_rtb_id --subnet-id $sub2_id

# create private route table
check_rtb=$(sudo aws ec2 describe-route-tables --filters Name=tag:Name,Values=private-devops90-rtb | grep -oP '(?<="RouteTableId": ")[^"]*'  | uniq)
if [ "$check_rtb" == "" ]; then
    echo "private route table will be created"
    private_rtb_id=$(sudo aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications ResourceType=route-table,Tags="[{Key=Name,Value=private-devops90-rtb}]" \
     --output json | grep -oP '(?<="RouteTableId": ")[^"]*'  | uniq)
    
    if [ "$private_rtb_id" == "" ]; then
        echo "Error in create private route table"
        exit 1
    fi
    echo "private route table created."

else 
    echo "private route table already exist"
    private_rtb_id=$check_rtb
fi

echo $private_rtb_id

# associate public route table to the public subnets
sudo aws ec2 associate-route-table --route-table-id $private_rtb_id --subnet-id $sub3_id
sudo aws ec2 associate-route-table --route-table-id $private_rtb_id --subnet-id $sub4_id
