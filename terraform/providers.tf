terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # ПОКИ ЩО ЗАКОМЕНТОВАНО! Ми розкоментуємо це на Кроці 3.
  # backend "gcs" {
  #   bucket = "bloom-terraform-state-unique-123" # Назва має бути глобально унікальною!
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
