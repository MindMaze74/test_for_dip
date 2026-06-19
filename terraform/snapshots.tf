# ============================================================
# РЕЗЕРВНОЕ КОПИРОВАНИЕ (SNAPSHOTS)
# ============================================================
# Ежедневные снапшоты всех дисков ВМ
# Время жизни снапшотов - 7 дней
# ============================================================

resource "yandex_compute_snapshot_schedule" "daily" {
  name = "${var.project_name}-daily-snapshots"

  schedule_policy {
    expression = "0 0 * * *" # Каждый день в 00:00 UTC
  }

  retention_period = "168h" # 7 дней

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
