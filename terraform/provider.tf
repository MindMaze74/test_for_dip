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
  service_account_key_file = "/home/user/diplom-sa-key.json"
  cloud_id                 = var.yc_cloud_id
  folder_id                = var.yc_folder_id
  zone                     = var.yc_zones[0]
}

provider "time" {}
provider "local" {}