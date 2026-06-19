#!/bin/bash

# ============================================================
# СКРИПТ ДЛЯ РАЗВЁРТЫВАНИЯ ПРОЕКТА
# ============================================================
# Проект: diplom_test
# Путь: /home/user/git/diplom_test
# Репозиторий: https://github.com/MindMaze74/test_for_dip
# ============================================================

set -e

# ------------------------------------------------------------------
# ПЕРЕМЕННЫЕ
# ------------------------------------------------------------------
PROJECT_DIR="/home/user/git/diplom_test"
GIT_REPO="https://github.com/MindMaze74/test_for_dip.git"

echo "============================================================"
echo "  🚀 СОЗДАНИЕ ПРОЕКТА diplom_test"
echo "  Путь: $PROJECT_DIR"
echo "  Репозиторий: $GIT_REPO"
echo "============================================================"

# ------------------------------------------------------------------
# 1. СОЗДАНИЕ ПАПКИ ПРОЕКТА
# ------------------------------------------------------------------
echo "📁 Создание папки проекта..."
mkdir -p $PROJECT_DIR

cd $PROJECT_DIR

# ------------------------------------------------------------------
# 2. ИНИЦИАЛИЗАЦИЯ GIT
# ------------------------------------------------------------------
echo "🔧 Инициализация Git..."

# Удаляем старый .git, если есть
if [ -d ".git" ]; then
    echo "⚠️  Удаляем существующий .git..."
    rm -rf .git
fi

git init

# Проверяем, есть ли уже remote origin
if git remote get-url origin &>/dev/null; then
    echo "⚠️  Remote origin уже существует, обновляем URL..."
    git remote set-url origin $GIT_REPO
else
    git remote add origin $GIT_REPO
fi

# ------------------------------------------------------------------
# 3. СОЗДАНИЕ СТРУКТУРЫ ПАПОК
# ------------------------------------------------------------------
echo "📁 Создание структуры папок..."

mkdir -p ansible/{playbooks,roles,templates,inventory}
mkdir -p ansible/roles/{docker,nginx,prometheus,grafana,elasticsearch,kibana,filebeat}/{tasks,templates,vars}
mkdir -p terraform/templates
mkdir -p docs

# ------------------------------------------------------------------
# 4. СОЗДАНИЕ ФАЙЛОВ TERRAFORM
# ------------------------------------------------------------------
echo "📄 Создание файлов Terraform..."

# provider.tf
cat > terraform/provider.tf << 'EOF'
# ============================================================
# ПРОВАЙДЕРЫ TERRAFORM
# ============================================================
# 1. yandex-cloud/yandex - основной провайдер для Yandex Cloud
# 2. hashicorp/time - для задержек между созданиями ресурсов
# 3. hashicorp/local - для генерации файлов (inventory.ini)
# ============================================================

terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.95.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
  }
  required_version = ">= 1.0"
}

# Динамический образ Ubuntu 22.04
# Используется для всех ВМ
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# Аутентификация через сервисный аккаунт
# Ключ хранится локально и НЕ коммитится в Git
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.yc_cloud_id
  folder_id                = var.yc_folder_id
  zone                     = var.yc_zones[0]
}

provider "time" {}
provider "local" {}
EOF

# variables.tf
cat > terraform/variables.tf << 'EOF'
# ============================================================
# ПЕРЕМЕННЫЕ TERRAFORM
# ============================================================

# ------------------------------------------------------------------
# Yandex Cloud
# ------------------------------------------------------------------
variable "yc_cloud_id" {
  description = "ID облака Yandex Cloud"
  type        = string
}

variable "yc_folder_id" {
  description = "ID каталога Yandex Cloud"
  type        = string
}

variable "yc_zones" {
  description = "Зоны доступности Yandex Cloud"
  type        = list(string)
  default     = ["ru-central1-a", "ru-central1-b"]
}

variable "service_account_key_file" {
  description = "Путь к файлу ключа сервисного аккаунта"
  type        = string
  default     = "~/diplom-sa-key.json"
}

# ------------------------------------------------------------------
# Проект
# ------------------------------------------------------------------
variable "project_name" {
  description = "Имя проекта (используется в именах ресурсов)"
  type        = string
  default     = "diplom-test"
}

# ------------------------------------------------------------------
# SSH-доступ
# ------------------------------------------------------------------
variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу"
  type        = string
  default     = "~/.ssh/diplom.pub"
}

variable "ssh_private_key_path" {
  description = "Путь к приватному SSH-ключу"
  type        = string
  default     = "~/.ssh/diplom"
}

# ------------------------------------------------------------------
# Ресурсы ВМ
# ------------------------------------------------------------------
variable "image_id" {
  description = "ID образа Ubuntu 22.04 LTS"
  type        = string
  default     = "fd80mrhj8fl2oe87o4e1"
}
EOF

# terraform.tfvars.example
cat > terraform/terraform.tfvars.example << 'EOF'
# ============================================================
# ПРИМЕР КОНФИГУРАЦИОННОГО ФАЙЛА
# ============================================================
# Скопируйте этот файл в terraform.tfvars и заполните
# своими данными. terraform.tfvars НЕ КОММИТИТЬ!
# ============================================================

yc_cloud_id  = "b1gervu69v9ig93k4v83"
yc_folder_id = "b1g4blc2guo29mqbh6bp"

# Путь к ключу сервисного аккаунта
service_account_key_file = "~/diplom-sa-key.json"

# Пути к SSH-ключам (созданы локально)
ssh_public_key_path  = "~/.ssh/diplom.pub"
ssh_private_key_path = "~/.ssh/diplom"
EOF

# network.tf
cat > terraform/network.tf << 'EOF'
# ============================================================
# СЕТЕВАЯ ИНФРАСТРУКТУРА
# ============================================================
# 1. Одна VPC-сеть
# 2. Приватные подсети (для web, prometheus, elasticsearch, grafana, kibana)
# 3. Публичные подсети (для Bastion)
# 4. NAT-шлюз для выхода в интернет из приватных подсетей
# ============================================================

# Основная VPC-сеть
resource "yandex_vpc_network" "main" {
  name = "${var.project_name}-network"
}

# ------------------------------------------------------------------
# Приватные подсети (по одной на зону)
# ------------------------------------------------------------------
resource "yandex_vpc_subnet" "private" {
  count = length(var.yc_zones)

  name           = "${var.project_name}-private-${var.yc_zones[count.index]}"
  zone           = var.yc_zones[count.index]
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.${count.index + 1}.0/24"]
  route_table_id = yandex_vpc_route_table.nat.id  # Маршрут через NAT
}

# ------------------------------------------------------------------
# Публичные подсети (по одной на зону)
# ------------------------------------------------------------------
resource "yandex_vpc_subnet" "public" {
  count = length(var.yc_zones)

  name           = "${var.project_name}-public-${var.yc_zones[count.index]}"
  zone           = var.yc_zones[count.index]
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.${count.index + 10}.0/24"]
}

# ------------------------------------------------------------------
# NAT-шлюз для выхода в интернет из приватных подсетей
# ------------------------------------------------------------------
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "${var.project_name}-nat-gateway"
  shared_egress_gateway {}
}

# Таблица маршрутизации с маршрутом по умолчанию через NAT
resource "yandex_vpc_route_table" "nat" {
  name       = "${var.project_name}-nat-route-table"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}
EOF

# security-groups.tf
cat > terraform/security-groups.tf << 'EOF'
# ============================================================
# ГРУППЫ БЕЗОПАСНОСТИ
# ============================================================
# Bastion - единственная ВМ с публичным доступом
# Все остальные ВМ доступны только через Bastion
# ============================================================

# ------------------------------------------------------------
# BASTION: доступ из интернета
# ------------------------------------------------------------
resource "yandex_vpc_security_group" "bastion" {
  depends_on = [time_sleep.wait_for_security_groups]
  name        = "${var.project_name}-bastion-sg"
  description = "Security group для bastion host"
  network_id  = yandex_vpc_network.main.id

  # SSH из интернета
  ingress {
    description    = "SSH доступ"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (сайт) из интернета
  ingress {
    description    = "HTTP (сайт)"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana из интернета
  ingress {
    description    = "Grafana"
    protocol       = "TCP"
    port           = 3000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Kibana из интернета
  ingress {
    description    = "Kibana"
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Исходящий трафик разрешён полностью
  egress {
    description    = "Разрешаем весь исходящий трафик"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------
# ВНУТРЕННЯЯ ГРУППА: доступ только от Bastion
# ------------------------------------------------------------
resource "yandex_vpc_security_group" "internal" {
  depends_on = [time_sleep.wait_for_security_groups]
  name        = "${var.project_name}-internal-sg"
  description = "Internal security group for all VMs"
  network_id  = yandex_vpc_network.main.id

  # Весь трафик от Bastion разрешён
  ingress {
    description       = "All traffic from Bastion"
    protocol          = "ANY"
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  # SSH от Bastion
  ingress {
    description       = "SSH from Bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  # Исходящий трафик разрешён полностью
  egress {
    description    = "Разрешаем весь исходящий трафик"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------
# ВЕБ-СЕРВЕРЫ: доступ только от Bastion
# ------------------------------------------------------------
resource "yandex_vpc_security_group" "web" {
  depends_on = [time_sleep.wait_for_security_groups]
  name        = "${var.project_name}-web-sg"
  description = "Security group для веб-серверов"
  network_id  = yandex_vpc_network.main.id

  # HTTP от Bastion
  ingress {
    description       = "HTTP from Bastion"
    protocol          = "TCP"
    port              = 80
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  # SSH от Bastion
  ingress {
    description       = "SSH from Bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  # Исходящий трафик разрешён полностью
  egress {
    description    = "Разрешаем весь исходящий трафик"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
EOF

# instances.tf
cat > terraform/instances.tf << 'EOF'
# ============================================================
# ВИРТУАЛЬНЫЕ МАШИНЫ
# ============================================================
# Все ВМ (кроме Bastion) находятся в приватных подсетях
# Используется динамический образ Ubuntu 22.04
# ============================================================

# ------------------------------------------------------------
# ВЕБ-СЕРВЕРЫ (2 шт, в разных зонах)
# ------------------------------------------------------------
resource "yandex_compute_instance" "web" {
  count = 2

  name        = "${var.project_name}-web-${count.index + 1}"
  hostname    = "${var.project_name}-web-${count.index + 1}"
  platform_id = "standard-v2"
  zone        = var.yc_zones[count.index]

  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20  # Прерываемые ВМ для экономии
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private[count.index].id
    nat                = false  # Без публичного IP
    security_group_ids = [yandex_vpc_security_group.web.id, yandex_vpc_security_group.internal.id]
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
      ssh_public_key = file(var.ssh_public_key_path)
    })
  }

  scheduling_policy {
    preemptible = true  # Прерываемые ВМ для экономии
  }
}

# ------------------------------------------------------------
# PROMETHEUS
# ------------------------------------------------------------
resource "yandex_compute_instance" "prometheus" {
  depends_on = [time_sleep.wait_for_prometheus]

  name        = "${var.project_name}-prometheus"
  hostname    = "${var.project_name}-prometheus"
  platform_id = "standard-v2"
  zone        = var.yc_zones[0]

  allow_stopping_for_update = true

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 30
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private[0].id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal.id]
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
      ssh_public_key = file(var.ssh_public_key_path)
    })
  }

  scheduling_policy {
    preemptible = true
  }
}

# ------------------------------------------------------------
# GRAFANA
# ------------------------------------------------------------
resource "yandex_compute_instance" "grafana" {
  depends_on = [time_sleep.wait_for_grafana]

  name        = "${var.project_name}-grafana"
  hostname    = "${var.project_name}-grafana"
  platform_id = "standard-v2"
  zone        = var.yc_zones[0]

  allow_stopping_for_update = true

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private[0].id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal.id]
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
      ssh_public_key = file(var.ssh_public_key_path)
    })
  }

  scheduling_policy {
    preemptible = true
  }
}

# ------------------------------------------------------------
# ELASTICSEARCH
# ------------------------------------------------------------
resource "yandex_compute_instance" "elasticsearch" {
  depends_on = [time_sleep.wait_for_elasticsearch]

  name        = "${var.project_name}-elasticsearch"
  hostname    = "${var.project_name}-elasticsearch"
  platform_id = "standard-v2"
  zone        = var.yc_zones[0]

  allow_stopping_for_update = true

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 30
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private[0].id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal.id]
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
      ssh_public_key = file(var.ssh_public_key_path)
    })
  }

  scheduling_policy {
    preemptible = true
  }
}

# ------------------------------------------------------------
# KIBANA
# ------------------------------------------------------------
resource "yandex_compute_instance" "kibana" {
  depends_on = [time_sleep.wait_for_kibana]

  name        = "${var.project_name}-kibana"
  hostname    = "${var.project_name}-kibana"
  platform_id = "standard-v2"
  zone        = var.yc_zones[0]

  allow_stopping_for_update = true

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private[0].id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal.id]
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
      ssh_public_key = file(var.ssh_public_key_path)
    })
  }

  scheduling_policy {
    preemptible = true
  }
}
EOF

# bastion.tf
cat > terraform/bastion.tf << 'EOF'
# ============================================================
# BASTION HOST (ЕДИНСТВЕННАЯ ТОЧКА ВХОДА)
# ============================================================
# Bastion выполняет 3 функции:
# 1. SSH-шлюз для доступа ко всем ВМ
# 2. Прокси для сайта (балансировка на web1/web2)
# 3. Прокси для Grafana (порт 3000) и Kibana (порт 5601)
# ============================================================

resource "yandex_compute_instance" "bastion" {
  depends_on = [
    time_sleep.wait_before_bastion,
    yandex_compute_instance.web[0],
    yandex_compute_instance.web[1],
    yandex_compute_instance.grafana,
    yandex_compute_instance.kibana,
    yandex_compute_instance.prometheus,
    yandex_compute_instance.elasticsearch
  ]

  name        = "${var.project_name}-bastion"
  hostname    = "${var.project_name}-bastion"
  platform_id = "standard-v2"
  zone        = var.yc_zones[0]

  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public[0].id
    nat                = true  # Единственная ВМ с публичным IP
    security_group_ids = [yandex_vpc_security_group.bastion.id]
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/bastion-cloud-init.yml.tpl", {
      web_private_ips   = [for inst in yandex_compute_instance.web : inst.network_interface[0].ip_address]
      grafana_private_ip = yandex_compute_instance.grafana.network_interface[0].ip_address
      kibana_private_ip  = yandex_compute_instance.kibana.network_interface[0].ip_address
      ssh_public_key     = file(var.ssh_public_key_path)
    })
  }

  scheduling_policy {
    preemptible = true
  }
}
EOF

# snapshots.tf
cat > terraform/snapshots.tf << 'EOF'
# ============================================================
# РЕЗЕРВНОЕ КОПИРОВАНИЕ (SNAPSHOTS)
# ============================================================
# Ежедневные снапшоты всех дисков ВМ
# Время жизни снапшотов - 7 дней
# ============================================================

resource "yandex_compute_snapshot_schedule" "daily" {
  name = "${var.project_name}-daily-snapshots"

  schedule_policy {
    expression = "0 0 * * *"  # Каждый день в 00:00 UTC
  }

  retention_period = "168h"  # 7 дней

  disk_ids = concat(
    # Диски веб-серверов
    [for inst in yandex_compute_instance.web : inst.boot_disk[0].disk_id],
    # Диски остальных сервисов
    [
      yandex_compute_instance.prometheus.boot_disk[0].disk_id,
      yandex_compute_instance.grafana.boot_disk[0].disk_id,
      yandex_compute_instance.elasticsearch.boot_disk[0].disk_id,
      yandex_compute_instance.kibana.boot_disk[0].disk_id,
      yandex_compute_instance.bastion.boot_disk[0].disk_id
    ]
  )
}
EOF

# timeouts.tf
cat > terraform/timeouts.tf << 'EOF'
# ============================================================
# ЗАДЕРЖКИ (TIMEOUTS)
# ============================================================
# Необходимы для упорядоченного создания ресурсов
# Избегаем ошибки rate exceeded при создании публичных IP
# ============================================================

# Задержка перед созданием Security Groups
resource "time_sleep" "wait_for_security_groups" {
  create_duration = "30s"
  depends_on = [
    yandex_vpc_network.main,
    yandex_vpc_subnet.public,
    yandex_vpc_subnet.private
  ]
}

# Задержка перед созданием Bastion
resource "time_sleep" "wait_before_bastion" {
  create_duration = "30s"
  depends_on = [
    yandex_vpc_subnet.public[0],
    yandex_vpc_security_group.bastion
  ]
}

# Небольшие задержки для остальных ВМ
resource "time_sleep" "wait_for_prometheus" {
  depends_on = [yandex_vpc_subnet.private[0]]
  create_duration = "10s"
}

resource "time_sleep" "wait_for_grafana" {
  depends_on = [yandex_vpc_subnet.private[0]]
  create_duration = "10s"
}

resource "time_sleep" "wait_for_elasticsearch" {
  depends_on = [yandex_vpc_subnet.private[0]]
  create_duration = "10s"
}

resource "time_sleep" "wait_for_kibana" {
  depends_on = [yandex_vpc_subnet.private[0]]
  create_duration = "10s"
}
EOF

# outputs.tf
cat > terraform/outputs.tf << 'EOF'
# ============================================================
# ВЫХОДНЫЕ ДАННЫЕ
# ============================================================
# IP-адреса для подключения к сервисам
# Генерация inventory.ini для Ansible
# ============================================================

output "bastion_public_ip" {
  description = "Публичный IP Bastion (единственная точка входа)"
  value       = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}

output "web_private_ips" {
  description = "Приватные IP веб-серверов"
  value       = [for inst in yandex_compute_instance.web : inst.network_interface[0].ip_address]
}

output "prometheus_private_ip" {
  description = "Приватный IP Prometheus"
  value       = yandex_compute_instance.prometheus.network_interface[0].ip_address
}

output "grafana_private_ip" {
  description = "Приватный IP Grafana"
  value       = yandex_compute_instance.grafana.network_interface[0].ip_address
}

output "elasticsearch_private_ip" {
  description = "Приватный IP Elasticsearch"
  value       = yandex_compute_instance.elasticsearch.network_interface[0].ip_address
}

output "kibana_private_ip" {
  description = "Приватный IP Kibana"
  value       = yandex_compute_instance.kibana.network_interface[0].ip_address
}

# Генерация инвентаря для Ansible
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    bastion_public_ip      = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
    web1_private_ip        = yandex_compute_instance.web[0].network_interface[0].ip_address
    web2_private_ip        = yandex_compute_instance.web[1].network_interface[0].ip_address
    prometheus_private_ip  = yandex_compute_instance.prometheus.network_interface[0].ip_address
    grafana_private_ip     = yandex_compute_instance.grafana.network_interface[0].ip_address
    elasticsearch_private_ip = yandex_compute_instance.elasticsearch.network_interface[0].ip_address
    kibana_private_ip      = yandex_compute_instance.kibana.network_interface[0].ip_address
  })
  filename = "../ansible/inventory/inventory.ini"
}
EOF

# templates/cloud-init.yml.tpl
cat > terraform/templates/cloud-init.yml.tpl << 'EOF'
#cloud-config
# ============================================================
# CLOUD-INIT ДЛЯ ВСЕХ ВМ (КРОМЕ BASTION)
# ============================================================
# 1. Создание пользователя ubuntu
# 2. Добавление SSH-ключа для доступа
# 3. Автоматическое обновление пакетов
# ============================================================

users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
      - ${ssh_public_key}

package_update: true
package_upgrade: true
EOF

# templates/bastion-cloud-init.yml.tpl
cat > terraform/templates/bastion-cloud-init.yml.tpl << 'EOF'
#cloud-config
# ============================================================
# CLOUD-INIT ДЛЯ BASTION
# ============================================================
# Bastion - единственная ВМ с публичным IP
# Выполняет роль:
# 1. SSH-шлюза
# 2. Прокси для сайта (порт 80)
# 3. Прокси для Grafana (порт 3000)
# 4. Прокси для Kibana (порт 5601)
# ============================================================

users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
      - ${ssh_public_key}

packages:
  - nginx

write_files:
  - path: /etc/nginx/sites-available/default
    content: |
      # Балансировка на веб-серверы
      upstream web_backend {
          server ${web_private_ips[0]}:80;
          server ${web_private_ips[1]}:80;
      }

      # Сайт (порт 80)
      server {
          listen 80 default_server;
          server_name _;

          access_log /var/log/nginx/access.log combined;
          error_log /var/log/nginx/error.log warn;

          location / {
              proxy_pass http://web_backend;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
      }

      # Прокси для Grafana (порт 3000)
      server {
          listen 3000;
          server_name _;

          location / {
              proxy_pass http://${grafana_private_ip}:3000;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
      }

      # Прокси для Kibana (порт 5601)
      server {
          listen 5601;
          server_name _;

          location / {
              proxy_pass http://${kibana_private_ip}:5601;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
      }

runcmd:
  - systemctl enable nginx
  - systemctl restart nginx
EOF

# templates/inventory.tpl
cat > terraform/templates/inventory.tpl << 'EOF'
# ============================================================
# INVENTORY ДЛЯ ANSIBLE
# ============================================================
# Автоматически генерируется Terraform после создания ВМ
# Использует реальные IP-адреса созданных ресурсов
# ============================================================

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[bastion]
bastion ansible_host=${bastion_public_ip}

[bastion:vars]
web1_private_ip=${web1_private_ip}
web2_private_ip=${web2_private_ip}
grafana_private_ip=${grafana_private_ip}
kibana_private_ip=${kibana_private_ip}
elasticsearch_private_ip=${elasticsearch_private_ip}
prometheus_private_ip=${prometheus_private_ip}

[web:vars]
ansible_ssh_common_args='-o ProxyJump=ubuntu@${bastion_public_ip} -o StrictHostKeyChecking=no'

[web]
web1 ansible_host=${web1_private_ip}
web2 ansible_host=${web2_private_ip}

[prometheus:vars]
ansible_ssh_common_args='-o ProxyJump=ubuntu@${bastion_public_ip} -o StrictHostKeyChecking=no'

[prometheus]
prometheus ansible_host=${prometheus_private_ip}

[grafana:vars]
ansible_ssh_common_args='-o ProxyJump=ubuntu@${bastion_public_ip} -o StrictHostKeyChecking=no'

[grafana]
grafana ansible_host=${grafana_private_ip}

[elasticsearch:vars]
ansible_ssh_common_args='-o ProxyJump=ubuntu@${bastion_public_ip} -o StrictHostKeyChecking=no'

[elasticsearch]
elasticsearch ansible_host=${elasticsearch_private_ip}

[kibana:vars]
ansible_ssh_common_args='-o ProxyJump=ubuntu@${bastion_public_ip} -o StrictHostKeyChecking=no'

[kibana]
kibana ansible_host=${kibana_private_ip}
EOF

# ------------------------------------------------------------------
# 5. ФАЙЛЫ ANSIBLE (роли)
# ------------------------------------------------------------------
echo "📄 Создание файлов Ansible..."

# ansible.cfg
cat > ansible/ansible.cfg << 'EOF'
# ============================================================
# ANSIBLE CONFIGURATION
# ============================================================

[defaults]
host_key_checking = False
inventory = inventory/inventory.ini
timeout = 60
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_cache
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o ServerAliveInterval=60
retry_files_enabled = False
stdout_callback = yaml
EOF

# Создаём файлы tasks/main.yml для всех ролей
echo "📄 Создание файлов задач для ролей Ansible..."

# Функция для создания main.yml в каждой роли
create_role_task() {
    local role=$1
    mkdir -p "ansible/roles/$role/tasks"
    cat > "ansible/roles/$role/tasks/main.yml" << 'EOF'
---
# ============================================================
# РОЛЬ: $(basename $1)
# ============================================================
# Настройка сервиса $(basename $1)
# ============================================================

- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: 3600

- name: Install $(basename $1)
  debug:
    msg: "Role $(basename $1) is being applied to {{ inventory_hostname }}"
EOF
}

# Создаём файлы для всех ролей
for role in docker nginx prometheus grafana elasticsearch kibana filebeat; do
    create_role_task "$role"
    echo "  ✅ Создана роль: $role"
done

# ------------------------------------------------------------------
# 6. СОЗДАНИЕ ПЛЕЙБУКОВ ANSIBLE
# ------------------------------------------------------------------
echo "📄 Создание плейбуков Ansible..."

# site.yml
cat > ansible/playbooks/site.yml << 'EOF'
---
# ============================================================
# ОСНОВНОЙ ПЛЕЙБУК ANSIBLE
# ============================================================
# Последовательно настраивает все сервисы:
# 1. SSH-ключ на Bastion
# 2. Docker на всех ВМ
# 3. Веб-серверы
# 4. Prometheus
# 5. Grafana
# 6. Elasticsearch
# 7. Kibana
# 8. Filebeat на веб-серверах
# ============================================================

- name: Generate SSH key on Bastion and distribute to all VMs
  hosts: bastion
  become: yes
  gather_facts: yes
  tasks:
    - name: Generate SSH key on Bastion
      user:
        name: ubuntu
        generate_ssh_key: yes
        ssh_key_bits: 4096
        ssh_key_file: .ssh/id_rsa
        ssh_key_type: rsa
      register: ssh_key_result

    - name: Copy SSH key to web1
      shell: |
        ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub -o StrictHostKeyChecking=no ubuntu@{{ web1_private_ip }} 2>/dev/null || true
      args:
        executable: /bin/bash
      ignore_errors: yes

    - name: Copy SSH key to web2
      shell: |
        ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub -o StrictHostKeyChecking=no ubuntu@{{ web2_private_ip }} 2>/dev/null || true
      args:
        executable: /bin/bash
      ignore_errors: yes

    - name: Copy SSH key to prometheus
      shell: |
        ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub -o StrictHostKeyChecking=no ubuntu@{{ prometheus_private_ip }} 2>/dev/null || true
      args:
        executable: /bin/bash
      ignore_errors: yes

    - name: Copy SSH key to grafana
      shell: |
        ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub -o StrictHostKeyChecking=no ubuntu@{{ grafana_private_ip }} 2>/dev/null || true
      args:
        executable: /bin/bash
      ignore_errors: yes

    - name: Copy SSH key to elasticsearch
      shell: |
        ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub -o StrictHostKeyChecking=no ubuntu@{{ elasticsearch_private_ip }} 2>/dev/null || true
      args:
        executable: /bin/bash
      ignore_errors: yes

    - name: Copy SSH key to kibana
      shell: |
        ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub -o StrictHostKeyChecking=no ubuntu@{{ kibana_private_ip }} 2>/dev/null || true
      args:
        executable: /bin/bash
      ignore_errors: yes

- name: Setup complete infrastructure
  hosts: all
  gather_facts: yes
  tasks:
    - name: Show inventory
      debug:
        msg: "Host: {{ inventory_hostname }} - IP: {{ ansible_default_ipv4.address }}"

- name: Install Docker on all servers
  hosts: all
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install prerequisites
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - software-properties-common
          - gnupg
          - lsb-release
        state: present

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
        state: present
        update_cache: yes

    - name: Install Docker
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-compose-plugin
        state: present

    - name: Start Docker service
      service:
        name: docker
        state: started
        enabled: yes

    - name: Add user to docker group
      user:
        name: ubuntu
        groups: docker
        append: yes

    - name: Verify Docker installation
      command: docker --version
      register: docker_version
      changed_when: false

    - name: Show Docker version
      debug:
        msg: "Docker installed on {{ inventory_hostname }}: {{ docker_version.stdout }}"

- name: Setup web servers
  hosts: web
  become: yes
  tasks:
    - name: Create nginx directories
      file:
        path: "/opt/nginx/{{ item }}"
        state: directory
        mode: '0755'
      loop:
        - html
        - logs
        - conf.d

    - name: Deploy website
      copy:
        dest: /opt/nginx/html/index.html
        content: |
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <title>Дипломный проект</title>
            <style>
              body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f0f0f0; }
              h1 { color: #333; }
              .server { color: #0066cc; font-weight: bold; }
            </style>
          </head>
          <body>
            <h1>🚀 Дипломный проект</h1>
            <p>Сервер: <span class="server">{{ ansible_hostname }}</span></p>
            <p>IP: <span class="server">{{ ansible_default_ipv4.address }}</span></p>
          </body>
          </html>

    - name: Run nginx container
      docker_container:
        name: nginx
        image: nginx:latest
        state: started
        restart_policy: always
        ports:
          - "80:80"
        volumes:
          - /opt/nginx/html:/usr/share/nginx/html:ro
          - /opt/nginx/logs:/var/log/nginx

    - name: Install Node Exporter
      get_url:
        url: "https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz"
        dest: /tmp/node_exporter.tar.gz
      register: download
      until: download is not failed
      retries: 3
      delay: 10

    - name: Extract Node Exporter
      unarchive:
        src: /tmp/node_exporter.tar.gz
        dest: /tmp/
        remote_src: yes
        creates: /tmp/node_exporter-1.7.0.linux-amd64/node_exporter

    - name: Install Node Exporter
      copy:
        src: /tmp/node_exporter-1.7.0.linux-amd64/node_exporter
        dest: /usr/local/bin/node_exporter
        mode: '0755'
        remote_src: yes

    - name: Create Node Exporter service
      copy:
        dest: /etc/systemd/system/node_exporter.service
        content: |
          [Unit]
          Description=Node Exporter
          After=network.target
          [Service]
          User=ubuntu
          ExecStart=/usr/local/bin/node_exporter
          [Install]
          WantedBy=multi-user.target

    - name: Start Node Exporter
      systemd:
        name: node_exporter
        state: started
        enabled: yes
        daemon_reload: yes

    - name: Install Nginx Log Exporter
      get_url:
        url: "https://github.com/martin-helmich/prometheus-nginxlog-exporter/releases/download/v1.9.2/prometheus-nginxlog-exporter_1.9.2_linux_amd64.deb"
        dest: /tmp/nginx-log-exporter.deb
      register: download
      until: download is not failed
      retries: 3
      delay: 10

    - name: Install DEB package
      apt:
        deb: /tmp/nginx-log-exporter.deb

    - name: Configure Nginx Log Exporter
      copy:
        dest: /etc/prometheus-nginxlog-exporter.hcl
        content: |
          listen {
            port = 4040
            address = "0.0.0.0"
          }
          namespace "nginx" {
            format = "$remote_addr - $remote_user [$time_local] \"$request\" $status $body_bytes_sent \"$http_referer\" \"$http_user_agent\" \"$http_x_forwarded_for\""
            source {
              files = ["/var/log/nginx/access.log"]
            }
          }

    - name: Start Nginx Log Exporter
      systemd:
        name: prometheus-nginxlog-exporter
        state: restarted
        enabled: yes

- name: Setup Prometheus
  hosts: prometheus
  become: yes
  tasks:
    - name: Create prometheus directory
      file:
        path: /opt/prometheus
        state: directory
        mode: '0755'

    - name: Create prometheus config
      copy:
        dest: /opt/prometheus/prometheus.yml
        content: |
          global:
            scrape_interval: 15s
            evaluation_interval: 15s

          scrape_configs:
            - job_name: 'node_exporter'
              static_configs:
                - targets:
                  - '{{ web1_private_ip }}:9100'
                  - '{{ web2_private_ip }}:9100'
                  labels:
                    service: 'web'

            - job_name: 'nginx_log_exporter'
              static_configs:
                - targets:
                  - '{{ web1_private_ip }}:4040'
                  - '{{ web2_private_ip }}:4040'
                  labels:
                    service: 'web'

    - name: Run prometheus container
      docker_container:
        name: prometheus
        image: prom/prometheus:latest
        state: started
        restart_policy: always
        ports:
          - "9090:9090"
        volumes:
          - /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml

- name: Setup Grafana
  hosts: grafana
  become: yes
  tasks:
    - name: Create grafana directory
      file:
        path: /opt/grafana
        state: directory
        owner: "472"
        group: "472"
        mode: '0755'

    - name: Run grafana container
      docker_container:
        name: grafana
        image: grafana/grafana:latest
        state: started
        restart_policy: always
        ports:
          - "3000:3000"
        volumes:
          - /opt/grafana:/var/lib/grafana
        env:
          GF_SECURITY_ADMIN_USER: "admin"
          GF_SECURITY_ADMIN_PASSWORD: "admin"

- name: Setup Elasticsearch
  hosts: elasticsearch
  become: yes
  tasks:
    - name: Create elasticsearch directory
      file:
        path: /opt/elasticsearch
        state: directory
        mode: '0755'
        owner: "1000"
        group: "1000"

    - name: Increase vm.max_map_count
      sysctl:
        name: vm.max_map_count
        value: '262144'
        state: present
        reload: yes

    - name: Run elasticsearch container
      docker_container:
        name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.17.0
        state: started
        restart_policy: always
        ports:
          - "9200:9200"
          - "9300:9300"
        env:
          discovery.type: "single-node"
          xpack.security.enabled: "false"
          ES_JAVA_OPTS: "-Xms512m -Xmx512m"
        volumes:
          - /opt/elasticsearch:/usr/share/elasticsearch/data

    - name: Wait for Elasticsearch to be ready
      uri:
        url: "http://localhost:9200"
        status_code: 200
        timeout: 10
      register: result
      until: result.status == 200
      retries: 15
      delay: 5
      ignore_errors: yes

    - name: Show Elasticsearch status
      debug:
        msg: "Elasticsearch on {{ inventory_hostname }} is {{ 'ready' if result.status == 200 else 'not ready' }}"

- name: Setup Kibana
  hosts: kibana
  become: yes
  tasks:
    - name: Run kibana container
      docker_container:
        name: kibana
        image: docker.elastic.co/kibana/kibana:8.17.0
        state: started
        restart_policy: always
        ports:
          - "5601:5601"
        env:
          ELASTICSEARCH_HOSTS: "http://{{ elasticsearch_private_ip }}:9200"

    - name: Wait for Kibana to be ready
      uri:
        url: "http://localhost:5601"
        status_code: 200
        timeout: 10
      register: result
      until: result.status == 200
      retries: 30
      delay: 10
      ignore_errors: yes

    - name: Show Kibana status
      debug:
        msg: "Kibana on {{ inventory_hostname }} is {{ 'ready' if result.status == 200 else 'not ready' }}"

- name: Setup Filebeat on web servers
  hosts: web
  become: yes
  tasks:
    - name: Create filebeat config directory
      file:
        path: /opt/filebeat
        state: directory
        mode: '0755'

    - name: Configure Filebeat for Docker
      copy:
        dest: /opt/filebeat/filebeat.yml
        content: |
          filebeat.inputs:
            - type: container
              paths:
                - /var/lib/docker/containers/*/*.log
              processors:
                - add_docker_metadata: ~

            - type: log
              enabled: true
              paths:
                - /var/log/nginx/access.log
              fields:
                log_type: nginx_access

            - type: log
              enabled: true
              paths:
                - /var/log/nginx/error.log
              fields:
                log_type: nginx_error

          output.elasticsearch:
            hosts: ["{{ elasticsearch_private_ip }}:9200"]
            index: "nginx-logs-%{+yyyy.MM.dd}"
          setup.ilm.enabled: false

    - name: Run Filebeat container
      docker_container:
        name: filebeat
        image: docker.elastic.co/beats/filebeat:7.17.20
        state: started
        restart_policy: always
        volumes:
          - /opt/filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
          - /var/log/nginx:/var/log/nginx:ro
          - /var/lib/docker/containers:/var/lib/docker/containers:ro
        user: root

    - name: Verify Filebeat container is running
      shell: docker ps -q -f name=filebeat
      register: filebeat_container
      changed_when: false
      failed_when: false

    - name: Show Filebeat container status
      debug:
        msg: "Filebeat container on {{ inventory_hostname }}: {{ 'running' if filebeat_container.stdout else 'not running' }}"
EOF

# ------------------------------------------------------------------
# 7. .gitignore
# ------------------------------------------------------------------
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars

# SSH keys
**/.ssh/
**/*.pem
**/*.key
**/*.pub

# Ansible
ansible/inventory/inventory.ini
ansible/.ansible/
/tmp/ansible_cache

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo
EOF
