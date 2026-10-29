# write_secret_file

Ansible role that creates individual secret files from Ansible Vault variables.

## Requirements

- The private `homelab-secrets` inventory (Ansible Vault encrypted `group_vars`/`host_vars`) passed with `-i`
- The vault password available through `ansible/vault-pass.sh`

## Role Variables

The role expects an `item` variable with the following structure:

```yaml
item:
  path: "/var/lib/docker-data/app/secret.txt"  # Absolute path for the secret file
  secret: "vault_app_secret"                    # Vault variable name
  mode: "0600"                                 # File permissions (optional, defaults to 600)
  base64: false                                # Whether to base64 decode the secret (optional, defaults to false)
```

## Variable Details

- `path` (required): Absolute path where the secret file will be created
- `secret` (required): Name of the vault variable holding the content
- `mode` (optional): File permissions, defaults to `"600"`
- `base64` (optional): If `true`, the secret value will be base64 decoded before writing

## Dependencies

None

## Example Usage

### Basic Secret File

```yaml
- name: Create database password file
  ansible.builtin.include_role:
    name: write_secret_file
  vars:
    item:
      path: "/var/lib/docker-data/postgres/password.txt"
      secret: "vault_postgres_password"
      mode: "0400"
```

### Base64 Encoded Secret

```yaml
- name: Create SSL certificate file
  ansible.builtin.include_role:
    name: write_secret_file
  vars:
    item:
      path: "/etc/ssl/certs/app.crt"
      secret: "vault_ssl_cert_base64"
      mode: "0644"
      base64: true
```

### Loop Over Multiple Secret Files

```yaml
- name: Create multiple secret files
  ansible.builtin.include_role:
    name: write_secret_file
  loop:
    - path: "/var/lib/docker-data/app/db_password.txt"
      secret: "vault_db_password"
    - path: "/var/lib/docker-data/app/api_key.txt"
      secret: "vault_api_key"
      mode: "0400"
    - path: "/var/lib/docker-data/app/certificate.pem"
      secret: "vault_cert_base64"
      base64: true
  loop_control:
    loop_var: item
```

## Behavior

1. **Directory Creation**: Automatically creates parent directories with mode `700`
2. **Secret Lookup**: Reads the vault variable on the control node
3. **Content Processing**: Optionally base64 decodes the secret value
4. **File Creation**: Creates the secret file on the target host with specified permissions

## Error Handling

- Fails if the referenced vault variable is not defined for the host
- Creates parent directories if they don't exist

## Security Notes

- Secrets are decrypted on the control node and transferred securely to target hosts
- The task runs with `no_log`, so secret values never show up in output
- Multi-line values (PEM keys, JSON) can be stored as-is with a YAML block scalar; `base64` is only needed for binary content
- Default file permissions are restrictive (`600`)
- Parent directories are created with secure permissions (`700`)