variable "project_id" {
  description = "ID GCP проєкту"
  type        = string
}

variable "region" {
  description = "Регіон"
  type        = string
  default     = "europe-west4"
}

variable "state_bucket_name" {
  description = "Глобально унікальна назва для бакета зі стейтом"
  type        = string
}

variable "domain_name" {
  description = "Доменне ім'я для додатку (наприклад, api.bloomsoil.com)"
  type        = string
}

variable "docker_image" {
  description = "URL Docker-образу в Artifact Registry"
  type        = string
}

# Змінні середовища для FastAPI
variable "mongo_url" {
  type      = string
  sensitive = true
}

variable "admin_api_token" {
  type      = string
  sensitive = true
}

# Додай сюди також CLOUDINARY_CLOUD_NAME, API_KEY тощо.