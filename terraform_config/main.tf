terraform {
  required_providers {
    yandex = {
      source = "terraform-registry.storage.yandexcloud.net/yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

resource "yandex_vpc_network" "default" {
  name = "my-vpc-network"
}

resource "yandex_vpc_subnet" "public" {
  name           = "public-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.default.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "private" {
  name           = "private-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.default.id
  v4_cidr_blocks = ["192.168.20.0/24"]
}

resource "yandex_vpc_security_group" "public_sg" {
  name        = "public-sg"
  description = "Security group for public subnet"

  network_id = yandex_vpc_network.default.id

  egress {
    protocol    = "tcp"
    description = "Allow outgoing traffic"
    from_port   = 0
    to_port     = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description   = "Allow SSH access"
    protocol      = "tcp"
    port          = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description   = "Allow HTTP traffic"
    protocol      = "tcp"
    port          = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description   = "Allow HTTPS traffic"
    protocol      = "tcp"
    port          = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "private_sg" {
  name        = "private-sg"
  description = "Security group for private subnet"

  network_id = yandex_vpc_network.default.id

  egress {
    protocol    = "tcp"
    description = "Allow outgoing traffic"
    from_port   = 0
    to_port     = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description   = "Allow Elasticsearch access from monitoring server"
    protocol      = "tcp"
    port          = 9200
    v4_cidr_blocks = ["192.168.20.0/24"]
  }

  ingress {
    description   = "Allow Zabbix Agent access from monitoring server"
    protocol      = "tcp"
    port          = 10050
    v4_cidr_blocks = ["192.168.20.0/24"]
  }

  ingress {
    description   = "Allow access to Kibana"
    protocol      = "tcp"
    port          = 5601
    v4_cidr_blocks = ["192.168.10.0/24"]
  }
}

resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  hostname    = "bastion.ru-central1.internal"
  platform_id = "standard-v1"
  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd80bm0rh4rkepi5ksdi"
      size     = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true
    security_group_ids = [yandex_vpc_security_group.public_sg.id]
  }
  allow_stopping_for_update = true

  metadata = {
    user-data = "${file("cloud-init.yaml")}"
  }
}

resource "yandex_compute_instance" "web" {
  count       = 2
  name        = "web-${count.index + 1}"
  hostname    = "web-${count.index + 1}.ru-central1.internal"
  platform_id = "standard-v1"
  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd80bm0rh4rkepi5ksdi"
      size     = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.private.id
    security_group_ids = [yandex_vpc_security_group.private_sg.id]
  }
  allow_stopping_for_update = true

  metadata = {
    user-data = "${file("cloud-init.yaml")}"
  }
}

resource "yandex_compute_instance" "zabbix" {
  name        = "zabbix"
  hostname    = "zabbix.ru-central1.internal"
  platform_id = "standard-v1"
  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd80bm0rh4rkepi5ksdi"
      size     = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    security_group_ids = [yandex_vpc_security_group.public_sg.id]
  }
  allow_stopping_for_update = true

  metadata = {
    user-data = "${file("cloud-init.yaml")}"
  }
}

resource "yandex_compute_instance" "elasticsearch" {
  name        = "elasticsearch"
  hostname    = "elasticsearch.ru-central1.internal"
  platform_id = "standard-v1"
  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd80bm0rh4rkepi5ksdi"
      size     = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.private.id
    security_group_ids = [yandex_vpc_security_group.private_sg.id]
  }
  allow_stopping_for_update = true

  metadata = {
    user-data = "${file("cloud-init.yaml")}"
  }
}

resource "yandex_compute_instance" "kibana" {
  name        = "kibana"
  hostname    = "kibana.ru-central1.internal"
  platform_id = "standard-v1"
  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd80bm0rh4rkepi5ksdi"
      size     = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.private.id
    security_group_ids = [yandex_vpc_security_group.private_sg.id]
  }
  allow_stopping_for_update = true

  metadata = {
    user-data = "${file("cloud-init.yaml")}"
  }
}

resource "yandex_alb_target_group" "web_servers" {
  name = "web-servers"

  target {
    ip_address = yandex_compute_instance.web[0].network_interface[0].ip_address
    subnet_id  = yandex_vpc_subnet.private.id
  }

  target {
    ip_address = yandex_compute_instance.web[1].network_interface[0].ip_address
    subnet_id  = yandex_vpc_subnet.private.id
  }
}

resource "yandex_alb_backend_group" "web_backends" {
  name = "web-backend-group"

  http_backend {
    name   = "web-http-backend"
    weight = 1
    port   = 80
    target_group_ids = [yandex_alb_target_group.web_servers.id]

    load_balancing_config {
      panic_threshold = 50
    }

    healthcheck {
      timeout  = "5s"
      interval = "10s"
      http_healthcheck {
        path = "/"
      }
    }

    http2 = true
  }
}

resource "yandex_alb_http_router" "web_router" {
  name = "web-router"
}

resource "yandex_alb_load_balancer" "web_lb" {
  name       = "web-lb"
  network_id = yandex_vpc_network.default.id

  allocation_policy {
    location {
      zone_id   = var.yc_zone
      subnet_id = yandex_vpc_subnet.public.id
    }
    location {
      zone_id   = var.yc_zone
      subnet_id = yandex_vpc_subnet.public.id
    }
  }

  listener {
    name = "web-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id
      }
    }
  }
}

resource "yandex_compute_snapshot" "web_disk_snapshot" {
  count           = 1
  name            = "web-disk-snapshot-${count.index + 1}"
  source_disk_id  = yandex_compute_instance.web[count.index].boot_disk[0].disk_id

  labels = {
    snapshot = "daily"
  }
}
