packer {
  required_plugins {
    hcloud = {
      version = "v1.6.0"
      source  = "github.com/hetznercloud/hcloud"
    }
  }
}

locals {
  write_image = <<-EOT
    set -ex
    echo 'Talos image loaded, writing to disk... '
    xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync
    echo 'done.'
  EOT

  clean_up = <<-EOT
    set -ex
    echo "Cleaning-up..."
    rm -rf /etc/ssh/ssh_host_*
  EOT
}

# Source for the Talos ARM image
source "hcloud" "talos-arm" {
  rescue       = "linux64"
  image        = "debian-12"
  location     = "hel1"
  server_type  = "cax11"
  ssh_username = "root"

  snapshot_name = "Talos Linux arm"
  snapshot_labels = {
    type    = "infra",
    os      = "talos",
    arch    = "arm",
    creator = "nahsilabs"
  }
}

# Source for the Talos x86 image
source "hcloud" "talos-x86" {
  rescue       = "linux64"
  image        = "debian-12"
  location     = "hel1"
  server_type  = "cx22"
  ssh_username = "root"

  snapshot_name = "Talos Linux x86"
  snapshot_labels = {
    type    = "infra",
    os      = "talos",
    arch    = "x86",
    creator = "nahsilabs"
  }
}

# Build the Talos ARM snapshot
build {
  sources = ["source.hcloud.talos-arm"]

  provisioner "file" {
    source      = "talos-arm.raw.xz"
    destination = "/tmp/talos.raw.xz"
  }

  # Write the Talos ARM image to the disk
  provisioner "shell" {
    inline = [local.write_image]
  }

  # Clean-up
  provisioner "shell" {
    inline = [local.clean_up]
  }
}

# Build the Talos x86 snapshot
build {
  sources = ["source.hcloud.talos-x86"]

  provisioner "file" {
    source      = "talos-x86.raw.xz"
    destination = "/tmp/talos.raw.xz"
  }

  # Write the Talos x86 image to the disk
  provisioner "shell" {
    inline = [local.write_image]
  }

  # Clean-up
  provisioner "shell" {
    inline = [local.clean_up]
  }
}
