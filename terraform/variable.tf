variable "project_id" {
  sensitive   = true
  description = "GCP project id"
  type        = string
}

variable "location" {
  description = "GCP location/region"
  type        = string
}

variable "bucket_name" {
  description = "GCS bucket name to upload the function source code"
  type        = string
}

variable "service_account" {
  sensitive   = true
  description = "GCP service account"
  type        = string
}

variable "function_name" {
  description = "Cloud Run Function name"
  type        = string
}

variable "runtime" {
  description = "Function runtime"
  type        = string
}

variable "entry_point" {
  description = "Function entry point"
  type        = string
}

variable "min_instance" {
  description = "Minimum number of instance"
  type        = number
  default     = 0
}

variable "max_instance" {
  description = "Maximum number of instance"
  type        = number
  default     = 1
}

variable "max_concurrency" {
  description = "Maximum number of concurrent requests per instance"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory allocated to the function"
  type        = string
}

variable "cpu" {
  description = "CPU allocated to the function"
  type        = string
}

variable "scheduler_name" {
  description = "Cloud Scheduler name"
  type        = string
}

variable "schedule" {
  description = "Frequency of Cloud Scheduler job"
  type        = string
}

variable "timezone" {
  description = "Timezone of Cloud Scheduler job"
  type        = string
}

variable "http_body" {
  description = "HTTP request body"
  type        = string
}
