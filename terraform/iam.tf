# Створюємо Service Account спеціально для GitHub Actions
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
}

# Надаємо права цьому Service Account (щоб він міг деплоїти Cloud Run та міняти інфраструктуру)
resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset([
    "roles/editor",                          # Загальні права на редагування ресурсів
    "roles/resourcemanager.projectIamAdmin", # Щоб Terraform міг призначати ролі
    "roles/storage.admin",                   # Для доступу до tfstate бакета
    "roles/run.admin",                       # Для деплою Cloud Run
    "roles/artifactregistry.admin",          # Для пушу Docker образів
    "roles/iam.serviceAccountUser"           # Щоб Cloud Run міг запускатись від імені Service Account
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Створюємо Workload Identity Pool
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions"
}

# Створюємо Provider для GitHub
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Жорстка умова - дозволяти доступ ТІЛЬКИ цьому репозиторію
  attribute_condition = "assertion.repository == \"defrag73/flovery-python\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Дозволяємо GitHub-репозиторію використовувати цей Service Account
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/deFrag73/flovery-python"
}
