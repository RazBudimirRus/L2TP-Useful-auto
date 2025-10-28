# Диагностика проблем автозапуска L2TP туннеля

## 🚨 Быстрая диагностика

Если туннель не поднимается после перезагрузки, выполните быструю проверку:

```bash
# Быстрая проверка основных проблем
sudo /opt/l2tp-tunnel/quick-check.sh
```

## 🔍 Детальная диагностика

Для полного анализа проблем запустите:

```bash
# Полная диагностика с отчетом
sudo /opt/lmp-tunnel/l2tp-tunnel-debug.sh
```

## 📋 Частые проблемы и решения

### 1. Сервис не включен для автозапуска

**Проблема:** Сервис не запускается автоматически после перезагрузки

**Решение:**
```bash
sudo systemctl enable l2tp-tunnel-restore.service
sudo systemctl enable l2tp-tunnel-monitor.service
```

### 2. Сервис неактивен

**Проблема:** Сервис остановлен или не запустился

**Решение:**
```bash
sudo systemctl start l2tp-tunnel-restore.service
sudo systemctl start l2tp-tunnel-monitor.service
```

### 3. Скрипты не исполняемые

**Проблема:** Отсутствуют права на выполнение

**Решение:**
```bash
sudo chmod +x /opt/l2tp-tunnel/*.sh
```

### 4. L2TP сервер недоступен

**Проблема:** Сервер main.razbudimir.com или 78.107.255.229 недоступен

**Проверка:**
```bash
ping -c 5 main.razbudimir.com
ping -c 5 78.107.255.229
```

**Решение:** Проверить сетевое подключение и доступность сервера

### 5. Зависимые сервисы не запущены

**Проблема:** ipsec или xl2tpd не запущены

**Решение:**
```bash
sudo systemctl start ipsec
sudo systemctl start xl2tpd
sudo systemctl enable ipsec
sudo systemctl enable xl2tpd
```

### 6. Проблемы с конфигурацией

**Проблема:** Неправильная конфигурация сервиса

**Проверка:**
```bash
sudo systemctl status l2tp-tunnel-restore.service
journalctl -u l2tp-tunnel-restore.service --no-pager -l
```

**Решение:** Переустановить сервисы
```bash
sudo bash /opt/l2tp-tunnel/install.sh
```

## 🔧 Команды для диагностики

### Проверка статуса сервисов
```bash
sudo systemctl status l2tp-tunnel-restore.service
sudo systemctl status l2tp-tunnel-monitor.service
sudo systemctl status ipsec.service
sudo systemctl status xl2tpd.service
```

### Проверка логов
```bash
# Логи systemd
sudo journalctl -u l2tp-tunnel-restore.service --no-pager -l --since "1 hour ago"

# Логи приложения
sudo tail -50 /var/log/l2tp-tunnel-restore.log
sudo tail -50 /var/log/l2tp-tunnel-monitor.log
```

### Проверка файлов
```bash
# Проверка существования файлов
ls -la /opt/l2tp-tunnel/
ls -la /etc/systemd/system/l2tp-tunnel-*.service

# Проверка прав
ls -la /opt/l2tp-tunnel/*.sh
```

### Проверка конфигурации
```bash
# Конфигурация сервиса
cat /etc/systemd/system/l2tp-tunnel-restore.service

# Конфигурация туннеля
cat /opt/l2tp-tunnel/tunnel-config.conf
```

## 🚀 Тестирование автозапуска

### Ручной тест
```bash
# Остановить сервис
sudo systemctl stop l2tp-tunnel-restore.service

# Запустить сервис
sudo systemctl start l2tp-tunnel-restore.service

# Проверить статус
sudo systemctl status l2tp-tunnel-restore.service
```

### Тест через скрипт диагностики
```bash
sudo /opt/l2tp-tunnel/l2tp-tunnel-debug.sh
# Выберите опцию тестирования автозапуска
```

## 📊 Анализ логов

### Ключевые моменты в логах:

1. **Успешный запуск:**
   - "L2TP сервер доступен"
   - "Все службы активны"
   - "Туннель успешно восстановлен"

2. **Проблемы:**
   - "L2TP сервер недоступен"
   - "Служба неактивна"
   - "Интерфейс ppp0 не найден"

### Время запуска:
- Сервис должен запуститься через 15 секунд после загрузки системы
- При сбое - повторные попытки через 30 секунд
- Максимум 3 попытки

## 🆘 Если ничего не помогает

1. **Полная переустановка:**
   ```bash
   sudo bash /opt/l2tp-tunnel/uninstall.sh
   sudo bash /opt/l2tp-tunnel/install.sh
   ```

2. **Проверка системных требований:**
   ```bash
   # Проверка версии Ubuntu
   lsb_release -a
   
   # Проверка установленных пакетов
   dpkg -l | grep -E "(strongswan|xl2tpd|iptables)"
   ```

3. **Обращение за помощью:**
   - Сохраните отчет диагностики
   - Приложите логи systemd
   - Укажите версию системы и время проблемы

---

**Помните:** Всегда проверяйте логи перед обращением за помощью!
