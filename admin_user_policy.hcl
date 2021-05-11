# Allow access to admin user-context secrets
path "secret/data/mlrun/users/admin" {
  capabilities = ["read", "list", "create", "update", "sudo"]
}

path "secret/data/mlrun/users/admin/*" {
  capabilities = ["read", "list", "create", "update", "sudo"]
}

# Allow access to secrets of all projects.
# This is an overkill, but for now we assume all projects are allowed.
path "secret/data/mlrun/projects/*" {
  capabilities = ["read", "list", "create", "update"]
}
