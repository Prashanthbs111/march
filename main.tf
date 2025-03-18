
# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}
# Create public subnets within the VPC's CIDR range
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"  # Valid within 10.0.0.0/16
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"  # Valid within 10.0.0.0/16
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}


# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Create a Route Table for public access
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
}

# Create a route to allow internet access
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Associate the route table with the subnet
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a security group to allow SSH
resource "aws_security_group" "ssh" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh-security-group"
  }
}

# Create an EC2 instance
resource "aws_instance" "ec2_example" {
  ami                    = "ami-0c7af5fe939f2677f" 
  instance_type          = "t2.micro"
  key_name               = "key1" 
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.ssh.id]
  associate_public_ip_address = true 
  tags = {
    Name = "test-EC2"
  }
}

# Create the EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach required policies to the EKS role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Create an EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

 vpc_config {
    subnet_ids = [
      aws_subnet.public_subnet_1.id,
      aws_subnet.public_subnet_2.id
    ] 
  endpoint_public_access  = true
  endpoint_private_access = true
   }
}
# Create IAM Role for EKS Worker Nodes
resource "aws_iam_role" "eks_worker_role" {
  name = "eks-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach required policies to worker nodes
resource "aws_iam_role_policy_attachment" "eks_worker_policies" {
  for_each = {
    AmazonEKSWorkerNodePolicy     = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKS_CNI_Policy          = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
  policy_arn = each.value
  role       = aws_iam_role.eks_worker_role.name
}


