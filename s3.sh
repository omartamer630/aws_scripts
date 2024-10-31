#create new bucket
sudo aws s3api create-bucket --bucket devops90-cli-bucket --region eu-north-1 --create-bucket-configuration LocationConstraint=eu-north-1

#get list of all available buckets in the default region of the current user
sudo aws s3 ls

#block all public access
sudo aws s3api put-public-access-block --bucket devops90-cli-bucket --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

#upload image file to the bucket
sudo aws s3api put-object --bucket omar-cli-bucket --content-type image/jpeg --key codeDeploy_in_action.jpg --body /mnt/c/aws/codeDeploy_in_action.jpg

#disable block public access (unblock)
sudo aws s3api delete-public-access-block --bucket omar-cli-bucket

#Transfer OwnerShip to me
sudo aws s3api put-bucket-ownership-controls --bucket omar-cli-bucket --ownership-controls 'Rules=[{ObjectOwnership="BucketOwnerPreferred"}]'          

#make the image file accessible for the world
sudo aws s3api put-object-acl --bucket omar-cli-bucket --key Lectures.pdf --grant-read uri=http://acs.amazonaws.com/groups/global/AllUsers

#make the image file accessible for the world
sudo aws s3api put-object-acl --bucket omar-cli-bucket --key Lectures.pdf --acl public-read

#make the image file private
sudo aws s3api put-object-acl --bucket omar-cli-bucket --key Lectures.pdf --acl private

#delete the image file
sudo aws s3api delete-object --bucket omar-cli-bucket --key Lectures.pdf

#delete the bucket
sudo aws s3api delete-bucket --bucket omar-cli-bucket --region eu-north-1

#get list of all available buckets in the default region of the current user
sudo aws s3 ls

#apply policy.json
aws s3api put-bucket-policy --bucket omar-cli-bucket --policy file://policy.json

#apply domain_policy.json
aws s3api put-bucket-policy --bucket omar-cli-bucket --policy file://domain_policy.json


