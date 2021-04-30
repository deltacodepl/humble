resource "vault_kubernetes_auth_backend_role" "postgresql" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "postgresql"
  bound_service_account_names      = ["postgresql"]
  bound_service_account_namespaces = [var.default_namespace]
  token_ttl                        = 3600
  token_policies                   = ["postgresql"]
}

resource "vault_kubernetes_auth_backend_role" "postgresql_read_only" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "postgresql_read_only"
  bound_service_account_names      = ["postgresql"]
  bound_service_account_namespaces = [var.default_namespace]
  token_ttl                        = 3600
  token_policies                   = ["postgresql_read_only"]
}

resource "vault_policy" "postgresql_read_only" {
  name = "postgresql_read_only"

  policy = <<EOT
path "${vault_mount.kvv2-postgresql.path}" {
  capabilities = ["read"]
}
EOT
}

resource "random_password" "postgresql_password" {
  length           = 16
  special          = false
}

resource "random_password" "kratos_password" {
  length           = 16
  special          = false
}

resource "vault_mount" "kvv2-postgresql" {
  path        = "secret/posgresql"
  type        = "kv-v2"
}

resource "vault_generic_secret" "postgresql" {
  path = "${vault_mount.kvv2-postgresql.path}/data"

  data_json = <<EOT
{
  "username": "${local.postgresql_username}",
  "password": "${random_password.postgresql_password.result}",
  "kratos_username": "kratos",
  "kratos_password" : "${random_password.kratos_password.result}",
  "kratos_database": "kratos"
}
EOT
}
