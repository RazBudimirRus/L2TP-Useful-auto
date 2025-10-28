#!/bin/bash

# L2TP Tunnel Autostart Debug Script
# Диагностика проблем автозапуска туннеля после перезагрузки
# Автор: PROJECT7
# Версия: 1.0

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/l2tp-tunnel-debug.log"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            echo "[$timestamp] [WARN] $message" >> "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $message"
            echo "[$timestamp] [DEBUG] $message" >> "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
            ;;
    esac
}

# Функция отображения заголовка
show_header() {
    clear
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}L2TP Tunnel Autostart Debug Tool${NC} ${WHITE}                        ║${NC}"
    echo -e "${WHITE}║${NC} ${PURPLE}Диагностика проблем автозапуска после перезагрузки${NC} ${WHITE}        ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Функция проверки статуса сервисов
check_service_status() {
    log "INFO" "=== Проверка статуса сервисов ==="
    
    local services=("l2tp-tunnel-restore.service" "l2tp-tunnel-monitor.service" "ipsec.service" "xl2tpd.service")
    
    for service in "${services[@]}"; do
        echo -e "${BLUE}Статус сервиса: $service${NC}"
        if systemctl is-active --quiet "$service"; then
            log "SUCCESS" "✓ Сервис $service активен"
        else
            log "ERROR" "✗ Сервис $service неактивен"
        fi
        
        if systemctl is-enabled --quiet "$service"; then
            log "SUCCESS" "✓ Сервис $service включен для автозапуска"
        else
            log "ERROR" "✗ Сервис $service НЕ включен для автозапуска"
        fi
        
        echo "Детальный статус:"
        systemctl status "$service" --no-pager -l | head -15
        echo
    done
}

# Функция проверки логов systemd
check_systemd_logs() {
    log "INFO" "=== Проверка логов systemd ==="
    
    echo -e "${BLUE}Логи сервиса l2tp-tunnel-restore.service:${NC}"
    journalctl -u l2tp-tunnel-restore.service --no-pager -l --since "1 hour ago" | tail -20
    echo
    
    echo -e "${BLUE}Логи сервиса l2tp-tunnel-monitor.service:${NC}"
    journalctl -u l2tp-tunnel-monitor.service --no-pager -l --since "1 hour ago" | tail -20
    echo
    
    echo -e "${BLUE}Логи сервиса ipsec.service:${NC}"
    journalctl -u ipsec.service --no-pager -l --since "1 hour ago" | tail -20
    echo
    
    echo -e "${BLUE}Логи сервиса xl2tpd.service:${NC}"
    journalctl -u xl2tpd.service --no-pager -l --since "1 hour ago" | tail -20
    echo
}

# Функция проверки файлов сервисов
check_service_files() {
    log "INFO" "=== Проверка файлов сервисов ==="
    
    local service_files=(
        "/etc/systemd/system/l2tp-tunnel-restore.service"
        "/etc/systemd/system/l2tp-tunnel-monitor.service"
        "/opt/l2tp-tunnel/l2tp-tunnel-restore.sh"
        "/opt/l2tp-tunnel/l2tp-tunnel-monitor.sh"
        "/opt/l2tp-tunnel/tunnel-config.conf"
    )
    
    for file in "${service_files[@]}"; do
        if [[ -f "$file" ]]; then
            log "SUCCESS" "✓ Файл $file существует"
            if [[ -r "$file" ]]; then
                log "SUCCESS" "✓ Файл $file читаемый"
            else
                log "ERROR" "✗ Файл $file не читаемый"
            fi
            
            if [[ "$file" == *.sh ]]; then
                if [[ -x "$file" ]]; then
                    log "SUCCESS" "✓ Скрипт $file исполняемый"
                else
                    log "ERROR" "✗ Скрипт $file НЕ исполняемый"
                fi
            fi
        else
            log "ERROR" "✗ Файл $file НЕ существует"
        fi
        echo
    done
}

# Функция проверки конфигурации сервисов
check_service_configuration() {
    log "INFO" "=== Проверка конфигурации сервисов ==="
    
    echo -e "${BLUE}Конфигурация l2tp-tunnel-restore.service:${NC}"
    cat /etc/systemd/system/l2tp-tunnel-restore.service 2>/dev/null || echo "Файл не найден"
    echo
    
    echo -e "${BLUE}Конфигурация l2tp-tunnel-monitor.service:${NC}"
    cat /etc/systemd/system/l2tp-tunnel-monitor.service 2>/dev/null || echo "Файл не найден"
    echo
    
    echo -e "${BLUE}Конфигурация туннеля:${NC}"
    cat /opt/l2tp-tunnel/tunnel-config.conf 2>/dev/null || echo "Файл не найден"
    echo
}

# Функция проверки времени загрузки системы
check_boot_time() {
    log "INFO" "=== Проверка времени загрузки системы ==="
    
    echo -e "${BLUE}Время загрузки системы:${NC}"
    uptime
    echo
    
    echo -e "${BLUE}Время работы системы:${NC}"
    systemd-analyze
    echo
    
    echo -e "${BLUE}Время загрузки критических сервисов:${NC}"
    systemd-analyze blame | head -10
    echo
}

# Функция проверки сетевых интерфейсов
check_network_interfaces() {
    log "INFO" "=== Проверка сетевых интерфейсов ==="
    
    echo -e "${BLUE}Активные сетевые интерфейсы:${NC}"
    ip link show
    echo
    
    echo -e "${BLUE}IP адреса:${NC}"
    ip addr show
    echo
    
    echo -e "${BLUE}Маршруты:${NC}"
    ip route show
    echo
    
    echo -e "${BLUE}Интерфейс ppp0 (если существует):${NC}"
    ip link show ppp0 2>/dev/null || echo "Интерфейс ppp0 не найден"
    echo
}

# Функция проверки доступности L2TP сервера
check_l2tp_server() {
    log "INFO" "=== Проверка доступности L2TP сервера ==="
    
    local servers=("main.razbudimir.com" "78.107.255.229")
    
    for server in "${servers[@]}"; do
        echo -e "${BLUE}Проверка доступности $server:${NC}"
        if ping -c 5 -W 3 "$server" >/dev/null 2>&1; then
            log "SUCCESS" "✓ Сервер $server доступен"
            ping -c 5 "$server"
        else
            log "ERROR" "✗ Сервер $server недоступен"
        fi
        echo
    done
}

# Функция проверки логов приложения
check_application_logs() {
    log "INFO" "=== Проверка логов приложения ==="
    
    local log_files=(
        "/var/log/l2tp-tunnel-restore.log"
        "/var/log/l2tp-tunnel-monitor.log"
        "/var/log/l2tp-health-check.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            echo -e "${BLUE}Последние 20 строк из $log_file:${NC}"
            tail -20 "$log_file"
            echo
        else
            log "WARN" "⚠ Лог файл $log_file не найден"
        fi
    done
}

# Функция тестирования автозапуска
test_autostart() {
    log "INFO" "=== Тестирование автозапуска ==="
    
    echo -e "${YELLOW}Внимание! Это перезапустит сервис восстановления туннеля.${NC}"
    echo -e "${YELLOW}Продолжить? (y/N):${NC}"
    read -p "" confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        log "INFO" "Перезапускаем сервис восстановления туннеля..."
        
        # Останавливаем сервис
        systemctl stop l2tp-tunnel-restore.service
        
        # Ждем немного
        sleep 5
        
        # Запускаем сервис
        systemctl start l2tp-tunnel-restore.service
        
        # Ждем завершения
        sleep 10
        
        # Проверяем статус
        if systemctl is-active --quiet l2tp-tunnel-restore.service; then
            log "SUCCESS" "✓ Сервис успешно запущен"
        else
            log "ERROR" "✗ Сервис не запустился"
        fi
        
        # Показываем логи
        echo -e "${BLUE}Логи после перезапуска:${NC}"
        journalctl -u l2tp-tunnel-restore.service --no-pager -l --since "1 minute ago"
    else
        log "INFO" "Тестирование отменено"
    fi
}

# Функция генерации отчета
generate_report() {
    log "INFO" "=== Генерация отчета диагностики ==="
    
    local report_file="/tmp/l2tp-autostart-debug-$(date +%Y%m%d_%H%M%S).txt"
    
    echo "L2TP Tunnel Autostart Debug Report" > "$report_file"
    echo "=================================" >> "$report_file"
    echo "Дата: $(date)" >> "$report_file"
    echo "Сервер: $(hostname)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Собираем информацию
    echo "СТАТУС СЕРВИСОВ:" >> "$report_file"
    systemctl status l2tp-tunnel-restore.service --no-pager >> "$report_file" 2>&1
    echo "" >> "$report_file"
    
    echo "ЛОГИ SYSTEMD:" >> "$report_file"
    journalctl -u l2tp-tunnel-restore.service --no-pager -l --since "1 hour ago" >> "$report_file" 2>&1
    echo "" >> "$report_file"
    
    echo "КОНФИГУРАЦИЯ СЕРВИСА:" >> "$report_file"
    cat /etc/systemd/system/l2tp-tunnel-restore.service >> "$report_file" 2>&1
    echo "" >> "$report_file"
    
    echo "ВРЕМЯ ЗАГРУЗКИ:" >> "$report_file"
    systemd-analyze >> "$report_file" 2>&1
    echo "" >> "$report_file"
    
    log "SUCCESS" "Отчет сохранен: $report_file"
    echo "$report_file"
}

# Основная функция
main() {
    show_header
    
    log "INFO" "Начинаем диагностику проблем автозапуска L2TP туннеля"
    
    # Проверяем права root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    # Выполняем все проверки
    check_service_status
    check_systemd_logs
    check_service_files
    check_service_configuration
    check_boot_time
    check_network_interfaces
    check_l2tp_server
    check_application_logs
    
    # Генерируем отчет
    local report_file=$(generate_report)
    
    # Предлагаем тестирование
    echo
    echo -e "${YELLOW}Хотите протестировать автозапуск? (y/N):${NC}"
    read -p "" test_choice
    
    if [[ $test_choice =~ ^[Yy]$ ]]; then
        test_autostart
    fi
    
    # Итоговый результат
    echo
    log "INFO" "=== Диагностика завершена ==="
    log "INFO" "Отчет сохранен: $report_file"
    log "INFO" "Лог диагностики: $LOG_FILE"
    
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC} ${WHITE}ДИАГНОСТИКА ЗАВЕРШЕНА${NC} ${GREEN}                                        ║${NC}"
    echo -e "${GREEN}║${NC} ${WHITE}Проверьте отчет и логи для анализа проблем${NC} ${GREEN}              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
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
