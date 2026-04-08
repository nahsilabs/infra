talos_version = "v1.13.0-beta.1"
cluster_name  = "nahsilabs"

nodes = [
  {
    name      = "odroid-1"
    server_ip = "10.2.15.10"
    role      = "controlplane"
    config_patches = [
      "./patches/base.yml",
      "./patches/odroid-1.yml",
    ]
    extensions = [
      "siderolabs/i915",
      "siderolabs/intel-ucode",
      "siderolabs/qemu-guest-agent",
    ]
  },
  {
    name      = "odroid-2"
    server_ip = "10.2.15.20"
    role      = "controlplane"
    config_patches = [
      "./patches/base.yml",
      "./patches/odroid-2.yml",
    ]
    extensions = [
      "siderolabs/i915",
      "siderolabs/intel-ucode",
      "siderolabs/qemu-guest-agent",
    ]
  },
  {
    name      = "odroid-3"
    server_ip = "10.2.15.30"
    role      = "controlplane"
    config_patches = [
      "./patches/base.yml",
      "./patches/odroid-3.yml",
    ]
    extensions = [
      "siderolabs/i915",
      "siderolabs/intel-ucode",
      "siderolabs/qemu-guest-agent",
    ]
  },
  {
    name      = "heliopolis"
    server_ip = "10.2.15.40"
    role      = "worker"
    config_patches = [
      "./patches/base.yml",
      "./patches/heliopolis.yml",
    ]
    extensions = [
      "siderolabs/amd-ucode",
      "siderolabs/qemu-guest-agent",
    ]
  },
  {
    name      = "pergamon"
    server_ip = "10.2.15.70"
    role      = "worker"
    config_patches = [
      "./patches/base.yml",
      "./patches/pergamon.yml",
    ]
    extensions = [
      "siderolabs/amd-ucode",
      "siderolabs/qemu-guest-agent",
      "siderolabs/nonfree-kmod-nvidia-lts",
      "siderolabs/nvidia-container-toolkit-lts",
    ]
  },
]
