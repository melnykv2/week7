variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name"
  default     = "healthchecks"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.22.0/24"]
}

variable "db_name" {
  type        = string
  description = "Database name"
  default     = "hc"
}

variable "db_username" {
  type        = string
  description = "Database username"
  default     = "hc"
}

variable "db_instance_class" {
  type        = string
  description = "Database instance class"
  default     = "db.t3.micro"
}

variable "image_tag" {
  type        = string
  description = "Image tag in ECR to deploy"
  default     = "v3"
}
