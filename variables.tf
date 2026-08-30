variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type. Keep this Free Tier eligible (t3.micro or t2.micro) unless you mean to pay."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Short name used to tag and name all resources created by this config"
  type        = string
  default     = "terraform-demo"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance. Defaults to open access for learning purposes only — restrict this to your own IP (e.g. 203.0.113.5/32) for anything beyond a throwaway demo."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ubuntu_ami_name_filter" {
  description = "Name filter used to look up the latest matching Ubuntu AMI"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}
