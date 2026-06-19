# 🚀 Дипломный проект: Отказоустойчивая инфраструктура в Yandex Cloud

## 📋 Описание

Инфраструктура для веб-сайта с мониторингом (Prometheus/Grafana), сбором логов (Elasticsearch/Kibana) и резервным копированием (snapshots). Реализована с использованием Terraform и Ansible.

## 🏗️ Архитектура

- **Bastion** — единственная ВМ с публичным IP, выполняет роль:
  - SSH-шлюза
  - Прокси для сайта (порт 80)
  - Прокси для Grafana (порт 3000)
  - Прокси для Kibana (порт 5601)
- **Web-серверы** (2 шт) — в приватных подсетях, балансировка через Bastion
- **Prometheus** — сбор метрик
- **Grafana** — визуализация (admin/admin)
- **Elasticsearch** — хранение логов
- **Kibana** — просмотр логов
- **Snapshots** — ежедневное резервное копирование дисков (7 дней)

## 📁 Структура
diplom_test/
├── terraform/ # IaC
│ ├── *.tf # Конфигурация ресурсов
│ └── templates/ # Шаблоны cloud-init
├── ansible/ # Управление конфигурацией
│ ├── playbooks/ # Плейбуки
│ └── roles/ # Роли
└── docs/ # Документация


## 🚀 Развёртывание

1. **Создайте сервисный аккаунт и ключ**:
   ```bash
   yc iam service-account create --name diplom-sa
   yc iam key create --service-account-name diplom-sa --output ~/diplom-sa-key.json

cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Заполните terraform.tfvars

cd terraform
terraform init
terraform apply -parallelism=1

cd ../ansible
ansible-playbook -i inventory/inventory.ini playbooks/site.yml


Доступ к сервисам
Сервис	URL
Сайт	http://<bastion_ip>:80
Grafana	http://<bastion_ip>:3000 (admin/admin)
Kibana	http://<bastion_ip>:5601
