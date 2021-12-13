resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_argo_tunnel" "humble_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "humble-tunnel"
  secret     = base64encode(random_password.tunnel_secret.result)
}

resource "cloudflare_record" "tunnels" {
  for_each = toset([
    "git"
  ])

  zone_id = data.cloudflare_zone.maibaloc_com.id
  type    = "CNAME"
  name    = each.key
  value   = "${cloudflare_argo_tunnel.humble_tunnel.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # Auto
}

resource "kubernetes_namespace" "namespaces" {
  for_each = toset([
    "cloudflared",
    "external-dns",
  ])

  metadata {
    name = each.key
  }
}

resource "kubernetes_secret" "cloudflared_credentials" {
  metadata {
    name = "cloudflared-credentials"
    namespace = "cloudflared"
  }

  data = {
    "credentials.json" = jsonencode({
      AccountTag   = var.cloudflare_account_id
      TunnelName   = cloudflare_argo_tunnel.humble_tunnel.name
      TunnelID     = cloudflare_argo_tunnel.humble_tunnel.id
      TunnelSecret = base64encode(random_password.tunnel_secret.result)
    })
  }
}

resource "cloudflare_api_token" "external_dns" {
  name = "homelab_external_dns"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.permissions["Zone Read"],
      data.cloudflare_api_token_permission_groups.all.permissions["DNS Write"]
    ]
    resources = {
      "com.cloudflare.api.account.zone.*" = "*"
    }
  }

  condition {
    request_ip {
      in = local.public_ips
    }
  }
}

resource "kubernetes_secret" "external_dns_token" {
  metadata {
    name = "cloudflare-api-token"
    namespace = "external-dns"
  }

  data = {
    "value" = cloudflare_api_token.external_dns.value
  }
}

resource "cloudflare_api_token" "cert_manager" {
  name = "homelab_cert_manager"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.permissions["Zone Read"],
      data.cloudflare_api_token_permission_groups.all.permissions["DNS Write"]
    ]
    resources = {
      "com.cloudflare.api.account.zone.*" = "*"
    }
  }

  condition {
    request_ip {
      in = local.public_ips
    }
  }
}

resource "kubernetes_secret" "cert_manager_token" {
  metadata {
    name = "cloudflare-api-token"
    namespace = "cert-manager"
  }

  data = {
    "api-token" = cloudflare_api_token.cert_manager.value
  }
}