variable "PROJECT" {
  description = "Project name"
  type        = string 
}

variable "REGION" {
  description = "AWS region"
  type        = string 
}

variable "DEFAULT_TAGS" {
   description = "Default tags"
    type        = map(string) 
}

############################
## ENV used in shell script
############################

variable "AWS_ACCOUNT_ID" {
  description = "AWS account ID"
  type        = string 
}

variable "KEYPAIR_NAME" {
    description = "Key pair name to connect to the instance"
    type        = string
}

variable "HOST_PORT" {
    description = "Host port"
    type        = number
}

variable "CONTAINER_PORT" {
    description = "Container port"
    type        = number
}