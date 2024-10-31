#!/bin/bash

region="eu-north-1"
dns_name="example.com"

create_hosted_zone()
{
    check_zone=$(aws route53 list-hosted-zones-by-name --dns-name $dns_name | grep -oP '(?<="Id": ")[^"]*' | uniq)
    if [ "$check_zone" == "" ]; then
        
        echo "Hosted Zone will be created ..."
        time=$(date -u +"%Y-%m-%d-%H-%M-%S")
        hosted_zone_id=$(aws route53 create-hosted-zone --name $dns_name --caller-reference $time | grep -oP '(?<="Id": ")[^"]*')
        
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
    # $1 ec2 Name
    ec2_ip=$(aws ec2 describe-instances --region $region --filters Name=tag:Name,Values=$1 | grep -oP '(?<="PublicIpAddress": ")[^"]*' )
    if [ "$ec2_ip" == "" ]; then
        echo "EC2 with name: '$1' not exist."
        exit 1
    else
        echo "EC2 found. public ip: $ec2_ip"
    fi
}

create_dns_record()
{
    # $1 sub domain, $2 ip
    full_sub_domain="$1.$dns_name"
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
    change=$(echo $change | tr -d '\n' | tr -d ' ')
    check_record=$(aws route53 list-resource-record-sets --hosted-zone-id $hosted_zone_id --query "ResourceRecordSets[?Name == '$full_sub_domain.']" | grep -oP '(?<="Name": ")[^"]*')
    if [ "$check_record" == "" ]; then
        
        echo "DNS Record will be created ..."
        record_id=$(aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch $change | grep -oP '(?<="Id": ")[^"]*')
        
        if [ "$record_id" == "" ]; then
            echo "Error in create DNS Record"
            exit 1
        fi
        echo "DNS Record created."

    else
        echo "DNS Record already exist."
    fi
}


create_hosted_zone
get_instance_ip "devops90"
create_dns_record "jump" $ip
