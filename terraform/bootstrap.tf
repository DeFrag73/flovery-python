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

  # Required by org policy
  uniform_bucket_level_access = true
}

# Активуємо всі необхідні API для проєкту
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",                  # Для Cloud Run
    "compute.googleapis.com",              # Для Load Balancer та SSL
    "iam.googleapis.com",                  # Для створення Service Account
    "iamcredentials.googleapis.com",       # Для Workload Identity Federation
    "artifactregistry.googleapis.com",     # Для Artifact Registry
    "cloudresourcemanager.googleapis.com", # Для керування IAM
    "iap.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Примусово створюємо сервісний акаунт для IAP
resource "google_project_service_identity" "iap_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "iap.googleapis.com"

  depends_on = [google_project_service.required_apis]
}

# 3. Створення Artifact Registry для Docker образів
resource "google_artifact_registry_repository" "bloom_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "bloom-repo"
  description   = "Приватний репозиторій для Docker образів Bloom & Soil"
  format        = "DOCKER"
}
