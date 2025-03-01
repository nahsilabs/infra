talos_version = "v1.9"
cluster_name  = "nahsilabs"

control_planes = [
  {
    name      = "odroid-1"
    server_ip = "10.2.15.10"
    config_patches = [
      "./patches/base.yml",
      "./patches/control-plane.yml",
      "./patches/odroid-1.yml",
    ]
  },
  {
    name      = "odroid-2"
    server_ip = "10.2.15.20"
    config_patches = [
      "./patches/base.yml",
      "./patches/control-plane.yml",
      "./patches/odroid-2.yml",
    ]
  },
  {
    name      = "odroid-3"
    server_ip = "10.2.15.30"
    config_patches = [
      "./patches/base.yml",
      "./patches/control-plane.yml",
      "./patches/odroid-3.yml",
    ]
  },
]

workers = [
  {
    name      = "heliopolis"
    server_ip = "10.2.15.40"
    config_patches = [
      "./patches/base.yml",
      "./patches/heliopolis.yml",
    ]
  },
]
