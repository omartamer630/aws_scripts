#!/bin/bash

region="eu-north-1"
dns_name="devops90.com"
private_dns_name="ourapp.prod"
vpc_name="devops90-vpc"

create_hosted_zone()
{
    check_zone=$(aws route53 list-hosted-zones-by-name --query "HostedZones[?Name == '$dns_name.']" | grep -oP '(?<="Id": ")[^"]*')

    if [ "$check_zone" == "" ]; then
        echo "Hosted Zone will be created ..."
        time=$(date -u +"%Y-%m-%d-%H-%M-%S")
        hosted_zone_id=$(aws route53 create-hosted-zone --name $dns_name --caller-reference $time  --query HostedZone | grep -oP '(?<="Id": ")[^"]*')
        if [ "$hosted_zone_id" == "" ]; then
            echo "Error in create Hosted Zone"
            exit 1
        fi
        echo "Hosted Zone created: $hosted_zone_id"
    else
        echo "Hosted Zone already exist: $check_zone"
        hosted_zone_id=$check_zone
    fi

    echo $hosted_zone_id

}

get_vpc_id()
{
    VPCID=$(aws ec2 describe-vpcs --region $region --filters Name=tag:Name,Values=$vpc_name | grep -oP '(?<="VpcId": ")[^"]*')
    if [ "$VPCID" == "" ]; then
        echo "VPC with name: $vpc_name doesn't exist"
        exit 1
    else
        echo "VPC found: $VPCID"
    fi
}

create_private_zone()
{
    check_zone=$(aws route53 list-hosted-zones-by-name --query "HostedZones[?Name == '$private_dns_name.']" | grep -oP '(?<="Id": ")[^"]*')
    if [ "$check_zone" == "" ]; then
        
        echo "Hosted Zone will be created ..."
        time=$(date -u +"%Y-%m-%d-%H-%M-%S")
        hosted_zone_id=$(aws route53 create-hosted-zone --hosted-zone-config \{\"PrivateZone\":true\} --vpc \{\"VPCRegion\":\"$region\",\"VPCId\":\"$VPCID\"\} --name $private_dns_name --caller-reference $time --query HostedZone | grep -oP '(?<="Id": ")[^"]*')
        
        if [ "$hosted_zone_id" == "" ]; then
            echo "Error in create Hosted Zone"
            exit 1
        fi
        echo "Hosted Zone created."

    else
        echo "Hosted Zone already exist."
        hosted_zone_id=$check_zone
    fi
}

get_instance_ip()
{
    # $1 ec2 Name, $2 Private or Public
    ec2_ip=$(aws ec2 describe-instances --region $region --filters Name=tag:Name,Values=$1 Name=instance-state-name,Values=running | grep -oP "(?<=\"$2IpAddress\": \")[^\"]*" | uniq)
    if [ "$ec2_ip" == "" ]; then
        echo "EC2 with name: '$1' not exist."
        exit 1
    else
        echo "EC2 found. public ip: $ec2_ip"
    fi

}

create_dns_record()
{
    # $1 sub domain, $2 ip, $3 Private or Public
    if [ "$3" == "Private" ]; then
        full_sub_domain="$1.$private_dns_name"
    else
        full_sub_domain="$1.$dns_name"
    fi
    
    change=$(cat << EOF
{
  "Changes": 
  [
    {
      "Action": "CREATE",
      "ResourceRecordSet": 
      {
        "Name": "$full_sub_domain",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": 
        [
          {
            "Value": "$2"
          }
        ]
      }
    }
  ]
}
EOF
)
    change=$( echo $change | tr -d '\n' | tr -d ' ')
    
    check_record=$(aws route53 list-resource-record-sets --hosted-zone-id $hosted_zone_id --query "ResourceRecordSets[?Name == '$full_sub_domain.']" | grep -oP '(?<="Name": ")[^"]*')
    if [ "$check_record" == "" ]; then
        echo "DNS Record will be created ..."
        change_info=$(aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch $change)
        echo $change_info
    else
        echo "DNS Record already exist."
    fi
}

get_vpc_id
create_private_zone
get_instance_ip "devops90" "Private"
create_dns_record srv $ec2_ip "Private"
