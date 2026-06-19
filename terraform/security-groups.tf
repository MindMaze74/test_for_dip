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
