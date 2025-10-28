# Руководство по оптимизации L2TP IPSec Tunnel Restore

## Общие рекомендации по оптимизации

### 1. Оптимизация производительности

#### Настройка таймаутов
```bash
# В tunnel-config.conf
PING_TIMEOUT=3          # Уменьшить с 5 до 3 секунд
L2TP_WAIT_TIME=20       # Уменьшить с 30 до 20 секунд
HEALTH_CHECK_INTERVAL=180  # Уменьшить с 300 до 180 секунд (3 минуты)
```

#### Оптимизация проверок
```bash
# Использовать более быстрые команды
ping -c 3 -W 2 "$TUNNEL_GATEWAY"  # Вместо ping -c 10 -W 5
```

### 2. Оптимизация логирования

#### Настройка уровней логирования
```bash
# Для продакшена
LOG_LEVEL="WARN"        # Только предупреждения и ошибки
ENABLE_DEBUG_OUTPUT=false

# Для разработки/отладки
LOG_LEVEL="DEBUG"       # Подробные логи
ENABLE_DEBUG_OUTPUT=true
```

#### Ротация логов
```bash
# Настройка в /etc/logrotate.d/l2tp-tunnel
/var/log/l2tp-tunnel*.log {
    daily
    missingok
    rotate 7           # Хранить только 7 дней
    compress
    delaycompress
    notifempty
    create 644 root root
    maxsize 10M        # Максимальный размер файла
}
```

### 3. Оптимизация мониторинга

#### Умный мониторинг
```bash
# Адаптивные интервалы проверки
HEALTH_CHECK_INTERVAL=300    # Нормальный режим: 5 минут
CRITICAL_CHECK_INTERVAL=60   # При проблемах: 1 минута
STABLE_CHECK_INTERVAL=600    # Стабильный режим: 10 минут
```

#### Условные проверки
```bash
# Проверять только при необходимости
if [[ $(date +%H) -ge 6 && $(date +%H) -le 22 ]]; then
    # Активные проверки только в рабочее время
    HEALTH_CHECK_INTERVAL=180
else
    # Менее частые проверки ночью
    HEALTH_CHECK_INTERVAL=600
fi
```

## Расширенные настройки

### 1. Настройка уведомлений

#### Email уведомления
```bash
# Установка mailutils
sudo apt install -y mailutils

# Настройка в tunnel-config.conf
ENABLE_NOTIFICATIONS=true
NOTIFICATION_EMAIL="admin@yourdomain.com"

# Настройка postfix (опционально)
sudo dpkg-reconfigure postfix
```

#### Webhook уведомления
```bash
# Slack webhook
NOTIFICATION_WEBHOOK="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Discord webhook
NOTIFICATION_WEBHOOK="https://discord.com/api/webhooks/YOUR/DISCORD/WEBHOOK"

# Telegram bot
NOTIFICATION_WEBHOOK="https://api.telegram.org/bot<TOKEN>/sendMessage?chat_id=<CHAT_ID>"
```

### 2. Настройка резервного копирования

#### Автоматическое резервное копирование конфигурации
```bash
#!/bin/bash
# backup-config.sh

BACKUP_DIR="/opt/l2tp-tunnel/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Копируем конфигурацию
cp /opt/l2tp-tunnel/tunnel-config.conf "$BACKUP_DIR/tunnel-config_$DATE.conf"

# Копируем правила iptables
iptables-save > "$BACKUP_DIR/iptables_$DATE.rules"

# Очищаем старые бэкапы (старше 30 дней)
find "$BACKUP_DIR" -name "*.conf" -mtime +30 -delete
find "$BACKUP_DIR" -name "*.rules" -mtime +30 -delete
```

### 3. Настройка метрик и мониторинга

#### Prometheus метрики
```bash
# Создание файла метрик
cat > /opt/l2tp-tunnel/metrics.sh << 'EOF'
#!/bin/bash

METRICS_FILE="/var/log/l2tp-tunnel-metrics.prom"

# Функция записи метрики
write_metric() {
    local name="$1"
    local value="$2"
    local labels="$3"
    echo "l2tp_tunnel_${name}{${labels}} ${value}" >> "$METRICS_FILE"
}

# Проверка состояния туннеля
if ip link show ppp0 >/dev/null 2>&1; then
    write_metric "interface_up" "1" "interface=\"ppp0\""
else
    write_metric "interface_up" "0" "interface=\"ppp0\""
fi

# Проверка связности
if ping -c 1 -W 2 172.20.179.1 >/dev/null 2>&1; then
    write_metric "connectivity_up" "1" "target=\"172.20.179.1\""
else
    write_metric "connectivity_up" "0" "target=\"172.20.179.1\""
fi

# Время последней проверки
write_metric "last_check_timestamp" "$(date +%s)" ""
EOF

chmod +x /opt/l2tp-tunnel/metrics.sh
```

### 4. Настройка безопасности

#### Ограничение доступа к логам
```bash
# Создание группы для доступа к логам
sudo groupadd l2tp-logs
sudo usermod -a -G l2tp-logs your-username

# Настройка прав доступа
sudo chown root:l2tp-logs /var/log/l2tp-tunnel*.log
sudo chmod 640 /var/log/l2tp-tunnel*.log
```

#### Настройка SELinux/AppArmor
```bash
# AppArmor профиль для скриптов
cat > /etc/apparmor.d/opt.l2tp-tunnel.bin << 'EOF'
/opt/l2tp-tunnel/*.sh {
  include <abstractions/base>
  include <abstractions/bash>
  
  /bin/bash ix,
  /usr/bin/ip ix,
  /usr/bin/ping ix,
  /usr/sbin/iptables ix,
  /usr/sbin/ipsec ix,
  /usr/sbin/xl2tpd ix,
  /usr/bin/systemctl ix,
  
  /var/log/l2tp-tunnel*.log w,
  /var/run/xl2tpd/l2tp-control w,
  /etc/iptables/rules.v4 w,
}
EOF

sudo apparmor_parser -r /etc/apparmor.d/opt.l2tp-tunnel.bin
```

## Производительность системы

### 1. Оптимизация systemd

#### Настройка systemd сервисов
```bash
# В l2tp-tunnel-monitor.service
[Service]
# Ограничение ресурсов
MemoryLimit=64M
CPUQuota=10%

# Настройки перезапуска
Restart=always
RestartSec=30
StartLimitInterval=300
StartLimitBurst=5
```

### 2. Оптимизация сети

#### Настройка TCP параметров
```bash
# В /etc/sysctl.conf
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
```

#### Настройка iptables для производительности
```bash
# Оптимизированные правила iptables
iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE -m comment --comment "L2TP tunnel NAT"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE -m comment --comment "Main interface NAT"
```

## Мониторинг и алертинг

### 1. Настройка Zabbix

#### Zabbix агент конфигурация
```bash
# В /etc/zabbix/zabbix_agentd.conf
UserParameter=l2tp.tunnel.status,/opt/l2tp-tunnel/check-tunnel-status.sh
UserParameter=l2tp.tunnel.uptime,/opt/l2tp-tunnel/check-tunnel-uptime.sh
```

#### Скрипты проверки для Zabbix
```bash
#!/bin/bash
# check-tunnel-status.sh
if ip link show ppp0 >/dev/null 2>&1 && ping -c 1 -W 2 172.20.179.1 >/dev/null 2>&1; then
    echo "1"
else
    echo "0"
fi
```

### 2. Настройка Grafana

#### Dashboard конфигурация
```json
{
  "dashboard": {
    "title": "L2TP Tunnel Monitoring",
    "panels": [
      {
        "title": "Tunnel Status",
        "type": "stat",
        "targets": [
          {
            "expr": "l2tp_tunnel_interface_up"
          }
        ]
      }
    ]
  }
}
```

## Резервное копирование и восстановление

### 1. Автоматическое резервное копирование

```bash
#!/bin/bash
# backup-tunnel-config.sh

BACKUP_DIR="/opt/l2tp-tunnel/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="tunnel-backup-$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

# Создаем архив с конфигурацией
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    /opt/l2tp-tunnel/tunnel-config.conf \
    /etc/iptables/rules.v4 \
    /etc/systemd/system/l2tp-tunnel-*.service

# Загружаем в облако (опционально)
# rclone copy "$BACKUP_DIR/$BACKUP_FILE" remote:backups/

# Очищаем старые бэкапы
find "$BACKUP_DIR" -name "tunnel-backup-*.tar.gz" -mtime +30 -delete
```

### 2. Восстановление из резервной копии

```bash
#!/bin/bash
# restore-tunnel-config.sh

BACKUP_FILE="$1"
BACKUP_DIR="/opt/l2tp-tunnel/backups"

if [[ -z "$BACKUP_FILE" ]]; then
    echo "Использование: $0 <backup-file>"
    exit 1
fi

# Восстанавливаем конфигурацию
tar -xzf "$BACKUP_DIR/$BACKUP_FILE" -C /

# Перезагружаем systemd
systemctl daemon-reload

# Перезапускаем сервисы
systemctl restart l2tp-tunnel-restore.service
systemctl restart l2tp-tunnel-monitor.service
```

## Заключение

Эти оптимизации помогут:

1. **Улучшить производительность** - быстрее обнаружение и восстановление сбоев
2. **Снизить нагрузку на систему** - оптимизированные проверки и логирование
3. **Повысить надежность** - лучший мониторинг и уведомления
4. **Упростить администрирование** - автоматическое резервное копирование и восстановление

Выберите те оптимизации, которые подходят для вашей инфраструктуры и требований.


