#!/bin/bash

# L2TP Tunnel Test Script
# Тестирование исправлений для проблем автозапуска
# Автор: PROJECT7

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Тестирование исправлений L2TP туннеля ===${NC}"
echo

# Проверка исправлений
echo -e "${BLUE}1. Проверка исправлений:${NC}"

# Проверяем синтаксис quick-check.sh
echo -e "${YELLOW}Проверяем синтаксис quick-check.sh...${NC}"
if bash -n /opt/l2tp-tunnel/quick-check.sh; then
    echo -e "${GREEN}✓ Синтаксис quick-check.sh исправлен${NC}"
else
    echo -e "${RED}✗ Ошибка синтаксиса в quick-check.sh${NC}"
fi

# Проверяем синтаксис основного скрипта
echo -e "${YELLOW}Проверяем синтаксис l2tp-tunnel-restore.sh...${NC}"
if bash -n /opt/l2tp-tunnel/l2tp-tunnel-restore.sh; then
    echo -e "${GREEN}✓ Синтаксис l2tp-tunnel-restore.sh корректен${NC}"
else
    echo -e "${RED}✗ Ошибка синтаксиса в l2tp-tunnel-restore.sh${NC}"
fi

echo

# Тестирование быстрой проверки
echo -e "${BLUE}2. Тестирование быстрой проверки:${NC}"
echo -e "${YELLOW}Запускаем quick-check.sh...${NC}"
if /opt/l2tp-tunnel/quick-check.sh; then
    echo -e "${GREEN}✓ Быстрая проверка работает${NC}"
else
    echo -e "${RED}✗ Ошибка в быстрой проверке${NC}"
fi

echo

# Проверка конфигурации
echo -e "${BLUE}3. Проверка конфигурации:${NC}"
if [[ -f /opt/l2tp-tunnel/tunnel-config.conf ]]; then
    echo -e "${GREEN}✓ Конфигурационный файл существует${NC}"
    
    # Проверяем новые параметры
    if grep -q "L2TP_INTERFACE_WAIT_TIME=60" /opt/l2tp-tunnel/tunnel-config.conf; then
        echo -e "${GREEN}✓ Новый параметр L2TP_INTERFACE_WAIT_TIME найден${NC}"
    else
        echo -e "${YELLOW}⚠ Параметр L2TP_INTERFACE_WAIT_TIME не найден${NC}"
    fi
    
    if grep -q "IPSEC_STABILIZATION_DELAY=10" /opt/l2tp-tunnel/tunnel-config.conf; then
        echo -e "${GREEN}✓ Новый параметр IPSEC_STABILIZATION_DELAY найден${NC}"
    else
        echo -e "${YELLOW}⚠ Параметр IPSEC_STABILIZATION_DELAY не найден${NC}"
    fi
else
    echo -e "${RED}✗ Конфигурационный файл не найден${NC}"
fi

echo

# Тестирование сервиса
echo -e "${BLUE}4. Тестирование сервиса:${NC}"
echo -e "${YELLOW}Перезапускаем сервис для тестирования...${NC}"

# Останавливаем сервис
systemctl stop l2tp-tunnel-restore.service
sleep 2

# Запускаем сервис
systemctl start l2tp-tunnel-restore.service

# Ждем завершения
sleep 5

# Проверяем статус
if systemctl is-active --quiet l2tp-tunnel-restore.service; then
    echo -e "${GREEN}✓ Сервис успешно запущен${NC}"
else
    echo -e "${RED}✗ Сервис не запустился${NC}"
    echo -e "${YELLOW}Логи сервиса:${NC}"
    journalctl -u l2tp-tunnel-restore.service --no-pager -l --since "2 minutes ago" | tail -20
fi

echo

# Проверка интерфейса
echo -e "${BLUE}5. Проверка интерфейса ppp0:${NC}"
if ip link show ppp0 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Интерфейс ppp0 существует${NC}"
    ip addr show ppp0 | grep "inet " || echo -e "${YELLOW}⚠ ppp0 не имеет IP адреса${NC}"
else
    echo -e "${RED}✗ Интерфейс ppp0 не найден${NC}"
fi

echo

# Итоговый результат
echo -e "${BLUE}6. Итоговый результат:${NC}"
if systemctl is-active --quiet l2tp-tunnel-restore.service && ip link show ppp0 >/dev/null 2>&1; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC} ${YELLOW}ТЕСТИРОВАНИЕ ПРОШЛО УСПЕШНО${NC} ${GREEN}                                    ║${NC}"
    echo -e "${GREEN}║${NC} ${YELLOW}Исправления работают корректно${NC} ${GREEN}                                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC} ${YELLOW}ТЕСТИРОВАНИЕ НЕ ПРОШЛО${NC} ${RED}                                            ║${NC}"
    echo -e "${RED}║${NC} ${YELLOW}Требуется дополнительная диагностика${NC} ${RED}                              ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
fi

echo
echo -e "${BLUE}Для детальной диагностики запустите:${NC}"
echo "   sudo /opt/l2tp-tunnel/l2tp-tunnel-debug.sh"
