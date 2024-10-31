#create key
sudo aws ec2 create-key-pair --key-name devops90-cli-key --key-format ppk --query 'KeyMaterial' --output text > devops90-cli-key.ppk


#create security group
sudo aws ec2 create-security-group --group-name devops90-sg --description 'from cli' --query 'GroupId'

#sg-07f896f087c9c7ff0

#add rule
sudo aws ec2 authorize-security-group-ingress --group-id sg-07f896f087c9c7ff0 --protocol tcp --port 22 --cidr 156.218.82.68/32
sudo aws ec2 authorize-security-group-ingress --group-id sg-07f896f087c9c7ff0 --protocol tcp --port 80 --cidr 156.218.82.68/32


# Create EC2 instance
sudo aws ec2 run-instances \
    --image-id ami-08eb150f611ca277f \
    --count 1 \
    --instance-type t3.micro \
    --key-name devops90-cli-key \
    --region eu-north-1 \
    --security-group-ids sg-07f896f087c9c7ff0 \
    --tag-specifications "ResourceType=instance,Tags=[{Key=env,Value=devops},{Key=Name,Value=devops-cli}]"



sudo aws ec2 terminate-instances --instance-ids i-0c7e7ccffa2637c0d
sudo aws ec2 delete-security-group --group-id sg-07f896f087c9c7ff0
