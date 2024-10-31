#!/bin/bash
LB_ARN=$(sudo aws elbv2 create-load-balancer --name devops-alb --type application --subnets subnet-071d82b6610ca0269 subnet-0222bc03af359c875 --security-groups sg-051518c4646a1198b | grep -oP '(?<="LoadBalancerArn": ")[^"]*' )


echo "$LB_ARN"
 
TG_ARN=$(sudo aws elbv2 create-target-group --name devops-tg --protocol HTTP --port 8002 --vpc-id vpc-037884fef3c9e4fab | grep -oP '(?<="TargetGroupArn": ")[^"]*')


echo "$TG_ARN"


sudo aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=i-0ba08cd42c08a53cf Id=i-063c9b6e4be31370b


LS_ARN=$(sudo aws elbv2 create-listener --load-balancer-arn $LB_ARN --protocol HTTP --port 8002  --default-actions Type=forward,TargetGroupArn=$TG_ARN | grep -oP '(?<="ListenerArn": ")[^"]*')


echo "$LS_ARN"


#aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN
#aws elbv2 delete-target-group --target-group-arn $TG_ARN
#aws elbv2 delete-listener --listener-arn LS_ARN
