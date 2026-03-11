resource "google_cloud_run_v2_service" "app" {
  name     = "bloom-catalog-api"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" # Дозволяємо трафік ТІЛЬКИ через Load Balancer

  template {
    containers {
      image = var.docker_image

      # Cloud Run автоматично надає змінну $PORT.
      # Оскільки твій Dockerfile використовує 8000, ми вказуємо це тут.
      ports {
        container_port = 8000
      }

      # Передаємо змінні середовища (env vars) у контейнер
      env {
        name  = "MONGO_URL"
        value = var.mongo_url
      }
      env {
        name  = "ADMIN_API_TOKEN"
        value = var.admin_api_token
      }
      env {
        name  = "CLOUDINARY_CLOUD_NAME"
        value = var.cloudinary_cloud_name
      }
      env {
        name  = "CLOUDINARY_API_KEY"
        value = var.cloudinary_api_key
      }
      env {
        name  = "CLOUDINARY_API_SECRET"
        value = var.cloudinary_api_secret
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image, # Terraform більше не буде відкочувати версію образу
    ]
  }

  depends_on = [google_project_service.required_apis]
}

# Дозволяємо Load Balancer'у викликати наш Cloud Run (надаємо публічний доступ до LB)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# =========================================================
# 2. НАЛАШТУВАННЯ LOAD BALANCER ТА HTTPS
# =========================================================

# Створюємо резервну публічну статичну IP-адресу для Load Balancer
resource "google_compute_global_address" "default" {
  name = "bloom-api-ip"

  depends_on = [google_project_service.required_apis]
}

# Serverless NEG (Міст між Load Balancer та Cloud Run)
resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  name                  = "bloom-serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_v2_service.app.name
  }
}

# Backend Service (керує трафіком, підключає NEG)
resource "google_compute_backend_service" "default" {
  name                  = "bloom-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }
}

# URL Map (маршрутизатор трафіку, скеровує всі запити на наш Backend Service)
resource "google_compute_url_map" "default" {
  name            = "bloom-url-map"
  default_service = google_compute_backend_service.default.id
}

# Google Managed SSL Certificate (Автоматичний безкоштовний HTTPS сертифікат)
resource "google_compute_managed_ssl_certificate" "default" {
  name = "bloom-managed-cert"

  managed {
    domains = [var.domain_name] # Наприклад: api.bloomsoil.com
  }

  depends_on = [google_project_service.required_apis]
}

# Target HTTPS Proxy (Зв'язує URL Map та SSL сертифікат)
resource "google_compute_target_https_proxy" "default" {
  name             = "bloom-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

# Global Forwarding Rule (Фінальна точка входу: слухає порт 443 і перенаправляє на Proxy)
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "bloom-https-forwarding-rule"
  target                = google_compute_target_https_proxy.default.id
  port_range            = "443"
  ip_address            = google_compute_global_address.default.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Виводимо IP-адресу, яку треба буде прописати в DNS (А-запис)
output "load_balancer_ip" {
  value = google_compute_global_address.default.address
}