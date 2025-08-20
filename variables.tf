# S3 bucket name where logs will be stored
variable "bucket_name" {
  description = "Name of the S3 bucket to store logs"
  type        = string
  default     = "practicepar" #  must be globally unique
}

# Retention policy (age in days)
variable "retention_days" {
  description = "Delete objects older than this number of days"
  type        = number
  default     = 7
}

# Minimum file size for deletion (in KB)
variable "min_file_size_kb" {
  description = "Delete only objects larger than this size (in KB)"
  type        = number
  default     = 10
}
