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
