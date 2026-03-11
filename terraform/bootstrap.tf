# 1. Створення GCS Bucket для збереження Terraform State
resource "google_storage_bucket" "terraform_state" {
  name          = var.state_bucket_name # Має збігатися з тим, що буде в backend "gcs"
  location      = var.region
  force_destroy = false # Захист від випадкового видалення бакета через terraform destroy

  versioning {
    enabled = true
  }

  # Best Practice: Жорстка заборона публічного доступу
  public_access_prevention = "enforced"
}

# 2. Створення Artifact Registry для Docker образів
resource "google_artifact_registry_repository" "bloom_repo" {
  location      = var.region
  repository_id = "bloom-repo"
  description   = "Приватний репозиторій для Docker образів Bloom & Soil"
  format        = "DOCKER"
}
