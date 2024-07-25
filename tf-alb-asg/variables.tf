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

variable "AWS_ACCESS_KEY_ID" {
  description = "AWS access key"
  type        = string 
}

variable "AWS_SECRET_ACCESS_KEY" {
    description = "AWS secret key"
    type        = string
}

variable "ECR_URL" {
    description = "AWS ECR URL"
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