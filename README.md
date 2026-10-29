# Homelab IaC

[![CD](https://github.com/Bhambya/homelab/actions/workflows/CD.yml/badge.svg)](https://github.com/Bhambya/homelab/actions/workflows/CD.yml)
[![Weekly host maintenance](https://github.com/Bhambya/homelab/actions/workflows/weekly_maintenance.yml/badge.svg)](https://github.com/Bhambya/homelab/actions/workflows/weekly_maintenance.yml)

## Overview

This repository contains the IaC ([Infrastructure as Code](https://en.wikipedia.org/wiki/Infrastructure_as_code)) configuration for my homelab. The setup securely connects a public VPS with my private home server network.

All services are containerized or run in a separate VM.

Security is a top priority. Only the SSH and HTTP[s] ports are exposed. All HTTP[s] traefik goes through the reverse proxy [Traefik](https://github.com/traefik/traefik). [Authelia](https://www.authelia.com/) authenticates and authorizes all requests. [CrowdSec](https://www.crowdsec.net/) bans bad actors automatically by parsing various logs. WireGuard VPN connects all the hosts in my homelab securely.

- **Infrastructure as Code**: Everything is defined in OpenTofu/Terraform for reproducibility
- **Automated Deployment**: GitHub Actions + Ansible playbooks are used for continuous deployment.
- **Comprehensive Monitoring**: I deploy Prometheus, Grafana, and Gatus for full observability

### Architecture

The setup uses a **public VPS as an internet gateway** that securely tunnels traffic to **my home server services** which is behind a CGNAT. This approach provides:

- **Availability**: Critical services on the VPN keep functioning if my home has a power/network outage.
- **Privacy & security**: My home network remains completely isolated from the internet. Single point of entry allows effective intrusion detection.

![High level architecture](docs/diagram.webp?raw=true "High level architecture")

## Services

The homelab runs various services distributed across VPS and the home server.

### Common services

These services run on both VPS and home server with specific configurations for each environment:

- [Traefik](https://traefik.io/traefik) - Reverse proxy for routing traffic and SSL termination
- [Filebrowser](https://github.com/gtsteffaniak/filebrowser) - Web-based file explorer for managing files
- [Backrest](https://github.com/garethgeorge/backrest/) - Web-UI for backup management built on top of [restic](https://restic.net/)
- [Apprise](https://github.com/caronc/apprise) - Push notification service for alerts and monitoring

### Monitoring services

Observability and monitoring stack deployed across both environments:

- [Prometheus](https://github.com/prometheus/prometheus) - Time-series database for metrics collection
- [Node exporter](https://github.com/prometheus/node_exporter) - Exports system metrics from both VPS and home server
- [Grafana](https://github.com/grafana/grafana) - Dashboarding and visualization for metrics and logs
- [Gatus](https://github.com/TwiN/gatus) - Service health monitoring and status page generation
- [cAdvisor](https://github.com/google/cadvisor) - Container resource usage monitoring *(home server only)*

### Services hosted directly on the VPS

Some services which don't require too much disk space or resources are hosted directly on the VPS:

- [Authelia](https://www.authelia.com/) - Authentication and authorization provider with OIDC support
- [Crowdsec](https://www.crowdsec.net/) - Collaborative security engine for blocking malicious IPs
- [Wireguard](https://www.wireguard.com/) - VPN server for secure tunneling to home server
- [IT-tools](https://github.com/CorentinTh/it-tools) - Collection of handy online tools for developers
- [Stirling-pdf](https://github.com/Stirling-Tools/Stirling-PDF) - PDF manipulation and processing tools
- [Vaultwarden](https://github.com/dani-garcia/vaultwarden) - Self-hosted Bitwarden-compatible password manager
- [Paperless-ngx](https://docs.paperless-ngx.com/) - Document management system with OCR capabilities
- [Linkwarden](https://github.com/linkwarden/linkwarden) - Bookmark and link management tool
- [Readeck](https://readeck.org/en/) - Read-later and article management service
- [Github Release Monitor](https://github.com/iamspido/github-release-monitor) - Monitors GitHub releases for software updates

### Services hosted on the home server

Services hosted on the home server behind the VPN:

- [Immich](https://immich.app/) - High-performance photo and video management with AI features
- [Jellyfin](https://jellyfin.org/) - Media server for streaming movies, TV shows, and family videos
- [Audiobookshelf](https://www.audiobookshelf.org/) - Audiobook and podcast server with progress tracking
- [Mealie](https://mealie.io/) - Recipe management and meal planning application
- [qBittorrent](https://www.qbittorrent.org/) - BitTorrent client with web interface
- [Pinchflat](https://github.com/kieraneglin/pinchflat) - YouTube channel archiver using yt-dlp
- [Speedtest](https://github.com/librespeed/speedtest-rust) - Self-hosted internet speed testing
- [Excalidraw](https://excalidraw.com/) - Collaborative whiteboard for creating hand-drawn diagrams


## VPN Architecture

[Wireguard](https://www.wireguard.com/) is the secret sauce that allows the outside world to connect to my home server which is behind a CGNAT. It works through a process called [NAT hole punching](https://en.wikipedia.org/wiki/Hole_punching_\(networking\)).

This homelab uses a dual-VPN setup to securely connect the public VPS to the home server network behind a dynamic IP.

![VPN](docs/vpn.svg?raw=true "VPN")

### Traffic Flow

1. **Inbound (Internet → Home Services)**:
   ```
   Internet → Gateway VPS → wg0 tunnel → Home Router → wg1 → Home VM → Docker Service
   ```

2. **Management Access**:
   ```
   Admin → Gateway VPS → wg0 → Home Router → wg1 → Home VMs (via SSH jump host)
   ```

3. **Service Access**:
   - Public services are exposed through Traefik on the Gateway VPS
   - Home services are tunneled through the VPN and proxied by Gateway Traefik
   - Internal home services use local Traefik instance

### Security Features

- **Network Isolation**: Home network is completely isolated from internet
- **Jump Host**: Gateway VPS serves as SSH jump host for home server management
- **Stateful Filtering**: iptables rules prevent unauthorized access patterns
- **Dynamic IP Support**: Home server can have dynamic IP; only VPS needs static IP

## Infrastructure as Code

The entire homelab infrastructure is defined and managed using OpenTofu/Terraform, enabling reproducible infrastructure deployments across Oracle Cloud Infrastructure (OCI) and Proxmox.

### VPS Infrastructure (Oracle Cloud - OCI)

The public VPS infrastructure leverages Oracle's **Always Free Tier** ARM-based compute instances:

#### VPS Infrastructure Table

| Instance | Provider | Type | CPU | RAM | Storage | Cost | Purpose |
|----------|----------|------|-----|-----|---------|------|---------|
| **Gateway VPS** | Oracle Cloud (OCI) | VM.Standard.A1.Flex (ARM64) | 4 OCPUs | 24GB | 150GB | **Free** | Primary internet gateway |
| **Little Gateway** | Oracle Cloud (OCI) | VM.Standard.E2.1.Micro (AMD64) | 1 OCPU | 1 GB | 50GB | **Free** | Backup/experimentation |

### Home Server Infrastructure (Proxmox)

The home server runs multiple VMs on Proxmox hypervisor, all defined through Terraform:

#### VM Specifications Table

| VM Name | CPU Cores | RAM | Disk | IP Address | Purpose | Key Features |
|---------|-----------|-----|------|------------|---------|--------------|
| **AdGuard Home** | 2 | 512MB | 4GB | 192.168.1.107/24 | DNS server & ad blocking | Auto-configured DNS rules for homelab domains |
| **WireGuard Router** | 2 | 512MB | 4GB | 192.168.1.104/24 | VPN gateway to OCI VPS | Dual-interface setup (wg0↔VPS, wg1↔internal VMs) |
| **Docker Services** | 4 | 20GB | 100GB | 192.168.1.103/24 | Docker Compose host | NFS mounts: Jellyfin, Movies, TV, Audiobooks, eBooks, Videos, Immich |
| **Tailscale Exit node** | 2 | 512MB | 4GB | 192.168.1.105/24 | Backup VPN & exit node | Fallback remote connectivity to my home network |

### Infrastructure Features

#### Network Configuration
- **Home Network**: `192.168.1.0/24` with static IP assignments
- **VPN Networks**: `10.13.13.0/24` (gateway-to-home) and `10.13.14.0/24` (internal mesh)
- **DNS Resolution**: AdGuard configured with homelab service records
- **Firewall Rules**: UFW rules automatically configured per service requirements

## Automated Deployment

The homelab infrastructure is automatically deployed using GitHub Actions and Ansible, with secrets kept in a private repository encrypted with Ansible Vault.

### Deployment Process

1. **Trigger**: Deployments run automatically on every push to the `main` branch or can be manually triggered
2. **GitHub Actions Workflow**: The `CD.yml` workflow orchestrates the entire deployment process
3. **Ansible Playbooks**: Two main playbooks handle deployments:
   - `deploy_vps.yml`: Deploys services to the public VPS
   - `deploy-home-server-docker.yml`: Deploys services to the home server using the VPS as the jump host.

### Deployment Steps

Each deployment follows this sequence:

1. **Environment Setup**:
   - Install Ansible on the GitHub Actions runner
   - Check out the private secrets repository into `.secrets/` using a read-only deploy key
   - Configure SSH agent for secure host access using the SSH key from GitHub Actions secrets

2. **Configuration Management**:
   - Clone the latest repository code to target hosts
   - Process `secret-mappings.yml` files to identify required secrets
   - Decrypt the vault variables on the runner with the vault password from GitHub Actions secrets
   - Generate `.env` files and configuration files with interpolated secrets

3. **Service Deployment**:
   - Deploy Docker Compose services with `docker compose up`
   - Configure system services (logrotate, cron jobs, etc.)
   - Verify service health and display deployment status

### Secrets Management

This repository is public, so no secrets live here, not even encrypted ones. They are kept in the private `Bhambya/homelab-secrets` repository as Ansible Vault encrypted inventory variables:

```
inventory/
  hosts.yml                                   # stub, hosts are defined in ansible/inventory.yml
  group_vars/all/vault.yml                    # secrets shared by all hosts
  host_vars/gateway/vault.yml                 # VPS secrets
  host_vars/home-server-containers/vault.yml  # home server secrets
```

`secret-mappings.yml` maps each env var or secret file to a `vault_*` variable name. The repository is passed to Ansible as a second inventory source (`-i .secrets/inventory`) so its variables are loaded like any other `group_vars`/`host_vars`.

GitHub Actions secrets on this repository:

- `ANSIBLE_VAULT_PASSWORD`: vault password
- `SECRETS_REPO_DEPLOY_KEY`: read-only deploy key for the secrets repository
- `ANSIBLE_SSH_KEY`, `VPS_HOST`, `VPS_HOST_SSH_PUBLIC_KEYS`: needed before Ansible runs

#### Adding or changing secrets

Run these from the root of this repository, with the secrets repository cloned to `.secrets/` (see [Manual Deployment](#manual-deployment)). Setting `ANSIBLE_CONFIG` lets `ansible-vault` find the vault password:

```bash
export ANSIBLE_CONFIG=ansible/ansible.cfg
```

Pick the vault file by which hosts need the secret:

| Used by | File |
|---|---|
| Both hosts (same value) | `.secrets/inventory/group_vars/all/vault.yml` |
| VPS only | `.secrets/inventory/host_vars/gateway/vault.yml` |
| Home server only | `.secrets/inventory/host_vars/home-server-containers/vault.yml` |

**Changing an existing secret**

1. Open the vault file. It is decrypted into your `$EDITOR` and re-encrypted on save:
   ```bash
   ansible-vault edit .secrets/inventory/host_vars/gateway/vault.yml
   ```
2. Commit and push the secrets repository.
3. Pushing to the secrets repository does not deploy anything, so trigger the deployment manually:
   ```bash
   gh workflow run CD.yml -f target_host=vps   # or home-server-containers
   ```
   Containers whose environment changed are recreated automatically. Secret *files* (e.g. the Authelia JWKS keys) are mounted, so restart the container that uses them.

**Adding a new secret**

1. Add it to the right vault file with `ansible-vault edit`, named `vault_<name>`:
   ```yaml
   vault_my_service_api_key: s3cr3t
   # Multi-line values (keys, certificates, JSON) go in a block scalar
   vault_my_service_tls_key: |
     -----BEGIN PRIVATE KEY-----
     ...
     -----END PRIVATE KEY-----
   # Values containing {{ or {% must be marked !unsafe so Ansible doesn't template them
   vault_my_service_password: !unsafe 'p@ss{{word'
   ```
2. Commit and push the secrets repository **first**. Every CD run checks out its latest `main`, so if this repository references a variable the secrets repository doesn't have yet, the deploy fails with `No variable named 'vault_...' was found`.
3. Reference it from this repository:
   - As an env var, in `hosts/<host>/secret-mappings.yml`. Then use `${MY_SERVICE_API_KEY}` in `compose.yml` and add it to `.env.example`:
     ```yaml
     secrets:
       MY_SERVICE_API_KEY: vault_my_service_api_key
     ```
   - As a file on the host, in the same file:
     ```yaml
     secret_files:
       - path: /var/lib/docker-data/my-service/tls.key
         secret: vault_my_service_tls_key
         mode: "600"   # optional, defaults to 600
     ```
   - Anywhere else Ansible templates (playbooks, `crons.yml`, `*.j2` templates), as `{{ vault_my_service_api_key }}`.
4. Push to `main`. The `hosts/` change triggers the deployment.

**Removing a secret**: remove its references from this repository first and deploy. Then delete it from the vault file.

**Viewing secrets**: `ansible-vault view <file>` prints the decrypted file without opening an editor.

**Readable diffs in the secrets repository (optional, one-time setup)**: make `git diff` and `git log -p` show decrypted content. The `.gitattributes` line is committed to the secrets repository; the `git config` is local to your clone:
```bash
echo '*.yml diff=ansible-vault' >> .secrets/.gitattributes
git -C .secrets config diff.ansible-vault.textconv "ansible-vault view --vault-password-file $PWD/ansible/vault-pass.sh"
```

### Manual Deployment

For manual deployments or troubleshooting:

```bash
# Install dependencies
pip install -r ansible/requirements.txt
ansible-galaxy role install -r ansible/requirements.yml

# Check out the secrets and store the vault password in the macOS keychain (once)
git clone git@github.com:Bhambya/homelab-secrets.git .secrets
security add-generic-password -a homelab -s ansible-vault -w

# Deploy to VPS
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i ansible/inventory.yml -i .secrets/inventory ansible/playbooks/deploy-vps.yml

# Deploy to home server
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i ansible/inventory.yml -i .secrets/inventory ansible/playbooks/deploy-home-server-containers.yml
```

Outside macOS, export `ANSIBLE_VAULT_PASSWORD` instead of using the keychain.

### Crowdsec setup

- Login to the [Crowdsec console](https://app.crowdsec.net) and enroll the node by following the instructions.

### Backups

Some data is backed up using [backrest](https://github.com/garethgeorge/backrest) (restic). The following paths are backed up:

- Vaultwarden: `/var/lib/docker-data/vaultwarden`
- Apprise: `/var/lib/docker-data/apprise/config`
- Authelia: `/var/lib/docker-data/authelia/config`
- Backrest: `/var/lib/docker-data/backrest/config`

Unfortunately, the backrest config cannot be checked-in because it doesn't support env variable interpolation: https://github.com/garethgeorge/backrest/issues/788.
Hence, when setting up for the first time, the repository and backup schedule needs to be configured through the backrest web UI.

In case of data loss, restore the latest snapshot using [restic](https://github.com/restic/restic).

### Paperless-ngx setup

#### Restoring backup

- Restore the backup to to `/var/lib/docker-data/paperless-ngx`

We don't back up some data so we need to regenerate it:

- Generate the document thumbnails: https://docs.paperless-ngx.com/administration/#thumbnails
- Generate the index: https://docs.paperless-ngx.com/administration/#index
- Train the classifier: https://docs.paperless-ngx.com/administration/#managing-the-automatic-matching-algorithm
