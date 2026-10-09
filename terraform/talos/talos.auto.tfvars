talos_version        = "v1.14.2"
talos_config_version = "v1.14.2"
kubernetes_version   = "1.37.1"
etcd_image           = "registry.k8s.io/etcd:v3.7.2"
coredns_image        = "registry.k8s.io/coredns/coredns:v1.14.7"
cluster_name         = "nahsilabs"

nodes = [
  {
    name      = "odroid-1"
    server_ip = "10.2.15.10"
    role      = "controlplane"
    config_patches = [
      "./patches/base.yml",
      "./patches/controlplane.yml",
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
      "./patches/controlplane.yml",
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
      "./patches/controlplane.yml",
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
      "siderolabs/i915",
      "siderolabs/xe",
      "siderolabs/qemu-guest-agent",
    ]
    extra_kernel_args = ["xe.probe_display=0"]
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
      "siderolabs/nonfree-kmod-nvidia-production",
      "siderolabs/nvidia-container-toolkit-production",
    ]
  },
  {
    name      = "ephesus"
    server_ip = "10.2.15.80"
    role      = "worker"
    platform  = "metal"
    config_patches = [
      "./patches/base.yml",
      "./patches/ephesus.yml",
    ]
    extensions = [
      "siderolabs/amd-ucode",
      "siderolabs/amdgpu",
      "siderolabs/realtek-firmware",
    ]
    extra_kernel_args = ["amd_iommu=off"]
  },
]
