# L2TP IPSec Tunnel Restore

Автоматическое восстановление L2TP IPSec туннеля после перезагрузки сервера Ubuntu.

## Описание

Этот проект предоставляет комплексное решение для автоматического восстановления L2TP IPSec туннеля на сервере Ubuntu 24.04. Скрипт проверяет состояние служб, поднимает туннель, настраивает маршрутизацию и правила iptables.

## Возможности

- ✅ Автоматическая проверка и перезапуск служб `ipsec` и `xl2tpd`
- ✅ Поднятие IPSec туннеля командой `ipsec up l2tp-client`
- ✅ Запуск L2TP туннеля через control файл
- ✅ Проверка интерфейса `ppp0` и его IP адреса
- ✅ Тестирование связности пингом до шлюза
- ✅ Автоматическая настройка маршрутов до целевой сети
- ✅ Проверка и настройка правил iptables (MASQUERADE)
- ✅ Логирование всех операций
- ✅ Systemd сервисы для автозапуска
- ✅ Мониторинг состояния туннеля
- ✅ Настраиваемая конфигурация

## Структура проекта

```
PROJECT7/
├── l2tp-tunnel-restore.sh      # Основной скрипт восстановления
├── l2tp-tunnel-monitor.sh      # Скрипт мониторинга
├── tunnel-config.conf          # Конфигурационный файл
├── l2tp-tunnel-restore.service # Systemd сервис восстановления
├── l2tp-tunnel-monitor.service # Systemd сервис мониторинга
├── install.sh                  # Скрипт установки
└── README.md                   # Документация
```

## Требования

- Ubuntu 24.04 (или совместимая система)
- Права root
- Установленные пакеты:
  - `strongswan` (ipsec)
  - `xl2tpd`
  - `iptables-persistent`
  - `netfilter-persistent`

## Быстрая установка

1. **Скачайте проект:**
   ```bash
   git clone <your-repo-url>
   cd PROJECT7
   ```

2. **Запустите установку:**
   ```bash
   sudo bash install.sh
   ```

3. **Настройте конфигурацию:**
   ```bash
   sudo nano /opt/l2tp-tunnel/tunnel-config.conf
   ```

4. **Запустите сервисы:**
   ```bash
   sudo systemctl start l2tp-tunnel-restore.service
   sudo systemctl start l2tp-tunnel-monitor.service
   ```

## Ручная установка

### 1. Установка зависимостей

```bash
sudo apt update
sudo apt install -y strongswan xl2tpd iptables-persistent netfilter-persistent
```

### 2. Копирование файлов

```bash
sudo mkdir -p /opt/l2tp-tunnel
sudo cp l2tp-tunnel-restore.sh /opt/l2tp-tunnel/
sudo cp l2tp-tunnel-monitor.sh /opt/l2tp-tunnel/
sudo cp tunnel-config.conf /opt/l2tp-tunnel/
sudo chmod +x /opt/l2tp-tunnel/*.sh
```

### 3. Установка systemd сервисов

```bash
sudo cp l2tp-tunnel-restore.service /etc/systemd/system/
sudo cp l2tp-tunnel-monitor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable l2tp-tunnel-restore.service
sudo systemctl enable l2tp-tunnel-monitor.service
```

## Конфигурация

Основные параметры настраиваются в файле `/opt/l2tp-tunnel/tunnel-config.conf`:

```bash
# Основные настройки
TUNNEL_INTERFACE="ppp0"
TUNNEL_GATEWAY="172.20.179.1"
TARGET_NETWORK="192.168.179.0/24"
L2TP_CONNECTION="razbudimir"

# Настройки логирования
LOG_FILE="/var/log/l2tp-tunnel-restore.log"
LOG_LEVEL="INFO"

# Настройки повторных попыток
MAX_RETRIES=1
PING_COUNT=10
PING_TIMEOUT=5
```

## Использование

### Ручной запуск

```bash
# Запуск восстановления туннеля
sudo /opt/l2tp-tunnel/l2tp-tunnel-restore.sh

# Запуск мониторинга
sudo /opt/l2tp-tunnel/l2tp-tunnel-monitor.sh
```

### Управление сервисами

```bash
# Запуск сервисов
sudo systemctl start l2tp-tunnel-restore.service
sudo systemctl start l2tp-tunnel-monitor.service

# Остановка сервисов
sudo systemctl stop l2tp-tunnel-restore.service
sudo systemctl stop l2tp-tunnel-monitor.service

# Проверка статуса
sudo systemctl status l2tp-tunnel-restore.service
sudo systemctl status l2tp-tunnel-monitor.service

# Просмотр логов
sudo journalctl -u l2tp-tunnel-restore.service -f
sudo journalctl -u l2tp-tunnel-monitor.service -f
```

### Автозапуск при перезагрузке

Сервисы автоматически запускаются при загрузке системы благодаря systemd. Для проверки:

```bash
sudo systemctl is-enabled l2tp-tunnel-restore.service
sudo systemctl is-enabled l2tp-tunnel-monitor.service
```

## Логирование

Логи сохраняются в следующих файлах:

- `/var/log/l2tp-tunnel-restore.log` - основной лог восстановления
- `/var/log/l2tp-tunnel-monitor.log` - лог мониторинга
- `/var/log/l2tp-health-check.log` - лог проверок здоровья
- `journalctl -u l2tp-tunnel-*` - systemd логи

## Мониторинг

Скрипт мониторинга (`l2tp-tunnel-monitor.sh`) работает как отдельный сервис и:

- Проверяет состояние туннеля каждые 5 минут (настраивается)
- Автоматически восстанавливает туннель при сбоях
- Отправляет уведомления при критических сбоях
- Ведет детальные логи всех операций

## Устранение неполадок

### Проверка состояния туннеля

```bash
# Проверка интерфейса
ip link show ppp0

# Проверка IP адреса
ip addr show ppp0

# Проверка маршрутов
ip route show | grep 192.168.179

# Проверка iptables
iptables -t nat -L POSTROUTING | grep ppp0

# Тест связности
ping -c 5 172.20.179.1
```

### Просмотр логов

```bash
# Основные логи
tail -f /var/log/l2tp-tunnel-restore.log

# Логи systemd
journalctl -u l2tp-tunnel-restore.service --since "1 hour ago"

# Логи мониторинга
tail -f /var/log/l2tp-tunnel-monitor.log
```

### Перезапуск сервисов

```bash
# Перезапуск восстановления
sudo systemctl restart l2tp-tunnel-restore.service

# Перезапуск мониторинга
sudo systemctl restart l2tp-tunnel-monitor.service
```

## Безопасность

- Скрипты запускаются с правами root (необходимо для работы с сетевыми интерфейсами)
- Логи содержат чувствительную информацию - ограничьте доступ к ним
- Регулярно проверяйте логи на предмет подозрительной активности
- Используйте файрвол для ограничения доступа к серверу

## Производительность

- Минимальное потребление ресурсов
- Проверки выполняются каждые 5 минут
- Логи ротируются ежедневно
- Автоматическая очистка старых логов

## Поддержка

При возникновении проблем:

1. Проверьте логи: `tail -f /var/log/l2tp-tunnel-restore.log`
2. Проверьте статус сервисов: `systemctl status l2tp-tunnel-*`
3. Проверьте конфигурацию: `cat /opt/l2tp-tunnel/tunnel-config.conf`
4. Запустите скрипт вручную для диагностики

## Лицензия

MIT License

## Автор

PROJECT7 - Автоматизация L2TP IPSec туннелей

