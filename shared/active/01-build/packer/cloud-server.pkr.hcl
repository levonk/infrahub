# Cloud Server Base Image for OCI
# Location: shared/active/01-build/packer/cloud-server.pkr.hcl
# Purpose: Packer template for building the OCI cloud-server base VM image.
# Build:   just packer-build   / devbox run packer-build
# Validate: just packer-validate / devbox run packer-validate
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "oci_tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
  default     = ""
}

variable "oci_user_ocid" {
  description = "OCI User OCID"
  type        = string
  default     = ""
}

variable "oci_fingerprint" {
  description = "OCI API Key Fingerprint"
  type        = string
  default     = ""
}

variable "oci_key_file" {
  description = "Path to OCI API Private Key"
  type        = string
  default     = ""
}

variable "oci_region" {
  description = "OCI Region (e.g., us-ashburn-1)"
  type        = string
  default     = ""
}

variable "oci_compartment_ocid" {
  description = "OCI Compartment OCID"
  type        = string
  default     = ""
}

variable "oci_availability_domain" {
  description = "OCI Availability Domain"
  type        = string
  default     = ""
}

variable "oci_base_image_ocid" {
  description = "OCID of the base image (e.g., Debian Bookworm)"
  type        = string
  default     = ""
}

variable "oci_shape" {
  description = "OCI Compute Shape"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "oci_subnet_ocid" {
  description = "OCID of the subnet for build instance"
  type        = string
  default     = ""
}

variable "ssh_username" {
  description = "SSH username for provisioning"
  type        = string
  default     = "debian"
}

variable "image_name" {
  description = "Name for the resulting custom image"
  type        = string
  default     = "cloud-server-base"
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  timestamp = formatdate("YYYYMMDDhhmmss", timestamp())
}

# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

source "oracle-oci" "cloud_server" {
  tenancy_ocid     = var.oci_tenancy_ocid
  user_ocid        = var.oci_user_ocid
  fingerprint      = var.oci_fingerprint
  key_file         = var.oci_key_file
  region           = var.oci_region
  compartment_ocid = var.oci_compartment_ocid

  availability_domain = var.oci_availability_domain
  base_image_ocid     = var.oci_base_image_ocid
  shape               = var.oci_shape
  subnet_ocid         = var.oci_subnet_ocid

  ssh_username = var.ssh_username

  create_vnic_details {
    assign_public_ip = true
  }

  image_name = "${var.image_name}-${local.timestamp}"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name = "cloud-server"

  source "source.oracle-oci.cloud_server" {
    # Per-build overrides can go here
  }

  provisioner "shell" {
    inline = [
      "# Update package lists",
      "sudo apt-get update",
      "",
      "# Install required packages",
      "sudo apt-get install -y python3 sudo openssh-server",
      "",
      "# Ensure ssh service is enabled",
      "sudo systemctl enable ssh || true",
      "",
      "# Create cuser with UID/GID 1000",
      "sudo groupadd --gid 1000 cuser || true",
      "sudo useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash cuser || true",
      "",
      "# Configure passwordless sudo for cuser",
      "echo 'cuser ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/cuser",
      "sudo chmod 0440 /etc/sudoers.d/cuser",
      "",
      "# Ensure cuser .ssh directory exists",
      "sudo mkdir -p /home/cuser/.ssh",
      "sudo chmod 700 /home/cuser/.ssh",
      "sudo chown -R cuser:cuser /home/cuser/.ssh",
      "",
      "# Clean up",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*"
    ]
  }
}
