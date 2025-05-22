# Creating a VPC

vpcid=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/26 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=Script-Vpc}]' \
    --query 'Vpc.VpcId' \
    --output text)

echo "VPC created: $vpcid"

# Next Step -> DNS Hostnames

#aws ec2 modify-vpc-attribute \
#    --vpc-id $vpcid \
#    --enable-dns-hostnames "{\"Value\":true}"

# Create Public Subnet

pubsub1=$(aws ec2 create-subnet \
  --vpc-id $vpcid \
  --cidr-block 10.0.0.0/27 \
  --availability-zone eu-north-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Public Subnet}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Public Subnet created: $pubsub1"

# Enable Public IP on launch

aws ec2 modify-subnet-attribute \
  --subnet-id $pubsub1 \
  --map-public-ip-on-launch


# Create Private Subnet

privsub1=$(aws ec2 create-subnet \
  --vpc-id $vpcid \
  --cidr-block 10.0.0.32/27 \
  --availability-zone eu-north-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Private Subnet}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Private Subnet created: $privsub1"

# Creating an IGW

igwid=$(aws ec2 create-internet-gateway \
	--tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=Script-IGW}]" \
--query 'InternetGateway.InternetGatewayId' \
--output text)

echo "Internet Gateway created: $igwid"

# attaching the IGW to the VPC

aws ec2 attach-internet-gateway --internet-gateway-id $igwid --vpc-id $vpcid
  
echo "IGW attached: $igwid"

# Create Route Table

rtbpubid1=$(aws ec2 create-route-table \
    --vpc-id $vpcid \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=Public Route Table}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Create a Route

aws ec2 create-route \
    --route-table-id $rtbpubid1 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $igwid

# Subnet Associations

aws ec2 associate-route-table --subnet-id $pubsub1 --route-table-id $rtbpubid1

echo "Public route table created and associated."

# Create Security Group for Bastion Host

bastionsgid=$(aws ec2 create-security-group \
  --group-name "Bastion Security Group" \
  --description "Allow SSH" \
  --vpc-id $vpcid \
  --query 'GroupId' \
  --output text)

echo "Security Group created: $bastionsgid"

# Adding Ingress Rule for Bastion SG

aws ec2 authorize-security-group-ingress \
    --group-id $bastionsgid \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 
# Change this either to 0.0.0.0 -> everyone
# Or change this to you own IP -> best practice

# Launch Bastion Host EC2

aws ec2 run-instances \
  --image-id ami-02ec57994fa0fae21 \
  --instance-type t3.micro \
  --subnet-id $pubsub1 \
  --key-name script \
  --associate-public-ip-address \
  --security-group-ids $bastionsgid \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="Bastion Server"}]'


# Create Security Group for Private Instance
# Allow SSH only from Bastion/CIDR 

privatesgid=$(aws ec2 create-security-group \
  --group-name "Private Instance Security Group" \
  --description "Allow SSH only from Bastion" \
  --vpc-id $vpcid \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $privatesgid \
    --protocol tcp \
    --port 22 \
    --cidr 10.0.0.0/26

# Launch instance in private subnet

aws ec2 run-instances \
  --image-id ami-02ec57994fa0fae21 \
  --instance-type t3.micro \
  --subnet-id $privsub1 \
  --key-name script \
  --security-group-ids $privatesgid \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="Private Server"}]'



# [Optional] NAT Gateway -> if the private instance needs internet access