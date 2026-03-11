variable "project_id" {
  description = "ID GCP проєкту"
  type        = string
}

variable "region" {
  description = "Регіон"
  type        = string
  default     = "europe-west1"
}

variable "state_bucket_name" {
  description = "Глобально унікальна назва для бакета зі стейтом"
  type        = string
}
