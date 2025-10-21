#!/bin/bash

# Скрипт удаления L2TP IPSec Tunnel Restore
# Автор: PROJECT7
# Версия: 1.0

set -euo pipefail

# Конфигурация
INSTALL_DIR="/opt/l2tp-tunnel"

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
    
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $message"
            ;;
    esac
}

# Функция проверки прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
}

# Функция остановки сервисов
stop_services() {
    log "INFO" "Останавливаем сервисы..."
    
    # Останавливаем сервисы
    systemctl stop l2tp-tunnel-monitor.service 2>/dev/null || true
    systemctl stop l2tp-tunnel-restore.service 2>/dev/null || true
    
    # Отключаем автозапуск
    systemctl disable l2tp-tunnel-monitor.service 2>/dev/null || true
    systemctl disable l2tp-tunnel-restore.service 2>/dev/null || true
    
    log "INFO" "Сервисы остановлены"
}

# Функция удаления systemd сервисов
remove_services() {
    log "INFO" "Удаляем systemd сервисы..."
    
    # Удаляем файлы сервисов
    rm -f /etc/systemd/system/l2tp-tunnel-restore.service
    rm -f /etc/systemd/system/l2tp-tunnel-monitor.service
    
    # Перезагружаем systemd
    systemctl daemon-reload
    
    log "INFO" "Systemd сервисы удалены"
}

# Функция удаления файлов
remove_files() {
    log "INFO" "Удаляем файлы..."
    
    # Удаляем установочную директорию
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        log "INFO" "Директория $INSTALL_DIR удалена"
    fi
    
    # Удаляем cron задачи
    rm -f /etc/cron.d/l2tp-tunnel-check
    
    # Удаляем logrotate конфигурацию
    rm -f /etc/logrotate.d/l2tp-tunnel
    
    log "INFO" "Файлы удалены"
}

# Функция очистки логов
cleanup_logs() {
    log "INFO" "Очищаем логи..."
    
    # Удаляем лог файлы
    rm -f /var/log/l2tp-tunnel*.log
    
    # Очищаем systemd логи
    journalctl --vacuum-time=1d >/dev/null 2>&1 || true
    
    log "INFO" "Логи очищены"
}

# Функция восстановления iptables
restore_iptables() {
    log "INFO" "Восстанавливаем iptables..."
    
    # Удаляем правила, связанные с L2TP туннелем
    iptables -t nat -D POSTROUTING -o ppp0 -j MASQUERADE 2>/dev/null || true
    
    # Сохраняем текущие правила
    iptables-save > /etc/iptables/rules.v4
    
    log "INFO" "iptables восстановлен"
}

# Функция подтверждения удаления
confirm_removal() {
    echo
    log "WARN" "Это действие удалит L2TP IPSec Tunnel Restore и все связанные файлы."
    log "WARN" "Сервисы будут остановлены и отключены."
    echo
    read -p "Вы уверены, что хотите продолжить? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Удаление отменено"
        exit 0
    fi
}

# Функция показа информации о том, что будет удалено
show_removal_info() {
    log "INFO" "=== Информация об удалении ==="
    log "INFO" "Будут удалены:"
    log "INFO" "  - Директория: $INSTALL_DIR"
    log "INFO" "  - Systemd сервисы: l2tp-tunnel-restore.service, l2tp-tunnel-monitor.service"
    log "INFO" "  - Cron задачи: /etc/cron.d/l2tp-tunnel-check"
    log "INFO" "  - Logrotate конфигурация: /etc/logrotate.d/l2tp-tunnel"
    log "INFO" "  - Лог файлы: /var/log/l2tp-tunnel*.log"
    log "INFO" "  - iptables правила для ppp0 (MASQUERADE)"
    echo
}

# Основная функция
main() {
    log "INFO" "=== Удаление L2TP IPSec Tunnel Restore ==="
    
    check_root
    show_removal_info
    confirm_removal
    
    stop_services
    remove_services
    remove_files
    cleanup_logs
    restore_iptables
    
    log "INFO" "=== Удаление завершено успешно ==="
    log "INFO" "L2TP IPSec Tunnel Restore полностью удален из системы"
}

# Запуск основной функции
main "$@"

