resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "proxmox"
  url          = "https://cloud-images.ubuntu.com/noble/20260108/noble-server-cloudimg-amd64.img"
  # need to rename the file to *.qcow2 to indicate the actual file format for import
  file_name          = "noble-server-cloudimg-amd64.qcow2"
  checksum           = "00786c0936a7dd91a6b07941ca60bb56652975e0e72f9dacf73c887ada420966"
  checksum_algorithm = "sha256"
}

locals {
  adguard_host_ip = "192.168.1.107"
  adguard_config = templatefile("${path.module}/adguard_home_config.tftpl",
    {
      base_domain : var.base_domain,
      host_ip : local.adguard_host_ip,
      admin_password_hash : data.bitwarden_secret.adguard_admin_password_hash.value
    }
  )
}

module "adguard" {
  source = "./ubuntu_vm"

  proxmox_node     = "proxmox"
  hostname         = "adguard"
  cpu_cores        = 2
  dedicated_memory = 1024
  floating_memory = 700
  disk_size        = 8
  disk_import_from = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
  start_order      = 1
  up_delay         = 30
  ipv4_address     = "${local.adguard_host_ip}/24"
  ipv4_gateway     = "192.168.1.1"
  dns_servers      = ["192.168.1.1"]
  ssh_authorized_keys = [
    trimspace(file(var.ssh_public_key_path)),
    trimspace(data.bitwarden_secret.github_ci_ansible_ssh_public_key.value)
  ]
  additional_rumcmds = [
    "curl -fsSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v",
    "/opt/AdGuardHome/AdGuardHome -s stop",
    indent(4, "|\ncat > /opt/AdGuardHome/AdGuardHome.yaml <<'EOAC'\n${local.adguard_config}\nEOAC"),
    "/opt/AdGuardHome/AdGuardHome -s start"
  ]
  ufw_allow_rules = [
    "ssh",
    "http",
    "53/tcp",
    "53/udp",
    "51820/udp",
  ]
}

module "tailscale" {
  source = "./ubuntu_vm"

  depends_on       = [module.adguard]
  proxmox_node     = "proxmox"
  hostname         = "tailscale"
  cpu_cores        = 2
  dedicated_memory = 1024
  floating_memory  = 700
  disk_size        = 8
  disk_import_from = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
  start_order      = 1
  ipv4_address     = "192.168.1.105/24"
  ipv4_gateway     = "192.168.1.1"
  dns_servers      = [local.adguard_host_ip]
  ssh_authorized_keys = [
    trimspace(file(var.ssh_public_key_path)),
    trimspace(data.bitwarden_secret.github_ci_ansible_ssh_public_key.value)
  ]
  additional_rumcmds = [
    # One-command install, from https://tailscale.com/download/
    "curl -fsSL https://tailscale.com/install.sh | sh",
    # Set sysctl settings for IP forwarding (useful when configuring an exit node)
    "echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-tailscale.conf && echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-tailscale.conf && sysctl -p /etc/sysctl.d/99-tailscale.conf",
    # Register tailscale node using auth-key.
    # NOTE: This command hangs until you approve the node in tailscale admin UI
    "tailscale up --auth-key=${data.bitwarden_secret.tailscale_auth_key.value}",
    # (Optional) Include this line to configure this machine as an exit node
    "tailscale set --advertise-exit-node --advertise-routes=192.168.1.0/24 --hostname home-network-exit-node"
  ]
  ufw_allow_rules = [
    "ssh",
    "51820/udp"
  ]
}

module "wireguard-router" {
  source = "./ubuntu_vm"

  depends_on       = [module.adguard]
  proxmox_node     = "proxmox"
  hostname         = "wireguard-router"
  cpu_cores        = 2
  dedicated_memory = 1024
  floating_memory  = 700
  disk_size        = 8
  disk_import_from = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
  start_order      = 1
  up_delay         = 30
  ipv4_address     = "192.168.1.104/24"
  ipv4_gateway     = "192.168.1.1"
  dns_servers      = [local.adguard_host_ip]
  ssh_authorized_keys = [
    trimspace(file(var.ssh_public_key_path)),
    trimspace(data.bitwarden_secret.github_ci_ansible_ssh_public_key.value)
  ]
  additional_rumcmds = [
    # Set sysctl settings for IP forwarding
    "echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-allow-forwarding.conf && echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-allow-forwarding.conf && sysctl -p /etc/sysctl.d/99-allow-forwarding.conf",
  ]
  ufw_allow_rules = [
    "ssh",
    "51820/udp"
  ]
}

module "containers" {
  source = "./ubuntu_vm"

  depends_on       = [module.adguard]
  proxmox_node     = "proxmox"
  hostname         = "containers"
  cpu_cores        = 4
  dedicated_memory = 22528
  floating_memory = 16384
  disk_size        = 100
  disk_import_from = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
  start_order      = 3 # so that it comes up after Truenas
  ipv4_address     = "192.168.1.103/24"
  ipv4_gateway     = "192.168.1.1"
  dns_servers      = [local.adguard_host_ip]
  ssh_authorized_keys = [
    trimspace(file(var.ssh_public_key_path)),
    trimspace(data.bitwarden_secret.github_ci_ansible_ssh_public_key.value)
  ]
  additional_packages = [
    "nfs-common",
    "restic",
    "sqlite3"
  ]
  additional_rumcmds = [
    "apt-get update",
    "apt-get -y install ca-certificates curl",
    "install -m 0755 -d /etc/apt/keyrings",
    "rm -f /etc/apt/keyrings/docker.asc",
    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
    "chmod a+r /etc/apt/keyrings/docker.asc",
    "rm -f /etc/apt/sources.list.d/docker.list",
    "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$${UBUNTU_CODENAME:-$VERSION_CODENAME}\") stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null",
    "apt-get update",
    "apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
    "mkdir -p /etc/docker/",
    # https://www.reddit.com/r/selfhosted/comments/1az6mqa/psa_adjust_your_docker_defaultaddresspool_size/
    # Otherwise, you may end up with subnet ranges inside your containers that overlap with the real LAN 
    # and make hosts unreachable.
    indent(4, "|\ncat > /etc/docker/daemon.json <<'EODC'\n${file("${path.module}/docker-config.json")}\nEODC"),
    "systemctl restart docker",
    "mount -a"
  ]
  mounts = [
    "['192.168.1.101:/mnt/nvme/nvme/AppData/jellyfin', '/mnt/jellyfin', 'nfs', 'defaults,_netdev', '0', '0']",
    "['192.168.1.101:/mnt/nvme/nvme/Audiobooks', '/mnt/Audiobooks', 'nfs', 'defaults,_netdev', '0', '0']",
    "['192.168.1.101:/mnt/nvme/nvme/EBooks', '/mnt/EBooks', 'nfs', 'defaults,_netdev', '0', '0']",
    "['192.168.1.101:/mnt/nvme/nvme/Movies', '/mnt/Movies', 'nfs', 'defaults,_netdev', '0', '0']",
    "['192.168.1.101:/mnt/nvme/nvme/TV', '/mnt/TV', 'nfs', 'defaults,_netdev', '0', '0']",
    "['192.168.1.101:/mnt/nvme/nvme/Videos', '/mnt/Videos', 'nfs', 'defaults,_netdev', '0', '0']",
    "['192.168.1.101:/mnt/nvme/nvme/Pictures/immich', '/mnt/immich', 'nfs', 'defaults,_netdev', '0', '0']"
  ]
  ufw_allow_rules = [
    "ssh",
    "http",
    "https",
    "51820/udp",
    "from 172.16.0.0/12" # allow from the docker subnet
  ]
}
