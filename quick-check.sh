#!/bin/bash

# Quick L2TP Tunnel Autostart Check
# Быстрая проверка проблем автозапуска
# Автор: PROJECT7

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Быстрая проверка автозапуска L2TP туннеля ===${NC}"
echo

# Проверка статуса сервисов
echo -e "${BLUE}1. Статус сервисов:${NC}"
services=("l2tp-tunnel-restore" "l2tp-tunnel-monitor" "ipsec" "xl2tpd")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service.service"; then
        echo -e "${GREEN}✓ $service.service - активен${NC}"
    else
        echo -e "${RED}✗ $service.service - неактивен${NC}"
    fi
    
    if systemctl is-enabled --quiet "$service.service"; then
        echo -e "${GREEN}✓ $service.service - включен для автозапуска${NC}"
    else
        echo -e "${RED}✗ $service.service - НЕ включен для автозапуска${NC}"
    fi
done
echo

# Проверка файлов
echo -e "${BLUE}2. Проверка файлов:${NC}"
files=(
    "/etc/systemd/system/l2tp-tunnel-restore.service"
    "/opt/l2tp-tunnel/l2tp-tunnel-restore.sh"
    "/opt/l2tp-tunnel/tunnel-config.conf"
)

for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ $file - существует${NC}"
        if [[ "$file" == *.sh" && -x "$file" ]]; then
            echo -e "${GREEN}✓ $file - исполняемый${NC}"
        elif [[ "$file" == *.sh" ]]; then
            echo -e "${RED}✗ $file - НЕ исполняемый${NC}"
        fi
    else
        echo -e "${RED}✗ $file - НЕ существует${NC}"
    fi
done
echo

# Проверка логов
echo -e "${BLUE}3. Последние ошибки в логах:${NC}"
echo "Логи systemd (последние 10 строк):"
journalctl -u l2tp-tunnel-restore.service --no-pager -l --since "1 hour ago" | tail -10
echo

# Проверка времени загрузки
echo -e "${BLUE}4. Время загрузки системы:${NC}"
uptime
echo "Время загрузки:"
systemd-analyze | head -3
echo

# Проверка сетевых интерфейсов
echo -e "${BLUE}5. Сетевые интерфейсы:${NC}"
if ip link show ppp0 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Интерфейс ppp0 существует${NC}"
    ip addr show ppp0 | grep "inet " || echo -e "${YELLOW}⚠ ppp0 не имеет IP адреса${NC}"
else
    echo -e "${RED}✗ Интерфейс ppp0 не найден${NC}"
fi
echo

# Проверка доступности сервера
echo -e "${BLUE}6. Проверка доступности L2TP сервера:${NC}"
if ping -c 3 -W 2 main.razbudimir.com >/dev/null 2>&1; then
    echo -e "${GREEN}✓ main.razbudimir.com доступен${NC}"
else
    echo -e "${RED}✗ main.razbudimir.com недоступен${NC}"
fi

if ping -c 3 -W 2 78.107.255.229 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 78.107.255.229 доступен${NC}"
else
    echo -e "${RED}✗ 78.107.255.229 недоступен${NC}"
fi
echo

# Рекомендации
echo -e "${BLUE}7. Рекомендации:${NC}"
if ! systemctl is-active --quiet l2tp-tunnel-restore.service; then
    echo -e "${YELLOW}⚠ Сервис неактивен. Попробуйте:${NC}"
    echo "   sudo systemctl start l2tp-tunnel-restore.service"
    echo "   sudo systemctl status l2tp-tunnel-restore.service"
fi

if ! systemctl is-enabled --quiet l2tp-tunnel-restore.service; then
    echo -e "${YELLOW}⚠ Сервис не включен для автозапуска. Выполните:${NC}"
    echo "   sudo systemctl enable l2tp-tunnel-restore.service"
fi

echo
echo -e "${BLUE}Для детальной диагностики запустите:${NC}"
echo "   sudo /opt/l2tp-tunnel/l2tp-tunnel-debug.sh"
