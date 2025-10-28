#!/bin/bash

# L2TP IPSec Tunnel Quick Diagnostic
# Скрипт быстрой диагностики состояния туннеля
# Автор: PROJECT7
# Версия: 1.0

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.conf"
OUTPUT_FILE="/tmp/l2tp-diagnostic-$(date +%Y%m%d_%H%M%S).txt"

# Загружаем конфигурацию
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Значения по умолчанию
TUNNEL_INTERFACE="${TUNNEL_INTERFACE:-ppp0}"
TUNNEL_GATEWAY="${TUNNEL_GATEWAY:-172.20.179.1}"
TARGET_NETWORK="${TARGET_NETWORK:-192.168.179.0/24}"
L2TP_CONNECTION="${L2TP_CONNECTION:-razbudimir}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "OK")
            echo -e "${GREEN}[OK]${NC} $message"
            echo "[$timestamp] [OK] $message" >> "$OUTPUT_FILE"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message"
            echo "[$timestamp] [FAIL] $message" >> "$OUTPUT_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            echo "[$timestamp] [WARN] $message" >> "$OUTPUT_FILE"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] $message" >> "$OUTPUT_FILE"
            ;;
    esac
}

# Функция проверки служб
check_services() {
    local services=("ipsec" "xl2tpd")
    local all_ok=true
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "OK" "Служба $service активна"
        else
            log "FAIL" "Служба $service неактивна"
            all_ok=false
        fi
    done
    
    return $([ "$all_ok" = "true" ] && echo 0 || echo 1)
}

# Функция проверки интерфейса
check_interface() {
    if ip link show "$TUNNEL_INTERFACE" >/dev/null 2>&1; then
        local tunnel_ip=$(ip addr show "$TUNNEL_INTERFACE" | grep -oP 'inet \K[0-9.]+' | head -1)
        if [[ -n "$tunnel_ip" ]]; then
            log "OK" "Интерфейс $TUNNEL_INTERFACE активен с IP: $tunnel_ip"
            return 0
        else
            log "FAIL" "Интерфейс $TUNNEL_INTERFACE не имеет IP адреса"
            return 1
        fi
    else
        log "FAIL" "Интерфейс $TUNNEL_INTERFACE не найден"
        return 1
    fi
}

# Функция тестирования связности
test_connectivity() {
    if ping -c 3 -W 2 "$TUNNEL_GATEWAY" >/dev/null 2>&1; then
        log "OK" "Связность с шлюзом $TUNNEL_GATEWAY OK"
        return 0
    else
        log "FAIL" "Нет связи с шлюзом $TUNNEL_GATEWAY"
        return 1
    fi
}

# Функция проверки маршрутов
check_routes() {
    if ip route show | grep -q "$TARGET_NETWORK"; then
        log "OK" "Маршрут до $TARGET_NETWORK найден"
        return 0
    else
        log "FAIL" "Маршрут до $TARGET_NETWORK не найден"
        return 1
    fi
}

# Функция проверки iptables
check_iptables() {
    local rules_ok=true
    
    if iptables -t nat -L POSTROUTING | grep -q "MASQUERADE.*ppp0"; then
        log "OK" "MASQUERADE правило для ppp0 найдено"
    else
        log "FAIL" "MASQUERADE правило для ppp0 не найдено"
        rules_ok=false
    fi
    
    if iptables -t nat -L POSTROUTING | grep -q "MASQUERADE.*eth0"; then
        log "OK" "MASQUERADE правило для eth0 найдено"
    else
        log "WARN" "MASQUERADE правило для eth0 не найдено"
    fi
    
    return $([ "$rules_ok" = "true" ] && echo 0 || echo 1)
}

# Функция сбора системной информации
collect_system_info() {
    log "INFO" "=== Системная информация ==="
    echo "Дата и время: $(date)" >> "$OUTPUT_FILE"
    echo "Версия ядра: $(uname -r)" >> "$OUTPUT_FILE"
    echo "Загрузка системы: $(uptime)" >> "$OUTPUT_FILE"
    echo "Использование памяти:" >> "$OUTPUT_FILE"
    free -h >> "$OUTPUT_FILE"
    echo "Использование диска:" >> "$OUTPUT_FILE"
    df -h / >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# Функция сбора сетевой информации
collect_network_info() {
    log "INFO" "=== Сетевая информация ==="
    echo "Сетевые интерфейсы:" >> "$OUTPUT_FILE"
    ip addr show >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Таблица маршрутизации:" >> "$OUTPUT_FILE"
    ip route show >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Правила iptables NAT:" >> "$OUTPUT_FILE"
    iptables -t nat -L -v >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# Функция сбора информации о туннеле
collect_tunnel_info() {
    log "INFO" "=== Информация о туннеле ==="
    
    # Статус ipsec
    echo "Статус ipsec:" >> "$OUTPUT_FILE"
    ipsec status 2>/dev/null >> "$OUTPUT_FILE" || echo "ipsec status недоступен" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Статус xl2tpd
    echo "Статус xl2tpd:" >> "$OUTPUT_FILE"
    systemctl status xl2tpd --no-pager >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Информация об интерфейсе туннеля
    if ip link show "$TUNNEL_INTERFACE" >/dev/null 2>&1; then
        echo "Информация об интерфейсе $TUNNEL_INTERFACE:" >> "$OUTPUT_FILE"
        ip addr show "$TUNNEL_INTERFACE" >> "$OUTPUT_FILE"
        ip -s link show "$TUNNEL_INTERFACE" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
}

# Функция сбора логов
collect_logs() {
    log "INFO" "=== Сбор логов ==="
    
    # Основные логи
    if [[ -f "/var/log/l2tp-tunnel-restore.log" ]]; then
        echo "Последние 50 строк лога восстановления:" >> "$OUTPUT_FILE"
        tail -50 /var/log/l2tp-tunnel-restore.log >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
    
    if [[ -f "/var/log/l2tp-tunnel-monitor.log" ]]; then
        echo "Последние 50 строк лога мониторинга:" >> "$OUTPUT_FILE"
        tail -50 /var/log/l2tp-tunnel-monitor.log >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
    
    # Systemd логи
    echo "Systemd логи восстановления:" >> "$OUTPUT_FILE"
    journalctl -u l2tp-tunnel-restore.service --no-pager -l | tail -20 >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "Systemd логи мониторинга:" >> "$OUTPUT_FILE"
    journalctl -u l2tp-tunnel-monitor.service --no-pager -l | tail -20 >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# Функция генерации отчета
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="/tmp/l2tp-diagnostic-report-$(date +%Y%m%d_%H%M%S).txt"
    
    log "INFO" "Генерируем отчет: $report_file"
    
    cat > "$report_file" << EOF
L2TP IPSec Tunnel Diagnostic Report
==================================
Дата: $timestamp
Сервер: $(hostname)
Пользователь: $(whoami)

РЕЗУЛЬТАТЫ ДИАГНОСТИКИ:
======================

EOF
    
    # Копируем результаты диагностики
    cat "$OUTPUT_FILE" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "РЕКОМЕНДАЦИИ:" >> "$report_file"
    echo "=============" >> "$report_file"
    
    # Анализируем результаты и даем рекомендации
    if grep -q "\[FAIL\]" "$OUTPUT_FILE"; then
        echo "- Обнаружены критические проблемы" >> "$report_file"
        echo "- Рекомендуется запустить восстановление туннеля" >> "$report_file"
        echo "- Проверьте конфигурацию в /opt/l2tp-tunnel/tunnel-config.conf" >> "$report_file"
    else
        echo "- Все проверки пройдены успешно" >> "$report_file"
        echo "- Туннель работает корректно" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "Для получения дополнительной информации используйте:" >> "$report_file"
    echo "- /opt/l2tp-tunnel/l2tp-tunnel-status.sh (интерактивная проверка)" >> "$report_file"
    echo "- /opt/l2tp-tunnel/l2tp-tunnel-restore.sh (восстановление туннеля)" >> "$report_file"
    
    log "INFO" "Отчет сохранен: $report_file"
    echo "$report_file"
}

# Основная функция
main() {
    echo -e "${BLUE}L2TP IPSec Tunnel Quick Diagnostic${NC}"
    echo -e "${BLUE}===================================${NC}"
    echo
    
    local overall_status=0
    local failed_checks=0
    
    # Собираем системную информацию
    collect_system_info
    
    # Проверяем службы
    log "INFO" "Проверка служб..."
    if ! check_services; then
        overall_status=1
        failed_checks=$((failed_checks + 1))
    fi
    
    # Проверяем интерфейс
    log "INFO" "Проверка интерфейса..."
    if ! check_interface; then
        overall_status=1
        failed_checks=$((failed_checks + 1))
    fi
    
    # Тестируем связность
    log "INFO" "Тест связности..."
    if ! test_connectivity; then
        overall_status=1
        failed_checks=$((failed_checks + 1))
    fi
    
    # Проверяем маршруты
    log "INFO" "Проверка маршрутов..."
    if ! check_routes; then
        overall_status=1
        failed_checks=$((failed_checks + 1))
    fi
    
    # Проверяем iptables
    log "INFO" "Проверка iptables..."
    if ! check_iptables; then
        overall_status=1
        failed_checks=$((failed_checks + 1))
    fi
    
    # Собираем дополнительную информацию
    collect_network_info
    collect_tunnel_info
    collect_logs
    
    # Генерируем отчет
    local report_file=$(generate_report)
    
    # Итоговый результат
    echo
    if [[ $overall_status -eq 0 ]]; then
        log "OK" "Диагностика завершена - все проверки пройдены успешно!"
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC} ${WHITE}СТАТУС: ТУННЕЛЬ РАБОТАЕТ КОРРЕКТНО${NC} ${GREEN}                        ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    else
        log "FAIL" "Диагностика завершена - обнаружено $failed_checks проблем"
        echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${NC} ${WHITE}СТАТУС: ОБНАРУЖЕНЫ ПРОБЛЕМЫ ($failed_checks)${NC} ${RED}                    ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    fi
    
    echo
    log "INFO" "Детальный отчет сохранен: $report_file"
    log "INFO" "Лог диагностики: $OUTPUT_FILE"
    
    # Показываем краткую сводку
    echo
    echo -e "${BLUE}Краткая сводка:${NC}"
    echo "✓ Успешных проверок: $((5 - failed_checks))"
    echo "✗ Неудачных проверок: $failed_checks"
    echo "📄 Отчет: $report_file"
    
    exit $overall_status
}

# Обработка аргументов командной строки
case "${1:-}" in
    --help|-h)
        echo "Использование: $0 [опции]"
        echo
        echo "Опции:"
        echo "  --help, -h    Показать эту справку"
        echo "  --report, -r  Только генерация отчета (без вывода)"
        echo
        echo "Без опций запускается полная диагностика с выводом"
        exit 0
        ;;
    --report|-r)
        # Тихий режим - только генерация отчета
        exec > /dev/null 2>&1
        main
        ;;
    *)
        main
        ;;
esac
