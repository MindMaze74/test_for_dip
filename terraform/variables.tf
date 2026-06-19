variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "yc_zones" {
  description = "Yandex Cloud availability zones"
  type        = list(string)
  default     = ["ru-central1-a", "ru-central1-b"]
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "diplom-project"
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH ключу"
  type        = string
  default     = "~/.ssh/diplom.pub"
}

variable "ssh_private_key_path" {
  description = "Путь к приватному SSH ключу"
  type        = string
  default     = "~/.ssh/diplom"
}

variable "default_username" {
  description = "Default username for VMs"
  type        = string
  default     = "ubuntu"
}