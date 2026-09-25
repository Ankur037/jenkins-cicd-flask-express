variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name to register the SSH key pair under in AWS"
  type        = string
  default     = "jenkins-cicd-key"
}

variable "public_key_path" {
  description = "Path to the local public key file"
  type        = string
  default     = "./terraform-key.pub"
}
