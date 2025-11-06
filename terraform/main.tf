# ---------- ECR Repository ----------
resource "aws_ecr_repository" "app" {
    name                 = var.ecr_repo_name
    image_tag_mutability = "MUTABLE"
}

# ---------- ECR Lifecycle Policy ----------
resource "aws_ecr_lifecycle_policy" "app_policy" {
    repository = aws_ecr_repository.app.name
    policy = jsonencode({
        rules = [
        {
            rulePriority = 1
            description  = "Keep last 10 images"
            selection = {
                tagStatus    = "any"
                countType    = "imageCountMoreThan"
                countNumber  = 10
            }
            action = {
                type = "expire"
            }
        }]
    })
}

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

# ---------- EC2 Instance ----------
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = length(trimspace(var.key_name)) > 0 ? var.key_name : null

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user

              REGION="${var.aws_region}"

              ACCOUNT_ID=$$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F'"' '{print $$4}')
              ECR_URI="$${ACCOUNT_ID}.dkr.ecr.${var.aws_region}.amazonaws.com"

              aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin $${ECR_URI}

              docker pull ${aws_ecr_repository.app.repository_url}:latest || true
              docker run -d --name portfolio -p 80:80 ${aws_ecr_repository.app.repository_url}:latest
              EOF

  tags = {
    Name = "${var.ecr_repo_name}-instance"
  }
}
