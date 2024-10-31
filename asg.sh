#!/bin/bash

get_vpc_id(){
    vpc_id=$(aws ec2 describe-vpcs --region eu-north-1 --filters Name=tag:Name,Values=devops90-vpc | grep -oP '(?<="VpcId": ")[^"]*')
    if [ "$vpc_id" == "" ]; then
        echo "vpc is not exist"
        exit 1
    fi
    echo $vpc_id
}

get_subnets_ids(){
    subnet_1a_id=$(aws ec2 describe-subnets --region eu-north-1 --filters Name=tag:Name,Values=sub-public-1-devops90 | grep -oP '(?<="SubnetId": ")[^"]*')
    if [ "$subnet_1a_id" == "" ]; then
        echo "subnet 1a not exists!"
        exit 1
    fi
    subnet_2b_id=$(aws ec2 describe-subnets --region eu-north-1 --filters Name=tag:Name,Values=sub-public-2-devops90 | grep -oP '(?<="SubnetId": ")[^"]*')
    if [ "$subnet_2b_id" == "" ]; then
        echo "subnet 2b not exists!"
        exit 1
    fi

    subnets_ids="${subnet_1a_id},${subnet_2b_id}"
    subnets_ids_space="${subnet_1a_id} ${subnet_2b_id}"

    echo $subnets_ids
    echo $subnets_ids_space
}

get_security_group_id(){
    sg_id=$(aws ec2 describe-security-groups --filters Name=tag:Name,Values=devops90-sg | grep -oP '(?<="GroupId": ")[^"]*' | uniq)
    if [ "$sg_id" == "" ]; then
        echo "security group is not exist"
        exit 1
    fi
    echo $sg_id
}

create_elb(){
    check_elb=$(aws elbv2 describe-load-balancers --region eu-north-1 --query "LoadBalancers[?LoadBalancerName == 'autoscaling-nlb']" | grep -oP '(?<="LoadBalancerArn": ")[^"]*')

    if [ "$check_elb" == "" ]; then
        
        echo "elb will be created"
        
        elb_arn=$(aws elbv2 create-load-balancer --name autoscaling-nlb --type network --subnets $subnets_ids_space --security-groups $sg_id | grep -oP '(?<="LoadBalancerArn": ")[^"]*' )
        if [ "$elb_arn" == "" ]; then
            echo "Error in create the elb"
            exit 1
        fi
        echo $elb_arn

    else
        echo "elb already exist"
        elb_arn=$check_elb
        echo $elb_arn
    fi
}

create_target_group(){
    check_tg=$(aws elbv2 describe-target-groups --region eu-north-1 --query "TargetGroups[?TargetGroupName == 'autoscaling-tg']" | grep -oP '(?<="TargetGroupArn": ")[^"]*')

    if [ "$check_tg" == "" ]; then
        
        echo "target group will be created"

        tg_arn=$(aws elbv2 create-target-group --name autoscaling-tg \
            --protocol TCP --port 8002 --vpc-id $vpc_id \
            --health-check-interval-seconds 30 \
            --health-check-timeout-seconds 20 \
            --healthy-threshold-count 2 \
            --unhealthy-threshold-count 2 \
            | grep -oP '(?<="TargetGroupArn": ")[^"]*')
        
        if [ "$tg_arn" == "" ]; then
            echo "Error in create the target group"
            exit 1
        fi
    else
        echo "target group already exist"
        tg_arn=$check_tg
    fi

    echo $tg_arn
}

create_listener(){
    ls_arn=$(aws elbv2 create-listener --load-balancer-arn "$elb_arn" --protocol TCP --port 80 --default-actions Type=forward,TargetGroupArn="$tg_arn" | grep -oP '(?<="ListenerArn": ")[^"]*')
    if [ "$ls_arn" == "" ]; then
        echo "Error in create the listener"
        exit 1
    fi
    echo $ls_arn
}

create_auto_scaling_group(){

    check_asg=$(aws autoscaling describe-auto-scaling-groups --region eu-north-1 --query "AutoScalingGroups[?AutoScalingGroupName == 'devops-asg']" | grep -oP '(?<="AutoScalingGroupARN": ")[^"]*')

    if [ "$check_asg" == "" ]; then
        
        echo "asg will be created!"
        
        aws autoscaling create-auto-scaling-group \
            --auto-scaling-group-name devops-asg \
            --launch-template LaunchTemplateName=srv02-template \
            --target-group-arns $tg_arn \
            --health-check-type ELB \
            --health-check-grace-period 120 \
            --min-size 2 \
            --desired-capacity 2 \
            --max-size 7 \
            --vpc-zone-identifier "$subnets_ids"

        echo "asg creation done. kinldy check it from the aws console!"

    else
        echo "asg already exist"
        asg_arn=$check_asg
        echo $asg_name
    fi
}

attach_scaling_policy(){
    config=$(cat << EOF
{
    "TargetValue": 50,
    "PredefinedMetricSpecification": {
         "PredefinedMetricType": "ASGAverageCPUUtilization"
    }
}
EOF
)
    config=$( echo $config | tr -d '\n' | tr -d ' ')

    aws autoscaling put-scaling-policy --auto-scaling-group-name devops-asg \
  --policy-name cpu50-target-tracking-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration $config
}

get_vpc_id
get_subnets_ids
get_security_group_id

create_elb
create_target_group
create_listener

create_auto_scaling_group
attach_scaling_policy
