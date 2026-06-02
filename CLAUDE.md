# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Infrastructure-as-code for a personal homelab. A public Oracle Cloud VPS acts as the internet-facing gateway; all actual services run on a home server behind CGNAT, reachable via WireGuard VPN tunnels. Everything is deployed via GitHub Actions → Ansible → Docker Compose.

## Key Commands

### Terraform (OpenTofu)
```bash
cd terraform/vps && tofu init && tofu plan && tofu apply
cd terraform/homeserver && tofu init && tofu plan && tofu apply
```

### Ansible
```bash
pip install -r ansible/requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml
ansible-galaxy role install -r ansible/requirements.yml

ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-vps.yml
ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-home-server-containers.yml
ansible-playbook -i ansible/inventory.yml ansible/playbooks/patch.yml
```

## Architecture

**Network topology**: Internet → VPS (OCI ARM64) → WireGuard (wg0) → Home Router → WireGuard (wg1) → Home VMs (Proxmox)

**VPS** acts as reverse proxy only: Traefik terminates TLS, Authelia enforces auth, CrowdSec blocks malicious IPs. Only SSH and HTTPS are internet-exposed.

**Home server** runs 4 Ubuntu VMs on Proxmox:
- AdGuard (DNS)
- WireGuard router (VPN gateway)
- Docker services (Immich, Jellyfin, Mealie, qBittorrent, etc.)
- Tailscale

**Deployment flow**:
1. Push to `main` → GitHub Actions detects changes in `hosts/` subdirectories
2. Secrets fetched from Bitwarden Secrets Manager (`bws` CLI)
3. Ansible writes `.env` files from secrets, then runs `docker compose up -d`
4. On first deploy (no `/var/lib/docker-data`), Restic backups are restored automatically

## Repository Layout

```
hosts/
  vps/docker/compose.yml          # All VPS services (Traefik, Authelia, Grafana, etc.)
  home-server-containers/docker/compose.yml  # Home services (Immich, Jellyfin, etc.)
  {host}/secret-mappings.yml      # Maps Bitwarden secret IDs → env var names
  {host}/crons.yml                # Cron jobs deployed to each host
ansible/
  playbooks/                      # deploy-vps.yml, deploy-home-server-containers.yml, patch.yml
  roles/                          # manage_crons, restore_postgres_backup, write_env_file, write_secret_file
  inventory.yml
terraform/
  vps/                            # OCI networking, gateway VM, little-gateway VM
  homeserver/                     # Proxmox VM definitions (ubuntu_vm module)
scripts/
  postgres-backup.sh              # DB backup script
  sqlite-db-backup.sh
  crowsec-hub-upgrade.sh
.github/workflows/
  CD.yml                          # Deploys on push to main
  weekly_maintenance.yml          # Weekly patching + Docker prune
```

## Secrets & Configuration

- All secrets live in **Bitwarden Secrets Manager**; never hardcoded
- `secret-mappings.yml` defines which Bitwarden secret IDs map to which env vars for each host
- Ansible `write_secret_file` and `write_env_file` roles materialize secrets on the target host at deploy time
- `local.auto.tfvars` files (gitignored) hold Terraform variable values locally

## Service Configuration Conventions

- Each service in `hosts/{host}/docker/` has its own subdirectory with static config files
- Dynamic/secret config is injected via `.env` at deploy time
- Docker data persisted at `/var/lib/docker-data/{service}/` on target hosts
- Traefik labels on each compose service define routing rules and auth middleware
- CrowdSec bouncers integrated with Traefik for automatic IP banning

## CI/CD

- `CD.yml` uses path filters — only redeploys hosts whose `hosts/` subdirectory changed
- Secrets are passed to Ansible via environment variables (`BWS_ACCESS_TOKEN`)
- The GitHub Actions runner must have SSH access to target hosts (key stored in repo secrets)
