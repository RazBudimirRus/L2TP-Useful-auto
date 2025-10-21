#!/bin/bash

# L2TP IPSec Tunnel Monitor Script
# Мониторинг состояния туннеля и автоматическое восстановление при сбоях
# Автор: PROJECT7
# Версия: 1.0

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.conf"
LOG_FILE="/var/log/l2tp-tunnel-monitor.log"
HEALTH_CHECK_LOG="/var/log/l2tp-health-check.log"

# Загружаем конфигурацию
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Значения по умолчанию
TUNNEL_INTERFACE="${TUNNEL_INTERFACE:-ppp0}"
TUNNEL_GATEWAY="${TUNNEL_GATEWAY:-172.20.179.1}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-300}"
ENABLE_HEALTH_CHECK="${ENABLE_HEALTH_CHECK:-true}"

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
    esac
}

# Функция проверки состояния туннеля
check_tunnel_health() {
    local issues=0
    
    # Проверяем интерфейс
    if ! ip link show "$TUNNEL_INTERFACE" >/dev/null 2>&1; then
        log "ERROR" "Интерфейс $TUNNEL_INTERFACE не найден"
        issues=$((issues + 1))
    fi
    
    # Проверяем IP адрес
    if ! ip addr show "$TUNNEL_INTERFACE" | grep -q "inet "; then
        log "ERROR" "Интерфейс $TUNNEL_INTERFACE не имеет IP адреса"
        issues=$((issues + 1))
    fi
    
    # Проверяем связность
    if ! ping -c 3 -W 5 "$TUNNEL_GATEWAY" >/dev/null 2>&1; then
        log "ERROR" "Нет связи с шлюзом $TUNNEL_GATEWAY"
        issues=$((issues + 1))
    fi
    
    # Проверяем маршруты
    if ! ip route show | grep -q "192.168.179.0/24"; then
        log "ERROR" "Маршрут до 192.168.179.0/24 не найден"
        issues=$((issues + 1))
    fi
    
    return $issues
}

# Функция восстановления туннеля
restore_tunnel() {
    log "INFO" "Запускаем восстановление туннеля"
    
    if [[ -f "${SCRIPT_DIR}/l2tp-tunnel-restore.sh" ]]; then
        if bash "${SCRIPT_DIR}/l2tp-tunnel-restore.sh"; then
            log "INFO" "Туннель успешно восстановлен"
            return 0
        else
            log "ERROR" "Не удалось восстановить туннель"
            return 1
        fi
    else
        log "ERROR" "Скрипт восстановления не найден: ${SCRIPT_DIR}/l2tp-tunnel-restore.sh"
        return 1
    fi
}

# Функция отправки уведомления
send_notification() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Логируем в health check лог
    echo "[$timestamp] $message" >> "$HEALTH_CHECK_LOG"
    
    # Здесь можно добавить отправку email или webhook
    if [[ "${ENABLE_NOTIFICATIONS:-false}" == "true" ]]; then
        # Пример отправки email
        if [[ -n "${NOTIFICATION_EMAIL:-}" ]]; then
            echo "$message" | mail -s "L2TP Tunnel Alert" "$NOTIFICATION_EMAIL" 2>/dev/null || true
        fi
        
        # Пример отправки webhook
        if [[ -n "${NOTIFICATION_WEBHOOK:-}" ]]; then
            curl -X POST -H "Content-Type: application/json" \
                 -d "{\"text\":\"$message\"}" \
                 "$NOTIFICATION_WEBHOOK" 2>/dev/null || true
        fi
    fi
}

# Основной цикл мониторинга
main() {
    log "INFO" "=== Запуск мониторинга L2TP туннеля ==="
    
    if [[ "$ENABLE_HEALTH_CHECK" != "true" ]]; then
        log "INFO" "Мониторинг отключен в конфигурации"
        exit 0
    fi
    
    local consecutive_failures=0
    local max_consecutive_failures=3
    
    while true; do
        log "DEBUG" "Проверка состояния туннеля..."
        
        if check_tunnel_health; then
            if [[ $consecutive_failures -gt 0 ]]; then
                log "INFO" "Туннель восстановлен после $consecutive_failures сбоев"
                send_notification "L2TP Tunnel restored after $consecutive_failures failures"
                consecutive_failures=0
            fi
        else
            consecutive_failures=$((consecutive_failures + 1))
            log "WARN" "Обнаружены проблемы с туннелем (сбой #$consecutive_failures)"
            
            if [[ $consecutive_failures -ge $max_consecutive_failures ]]; then
                log "ERROR" "Критическое количество сбоев ($consecutive_failures), запускаем восстановление"
                send_notification "L2TP Tunnel critical failure, attempting restore"
                
                if restore_tunnel; then
                    consecutive_failures=0
                    send_notification "L2TP Tunnel successfully restored"
                else
                    send_notification "L2TP Tunnel restore failed"
                fi
            fi
        fi
        
        log "DEBUG" "Ожидание $HEALTH_CHECK_INTERVAL секунд до следующей проверки"
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Обработка сигналов
trap 'log "WARN" "Получен сигнал прерывания, завершаем мониторинг"; exit 0' INT TERM

# Запуск основной функции
main "$@"

