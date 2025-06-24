variable "create" {
  type = bool
}

variable "public_subnet" {
  type = string
}

variable "private_rtb_ids" {
  type = list(string)
}