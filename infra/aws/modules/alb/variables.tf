variable "create" {
  type = bool
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "vpc_id" {
  type = string
}