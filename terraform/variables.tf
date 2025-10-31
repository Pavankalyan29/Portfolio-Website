variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "ecr_repo_name" {
  description = "ECR repository name"
  type        = string
  default     = "portfolio"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name (optional)"
  type        = string
  default     = "jenkins-key"
}

variable "allowed_cidr" {
  description = "CIDR allowed to access SSH/HTTP (default open)"
  type        = string
  default     = "0.0.0.0/0"
}
