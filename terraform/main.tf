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

# 1. ПУБЛІЧНИЙ Backend Service (для каталогу)
resource "google_compute_backend_service" "public" {
  name                  = "bloom-public-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # Підключаємо WAF для блокування прямого IP
  security_policy = google_compute_security_policy.armor_policy.id

  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }
}

# 2. АДМІНСЬКИЙ Backend Service (з увімкненим IAP)
resource "google_compute_backend_service" "admin" {
  name                  = "bloom-admin-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # Підключаємо WAF для блокування прямого IP
  security_policy = google_compute_security_policy.armor_policy.id

  # Вмикаємо IAP для цього бекенду
  iap {
    oauth2_client_id     = var.iap_client_id
    oauth2_client_secret = var.iap_client_secret
  }

  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }
}

resource "google_compute_url_map" "default" {
  name            = "bloom-url-map" # Повернули стару назву
  default_service = google_compute_backend_service.public.id

  host_rule {
    hosts        = [var.domain_name]
    path_matcher = "bloom-paths"
  }

  path_matcher {
    name            = "bloom-paths"
    default_service = google_compute_backend_service.public.id

    path_rule {
      # Перенаправляємо всі адмінські шляхи на захищений IAP бекенд
      paths   = [
        "/admin-panel", "/admin-panel/*",
        "/api/v1/admin", "/api/v1/admin/*",
        "/docs", "/redoc", "/openapi.json"
      ]
      service = google_compute_backend_service.admin.id
    }
  }
}

# 4. Надаємо твоєму email право проходити через IAP
resource "google_iap_web_backend_service_iam_member" "admin_access" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.admin.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "user:${var.admin_email}"
}

# Google Managed SSL Certificate (Автоматичний безкоштовний HTTPS сертифікат)
resource "google_compute_managed_ssl_certificate" "default" {
  name = "bloom-managed-cert"

  managed {
    domains = [var.domain_name] # Наприклад: api.bloomsoil.com
  }
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

# =========================================================
# 3. GOOGLE CLOUD ARMOR (WEB APPLICATION FIREWALL)
# =========================================================

resource "google_compute_security_policy" "armor_policy" {
  name        = "bloom-security-policy"
  description = "Комплексний захист WAF"

  # 1. Захист від SQL-ін'єкцій (щоб ніхто не "зламав" запити до MongoDB)
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Блокувати SQL Injection"
  }

  # 2. Захист від міжсайтового скриптингу (XSS)
  rule {
    action   = "deny(403)"
    priority = 1001
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Блокувати XSS атаки"
  }

  # 3. Захист від віддаленого виконання коду (RCE) та включення файлів (LFI/RFI)
  rule {
    action   = "deny(403)"
    priority = 1002
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable') || evaluatePreconfiguredExpr('lfi-v33-stable') || evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }
    description = "Блокувати RCE, LFI, RFI атаки"
  }

  # 4. Забороняємо прямий доступ по IP
  rule {
    action   = "deny(404)"
    priority = 2000
    match {
      expr {
        # Якщо Host не дорівнює твоєму домену - відкидаємо запит
        expression = "request.headers['host'] != '${var.domain_name}'"
      }
    }
    description = "Блокувати прямий доступ по IP Load Balancer'а"
  }

  # 5. Дефолтне правило: Дозволити весь безпечний трафік
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Дозволити легітимний трафік"
  }
}

# =========================================================
# 4. HTTP ДО HTTPS РЕДІРЕКТ
# =========================================================

# URL Map, який робить виключно редірект на HTTPS
resource "google_compute_url_map" "http_redirect" {
  name = "bloom-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT" # 301 Redirect
    strip_query            = false
  }
}

# Target HTTP Proxy для редіректу
resource "google_compute_target_http_proxy" "http" {
  name    = "bloom-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

# Forwarding Rule для порту 80 (HTTP)
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "bloom-http-forwarding-rule"
  target                = google_compute_target_http_proxy.http.id
  port_range            = "80"
  ip_address            = google_compute_global_address.default.address # Використовуємо ту саму IP Load Balancer'а
  load_balancing_scheme = "EXTERNAL_MANAGED"
}