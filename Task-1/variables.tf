variable "aws_region" {
  default = "us-east-1"
}
variable "vpc_cidr" {
  default = "10.5.0.0/16"
}
variable "route_cidr" {
  default = "0.0.0.0/0"
}
variable "subnets_cidr_public" {
  type    = list(any)
  default = ["10.5.1.0/24", "10.5.2.0/24"]
}
variable "subnets_cidr_private" {
  type    = list(any)
  default = ["10.5.5.0/24", "10.5.6.0/24"]
}
variable "azs" {
  type    = list(any)
  default = ["us-east-1a", "us-east-1b"]
}
variable "nic_private_ips" {
  type    = list(any)
  default = ["10.5.5.50/32", "10.5.6.50/32"]
}

variable "ami_type" {
  default = "ami-0cf6c10214cc015c9"
}

variable "ami_instance_type" {
  default = "t2.micro"
}

variable "name" {
  default = "CourseProject123"
}

variable "type" {
  type        = string
  default     = "private"
  description = "Type of subnets to create (`private` or `public`)"
}