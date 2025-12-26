variable "aws_region" {}
variable "my_ip_cidr" {}
variable "name_prefix" {}
variable "instance_type" {}
variable "app_port" {
  type    = number
  default = 8080
}
