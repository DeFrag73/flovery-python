# Виводимо згенеровані значення, щоб скопіювати їх у GitHub Actions
output "workload_identity_provider_id" {
  value       = google_iam_workload_identity_pool_provider.github_provider.name
  description = "Скопіюй це для GitHub Actions (workload_identity_provider)"
}

output "service_account_email" {
  value       = google_service_account.github_actions.email
  description = "Скопіюй це для GitHub Actions (service_account)"
}