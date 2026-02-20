variable "proxmox_node" {
  type        = string
  description = "The Proxmox node to create the VM in"
}

variable "hostname" {
  type        = string
  description = "The hostname"
}

variable "cpu_cores" {
  type        = number
  description = "Number of CPU cores"
}

variable "dedicated_memory" {
  type        = number
  description = "Dedicated memory (RAM) in Megabytes"
}

variable "floating_memory" {
  type        = number
  description = "Floating memory (RAM) in Megabytes"
}

variable "disk_import_from" {
  type        = string
  description = "Image to import from"
}

variable "disk_size" {
  type        = number
  description = "Boot disk size in Gigabytes"
}

variable "ipv4_address" {
  type        = string
  description = "The IPv4 address with subnet"
}

variable "ipv4_gateway" {
  type        = string
  description = "The IPv4 gateway"
}

variable "dns_servers" {
  type        = list(string)
  description = "(Optional) The list of DNS servers"
}

variable "additional_packages" {
  type        = list(string)
  description = "Additional packages to be installed during cloud-init"
  default     = []
}

variable "additional_rumcmds" {
  type        = list(string)
  description = "Additional commands to run during cloud-init"
  default     = []
}

variable "mounts" {
  type        = list(string)
  description = "Lines in mounts for cloud-init https://cloudinit.readthedocs.io/en/latest/reference/examples.html#adjust-mount-points-mounted"
  default     = []
}

variable "ufw_allow_rules" {
  type        = list(string)
  description = "ufw rules to be allowed"
  default     = ["ssh"]
}

variable "ssh_authorized_keys" {
  type        = list(string)
  description = "Authorized ssh public keys"
  default     = []
}

variable "start_order" {
  type        = number
  description = "A non-negative number defining the general startup order."
}

variable "up_delay" {
  type        = number
  default     = 0
  description = "(Optional) A non-negative number defining the delay in seconds before the next VM is started."
}

variable "down_delay" {
  type        = number
  default     = 0
  description = "(Optional) A non-negative number defining the delay in seconds before the next VM is shut down."
}

