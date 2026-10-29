# write_env_file

Ansible role that creates environment files by combining fixed values, Ansible variables, and secrets from Ansible Vault.

## Requirements

- The private `homelab-secrets` inventory (Ansible Vault encrypted `group_vars`/`host_vars`) passed with `-i`
- The vault password available through `ansible/vault-pass.sh`

## Role Variables

The role expects an `env_file` variable with the following structure:

```yaml
env_file:
  relative_path: "docker/.env"  # Path relative to repo_path
  mode: "0600"                  # File permissions
  fixed:                        # Static key-value pairs
    COMPOSE_PROJECT_NAME: "homelab"
    ENVIRONMENT: "production"
  vars:                         # Values from Ansible variables
    DOMAIN: "domain_name"       # Uses {{ domain_name }} variable
    USER_ID: "user_id"          # Uses {{ user_id }} variable
  secrets:                      # Values from vault variables
    DB_PASSWORD: "vault_db_password" # Uses {{ vault_db_password }} from the secrets repo
    API_KEY: "vault_api_key"
```

`vars` and `secrets` resolve the same way; `secrets` exists to keep vault variables apart and is never logged.

## Dependencies

- `repo_path` variable must be defined (target directory path)

## Example Usage

```yaml
- name: Create application environment file
  ansible.builtin.include_role:
    name: write_env_file
  vars:
    env_file:
      relative_path: "docker/.env"
      mode: "0600"
      fixed:
        COMPOSE_PROJECT_NAME: "myapp"
        LOG_LEVEL: "info"
      vars:
        DOMAIN: "app_domain"
        PORT: "app_port"
      secrets:
        DATABASE_PASSWORD: "vault_database_password"
        JWT_SECRET: "vault_jwt_secret"
```

## Generated File Format

The role generates an environment file with the following format:

```bash
# Fixed values
COMPOSE_PROJECT_NAME='myapp'
LOG_LEVEL='info'

# Variable values
DOMAIN='example.com'
PORT='8080'

# Secret values (from Ansible Vault)
DATABASE_PASSWORD='secret_password_value'
JWT_SECRET='jwt_token_value'
```

## Error Handling

- Fails if a referenced vault variable is not defined for the host
- The task runs with `no_log`, so secret values never show up in output
