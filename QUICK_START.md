# Быстрый старт - L2TP IPSec Tunnel Restore

## 🚀 Установка за 5 минут

### 1. Подготовка системы

```bash
# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Устанавливаем зависимости
sudo apt install -y strongswan xl2tpd iptables-persistent netfilter-persistent
```

### 2. Установка скрипта

```bash
# Клонируем проект (или скачиваем)
git clone <your-repo-url>
cd PROJECT7

# Запускаем установку
sudo bash install.sh
```

### 3. Настройка конфигурации

```bash
# Редактируем конфигурацию
sudo nano /opt/l2tp-tunnel/tunnel-config.conf
```

**Основные параметры для настройки:**
```bash
TUNNEL_GATEWAY="172.20.179.1"        # IP шлюза туннеля
TARGET_NETWORK="192.168.179.0/24"    # Целевая сеть
L2TP_CONNECTION="razbudimir"          # Имя подключения
```

### 4. Запуск

```bash
# Запускаем сервисы
sudo systemctl start l2tp-tunnel-restore.service
sudo systemctl start l2tp-tunnel-monitor.service

# Проверяем статус
sudo systemctl status l2tp-tunnel-restore.service
```

## ✅ Проверка работы

### Проверка туннеля
```bash
# Проверяем интерфейс
ip link show ppp0

# Проверяем IP адрес
ip addr show ppp0

# Тестируем связность
ping -c 5 172.20.179.1
```

### Проверка маршрутов
```bash
# Проверяем маршрут до целевой сети
ip route show | grep 192.168.179

# Проверяем iptables
iptables -t nat -L POSTROUTING | grep ppp0
```

### Проверка логов
```bash
# Основные логи
tail -f /var/log/l2tp-tunnel-restore.log

# Логи systemd
journalctl -u l2tp-tunnel-restore.service -f
```

## 🔧 Основные команды

### Управление сервисами
```bash
# Запуск
sudo systemctl start l2tp-tunnel-restore.service
sudo systemctl start l2tp-tunnel-monitor.service

# Остановка
sudo systemctl stop l2tp-tunnel-restore.service
sudo systemctl stop l2tp-tunnel-monitor.service

# Перезапуск
sudo systemctl restart l2tp-tunnel-restore.service
sudo systemctl restart l2tp-tunnel-monitor.service

# Статус
sudo systemctl status l2tp-tunnel-restore.service
sudo systemctl status l2tp-tunnel-monitor.service
```

### Ручной запуск
```bash
# Запуск восстановления туннеля
sudo /opt/l2tp-tunnel/l2tp-tunnel-restore.sh

# Интерактивная проверка состояния
sudo /opt/l2tp-tunnel/l2tp-tunnel-status.sh

# Быстрая диагностика
sudo /opt/l2tp-tunnel/l2tp-tunnel-diagnostic.sh

# Запуск мониторинга
sudo /opt/l2tp-tunnel/l2tp-tunnel-monitor.sh
```

## 🔍 Новые возможности диагностики

### Интерактивная проверка состояния
```bash
# Запуск интерактивного меню
sudo /opt/l2tp-tunnel/l2tp-tunnel-status.sh

# Быстрая диагностика
sudo /opt/l2tp-tunnel/l2tp-tunnel-status.sh --quick

# Проверка служб
sudo /opt/l2tp-tunnel/l2tp-tunnel-status.sh --services

# Проверка интерфейса
sudo /opt/l2tp-tunnel/l2tp-tunnel-status.sh --interface
```

### Автоматическая диагностика
```bash
# Полная диагностика с отчетом
sudo /opt/l2tp-tunnel/l2tp-tunnel-diagnostic.sh

# Тихий режим (только отчет)
sudo /opt/l2tp-tunnel/l2tp-tunnel-diagnostic.sh --report
```

## 🚨 Устранение неполадок

### Проблема: Туннель не поднимается
```bash
# Проверяем службы
sudo systemctl status ipsec
sudo systemctl status xl2tpd

# Перезапускаем службы
sudo systemctl restart ipsec
sudo systemctl restart xl2tpd

# Запускаем туннель вручную
sudo /opt/l2tp-tunnel/l2tp-tunnel-restore.sh
```

### Проблема: Нет связи с шлюзом
```bash
# Проверяем интерфейс
ip link show ppp0

# Проверяем IP адрес
ip addr show ppp0

# Проверяем маршруты
ip route show
```

### Проблема: Не работают маршруты
```bash
# Добавляем маршрут вручную
sudo ip route add 192.168.179.0/24 via 172.20.179.1 dev ppp0

# Проверяем iptables
sudo iptables -t nat -L POSTROUTING
```

## 📊 Мониторинг

### Просмотр логов в реальном времени
```bash
# Основные логи
tail -f /var/log/l2tp-tunnel-restore.log

# Логи мониторинга
tail -f /var/log/l2tp-tunnel-monitor.log

# Systemd логи
journalctl -u l2tp-tunnel-restore.service -f
journalctl -u l2tp-tunnel-monitor.service -f
```

### Проверка состояния
```bash
# Статус всех сервисов
sudo systemctl status l2tp-tunnel-*

# Проверка туннеля
sudo /opt/l2tp-tunnel/l2tp-tunnel-restore.sh
```

## 🔄 Автозапуск

Сервисы автоматически запускаются при загрузке системы:

```bash
# Проверяем автозапуск
sudo systemctl is-enabled l2tp-tunnel-restore.service
sudo systemctl is-enabled l2tp-tunnel-monitor.service

# Включаем автозапуск (если не включен)
sudo systemctl enable l2tp-tunnel-restore.service
sudo systemctl enable l2tp-tunnel-monitor.service
```

## 🗑️ Удаление

```bash
# Запускаем удаление
sudo bash uninstall.sh

# Или вручную
sudo systemctl stop l2tp-tunnel-*
sudo systemctl disable l2tp-tunnel-*
sudo rm -rf /opt/l2tp-tunnel
sudo rm -f /etc/systemd/system/l2tp-tunnel-*.service
sudo systemctl daemon-reload
```

## 📝 Полезные файлы

- **Конфигурация:** `/opt/l2tp-tunnel/tunnel-config.conf`
- **Основной скрипт:** `/opt/l2tp-tunnel/l2tp-tunnel-restore.sh`
- **Скрипт мониторинга:** `/opt/l2tp-tunnel/l2tp-tunnel-monitor.sh`
- **Интерактивная проверка:** `/opt/l2tp-tunnel/l2tp-tunnel-status.sh`
- **Быстрая диагностика:** `/opt/l2tp-tunnel/l2tp-tunnel-diagnostic.sh`
- **Логи:** `/var/log/l2tp-tunnel*.log`
- **Systemd сервисы:** `/etc/systemd/system/l2tp-tunnel-*.service`

## 🆘 Поддержка

При возникновении проблем:

1. **Проверьте логи:** `tail -f /var/log/l2tp-tunnel-restore.log`
2. **Проверьте статус:** `systemctl status l2tp-tunnel-*`
3. **Запустите вручную:** `sudo /opt/l2tp-tunnel/l2tp-tunnel-restore.sh`
4. **Проверьте конфигурацию:** `cat /opt/l2tp-tunnel/tunnel-config.conf`

---

**Готово!** Ваш L2TP IPSec туннель теперь будет автоматически восстанавливаться после перезагрузки сервера. 🎉


