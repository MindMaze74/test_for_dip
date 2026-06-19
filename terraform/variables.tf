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
