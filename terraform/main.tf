# ---------- IAM Role for EC2 ----------
data "aws_iam_policy" "ecr_readonly" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.ecr_repo_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = data.aws_iam_policy.ecr_readonly.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.ecr_repo_name}-profile"
  role = aws_iam_role.ec2_role.name
}

# ---------- Security Group ----------
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "web_sg" {
  name        = "${var.ecr_repo_name}-sg"
  description = "Allow HTTP and SSH access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.ecr_repo_name}-sg"
  }
}

# ---------- AMI ----------
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ---------- EC2 Instance ----------
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = length(trimspace(var.key_name)) > 0 ? var.key_name : null

    user_data = <<-EOF
              #!/bin/bash
              set -xe

              # Update system
              yum update -y

              # Install Docker
              yum install -y docker

              # Start Docker
              systemctl start docker
              systemctl enable docker

              # Add ec2-user to docker group
              usermod -aG docker ec2-user

              # Install AWS CLI v2 (ensure installed)
              if ! command -v aws &> /dev/null
              then
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                yum install -y unzip
                unzip awscliv2.zip
                ./aws/install
              fi

              # Get region & account ID
              REGION="${var.aws_region}"
              ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F'"' '{print $4}')

              ECR_URI="$ACCOUNT_ID.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repo_name}"

              # Login to ECR
              aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

              # Pull latest image
              # docker pull $ECR_URI:latest
              aws ecr get-login-password --region ap-south-1 \
              | docker login --username AWS --password-stdin 108792016419.dkr.ecr.ap-south-1.amazonaws.com/portfolio-web

              docker pull 108792016419.dkr.ecr.ap-south-1.amazonaws.com/portfolio-web:latest


              # Run container
              # docker run -d --name portfolio -p 80:80 $ECR_URI:latest
              docker run -d --name portfolio -p 80:80 108792016419.dkr.ecr.ap-south-1.amazonaws.com/portfolio-web:latest

              EOF

  tags = {
    Name = "${var.ecr_repo_name}-instance"
  }
}
