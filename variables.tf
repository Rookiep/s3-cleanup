variable "bucket_name" {
  description = "Name of the S3 bucket to store logs"
  type        = string
  default     = "parthob" # change this to a unique bucket name!
}

# Number of days to retain logs before deletion
variable "retention_days" {
  description = "Number of days to retain logs before cleanup"
  type        = number
  default     = 7
}
