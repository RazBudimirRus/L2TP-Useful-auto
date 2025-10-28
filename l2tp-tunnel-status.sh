#!/bin/bash

# L2TP IPSec Tunnel Status Checker
# Интерактивный скрипт проверки состояния туннеля
# Автор: PROJECT7
# Версия: 1.0

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.conf"
LOG_FILE="/var/log/l2tp-tunnel-status.log"

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
        "STATUS")
            echo -e "${CYAN}[STATUS]${NC} $message"
            echo "[$timestamp] [STATUS] $message" >> "$LOG_FILE"
            ;;
    esac
}

# Функция отображения заголовка
show_header() {
    clear
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║${NC} ${CYAN}L2TP IPSec Tunnel Status Checker${NC} ${WHITE}                              ║${NC}"
    echo -e "${WHITE}║${NC} ${PURPLE}Интерактивная проверка состояния туннеля${NC} ${WHITE}                    ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Функция отображения меню
show_menu() {
    echo -e "${WHITE}Выберите действие:${NC}"
    echo
    echo -e "${GREEN}1.${NC} ${CYAN}Полная проверка состояния${NC}"
    echo -e "${GREEN}2.${NC} ${CYAN}Быстрая диагностика${NC}"
    echo -e "${GREEN}3.${NC} ${CYAN}Проверка служб${NC}"
    echo -e "${GREEN}4.${NC} ${CYAN}Проверка интерфейса${NC}"
    echo -e "${GREEN}5.${NC} ${CYAN}Тест связности${NC}"
    echo -e "${GREEN}6.${NC} ${CYAN}Проверка маршрутов${NC}"
    echo -e "${GREEN}7.${NC} ${CYAN}Проверка iptables${NC}"
    echo -e "${GREEN}8.${NC} ${CYAN}Просмотр логов${NC}"
    echo -e "${GREEN}9.${NC} ${CYAN}Перезапуск туннеля${NC}"
    echo -e "${GREEN}0.${NC} ${RED}Выход${NC}"
    echo
}

# Функция проверки служб
check_services() {
    log "STATUS" "=== Проверка служб ==="
    
    local services=("ipsec" "xl2tpd")
    local all_active=true
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "INFO" "✓ Служба $service активна"
        else
            log "ERROR" "✗ Служба $service неактивна"
            all_active=false
        fi
        
        # Показываем статус
        echo -e "${BLUE}Статус службы $service:${NC}"
        systemctl status "$service" --no-pager -l | head -10
        echo
    done
    
    if [[ "$all_active" == "true" ]]; then
        log "INFO" "Все службы активны"
        return 0
    else
        log "ERROR" "Некоторые службы неактивны"
        return 1
    fi
}

# Функция проверки интерфейса
check_interface() {
    log "STATUS" "=== Проверка интерфейса $TUNNEL_INTERFACE ==="
    
    if ip link show "$TUNNEL_INTERFACE" >/dev/null 2>&1; then
        log "INFO" "✓ Интерфейс $TUNNEL_INTERFACE существует"
        
        # Показываем информацию об интерфейсе
        echo -e "${BLUE}Информация об интерфейсе:${NC}"
        ip link show "$TUNNEL_INTERFACE"
        echo
        
        # Проверяем IP адрес
        local tunnel_ip=$(ip addr show "$TUNNEL_INTERFACE" | grep -oP 'inet \K[0-9.]+' | head -1)
        if [[ -n "$tunnel_ip" ]]; then
            log "INFO" "✓ IP адрес интерфейса: $tunnel_ip"
        else
            log "ERROR" "✗ Интерфейс не имеет IP адреса"
            return 1
        fi
        
        # Показываем статистику
        echo -e "${BLUE}Статистика интерфейса:${NC}"
        ip -s link show "$TUNNEL_INTERFACE"
        echo
        
        return 0
    else
        log "ERROR" "✗ Интерфейс $TUNNEL_INTERFACE не найден"
        return 1
    fi
}

# Функция тестирования связности
test_connectivity() {
    log "STATUS" "=== Тест связности ==="
    
    # Тест до шлюза
    log "INFO" "Тестируем связность с шлюзом $TUNNEL_GATEWAY"
    if ping -c 5 -W 3 "$TUNNEL_GATEWAY" >/dev/null 2>&1; then
        log "INFO" "✓ Пинг до шлюза успешен"
        
        # Показываем детальный пинг
        echo -e "${BLUE}Детальный пинг до шлюза:${NC}"
        ping -c 5 "$TUNNEL_GATEWAY"
        echo
    else
        log "ERROR" "✗ Пинг до шлюза неудачен"
        return 1
    fi
    
    # Тест до целевой сети
    log "INFO" "Тестируем связность с целевой сетью"
    local target_ip=$(echo "$TARGET_NETWORK" | cut -d'/' -f1 | sed 's/0$/1/')
    if ping -c 3 -W 2 "$target_ip" >/dev/null 2>&1; then
        log "INFO" "✓ Пинг до целевой сети успешен"
    else
        log "WARN" "⚠ Пинг до целевой сети неудачен"
    fi
    
    return 0
}

# Функция проверки маршрутов
check_routes() {
    log "STATUS" "=== Проверка маршрутов ==="
    
    # Проверяем маршрут до целевой сети
    if ip route show | grep -q "$TARGET_NETWORK"; then
        log "INFO" "✓ Маршрут до $TARGET_NETWORK найден"
        
        # Показываем маршрут
        echo -e "${BLUE}Маршрут до целевой сети:${NC}"
        ip route show | grep "$TARGET_NETWORK"
        echo
    else
        log "ERROR" "✗ Маршрут до $TARGET_NETWORK не найден"
    fi
    
    # Показываем все маршруты через туннель
    echo -e "${BLUE}Все маршруты через $TUNNEL_INTERFACE:${NC}"
    ip route show | grep "$TUNNEL_INTERFACE" || echo "Маршруты через $TUNNEL_INTERFACE не найдены"
    echo
    
    # Показываем таблицу маршрутизации
    echo -e "${BLUE}Таблица маршрутизации:${NC}"
    ip route show | head -20
    echo
}

# Функция проверки iptables
check_iptables() {
    log "STATUS" "=== Проверка iptables ==="
    
    # Проверяем MASQUERADE для ppp0
    if iptables -t nat -L POSTROUTING | grep -q "MASQUERADE.*ppp0"; then
        log "INFO" "✓ MASQUERADE правило для ppp0 найдено"
    else
        log "ERROR" "✗ MASQUERADE правило для ppp0 не найдено"
    fi
    
    # Проверяем MASQUERADE для eth0
    if iptables -t nat -L POSTROUTING | grep -q "MASQUERADE.*eth0"; then
        log "INFO" "✓ MASQUERADE правило для eth0 найдено"
    else
        log "WARN" "⚠ MASQUERADE правило для eth0 не найдено"
    fi
    
    # Показываем правила NAT
    echo -e "${BLUE}Правила NAT (POSTROUTING):${NC}"
    iptables -t nat -L POSTROUTING -v
    echo
    
    # Показываем правила фильтрации
    echo -e "${BLUE}Правила фильтрации (INPUT):${NC}"
    iptables -L INPUT -v | head -10
    echo
}

# Функция просмотра логов
view_logs() {
    log "STATUS" "=== Просмотр логов ==="
    
    echo -e "${WHITE}Выберите лог для просмотра:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Основной лог восстановления"
    echo -e "${GREEN}2.${NC} Лог мониторинга"
    echo -e "${GREEN}3.${NC} Лог проверок здоровья"
    echo -e "${GREEN}4.${NC} Systemd логи восстановления"
    echo -e "${GREEN}5.${NC} Systemd логи мониторинга"
    echo -e "${GREEN}6.${NC} Логи ipsec"
    echo -e "${GREEN}7.${NC} Логи xl2tpd"
    echo -e "${GREEN}0.${NC} Назад"
    echo
    
    read -p "Выберите опцию: " log_choice
    
    case $log_choice in
        1)
            echo -e "${BLUE}Последние 50 строк основного лога:${NC}"
            tail -50 /var/log/l2tp-tunnel-restore.log 2>/dev/null || echo "Лог не найден"
            ;;
        2)
            echo -e "${BLUE}Последние 50 строк лога мониторинга:${NC}"
            tail -50 /var/log/l2tp-tunnel-monitor.log 2>/dev/null || echo "Лог не найден"
            ;;
        3)
            echo -e "${BLUE}Последние 50 строк лога проверок здоровья:${NC}"
            tail -50 /var/log/l2tp-health-check.log 2>/dev/null || echo "Лог не найден"
            ;;
        4)
            echo -e "${BLUE}Systemd логи восстановления:${NC}"
            journalctl -u l2tp-tunnel-restore.service --no-pager -l | tail -20
            ;;
        5)
            echo -e "${BLUE}Systemd логи мониторинга:${NC}"
            journalctl -u l2tp-tunnel-monitor.service --no-pager -l | tail -20
            ;;
        6)
            echo -e "${BLUE}Логи ipsec:${NC}"
            journalctl -u ipsec.service --no-pager -l | tail -20
            ;;
        7)
            echo -e "${BLUE}Логи xl2tpd:${NC}"
            journalctl -u xl2tpd.service --no-pager -l | tail -20
            ;;
        0)
            return 0
            ;;
        *)
            log "ERROR" "Неверный выбор"
            ;;
    esac
    
    echo
    read -p "Нажмите Enter для продолжения..."
}

# Функция перезапуска туннеля
restart_tunnel() {
    log "STATUS" "=== Перезапуск туннеля ==="
    
    echo -e "${YELLOW}Внимание! Это перезапустит туннель. Продолжить? (y/N):${NC}"
    read -p "" confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        log "INFO" "Запускаем восстановление туннеля..."
        
        if [[ -f "${SCRIPT_DIR}/l2tp-tunnel-restore.sh" ]]; then
            if bash "${SCRIPT_DIR}/l2tp-tunnel-restore.sh"; then
                log "INFO" "✓ Туннель успешно перезапущен"
            else
                log "ERROR" "✗ Ошибка при перезапуске туннеля"
            fi
        else
            log "ERROR" "✗ Скрипт восстановления не найден"
        fi
    else
        log "INFO" "Перезапуск отменен"
    fi
    
    echo
    read -p "Нажмите Enter для продолжения..."
}

# Функция быстрой диагностики
quick_diagnosis() {
    log "STATUS" "=== Быстрая диагностика ==="
    
    local issues=0
    
    # Проверяем службы
    if ! systemctl is-active --quiet ipsec; then
        log "ERROR" "✗ Служба ipsec неактивна"
        issues=$((issues + 1))
    fi
    
    if ! systemctl is-active --quiet xl2tpd; then
        log "ERROR" "✗ Служба xl2tpd неактивна"
        issues=$((issues + 1))
    fi
    
    # Проверяем интерфейс
    if ! ip link show "$TUNNEL_INTERFACE" >/dev/null 2>&1; then
        log "ERROR" "✗ Интерфейс $TUNNEL_INTERFACE не найден"
        issues=$((issues + 1))
    fi
    
    # Проверяем связность
    if ! ping -c 1 -W 2 "$TUNNEL_GATEWAY" >/dev/null 2>&1; then
        log "ERROR" "✗ Нет связи с шлюзом $TUNNEL_GATEWAY"
        issues=$((issues + 1))
    fi
    
    # Проверяем маршруты
    if ! ip route show | grep -q "$TARGET_NETWORK"; then
        log "ERROR" "✗ Маршрут до $TARGET_NETWORK не найден"
        issues=$((issues + 1))
    fi
    
    # Результат
    if [[ $issues -eq 0 ]]; then
        log "INFO" "✓ Все проверки пройдены успешно!"
        echo -e "${GREEN}Туннель работает корректно${NC}"
    else
        log "ERROR" "✗ Обнаружено $issues проблем"
        echo -e "${RED}Туннель требует внимания${NC}"
    fi
    
    echo
    read -p "Нажмите Enter для продолжения..."
}

# Функция полной проверки
full_check() {
    log "STATUS" "=== Полная проверка состояния туннеля ==="
    
    local overall_status=0
    
    # Проверяем службы
    if ! check_services; then
        overall_status=1
    fi
    
    echo
    read -p "Нажмите Enter для продолжения..."
    
    # Проверяем интерфейс
    if ! check_interface; then
        overall_status=1
    fi
    
    echo
    read -p "Нажмите Enter для продолжения..."
    
    # Тестируем связность
    if ! test_connectivity; then
        overall_status=1
    fi
    
    echo
    read -p "Нажмите Enter для продолжения..."
    
    # Проверяем маршруты
    check_routes
    
    echo
    read -p "Нажмите Enter для продолжения..."
    
    # Проверяем iptables
    check_iptables
    
    # Итоговый результат
    echo
    if [[ $overall_status -eq 0 ]]; then
        log "INFO" "✓ Полная проверка завершена - все системы работают нормально"
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC} ${WHITE}СТАТУС: ТУННЕЛЬ РАБОТАЕТ КОРРЕКТНО${NC} ${GREEN}                        ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    else
        log "ERROR" "✗ Полная проверка завершена - обнаружены проблемы"
        echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${NC} ${WHITE}СТАТУС: ОБНАРУЖЕНЫ ПРОБЛЕМЫ${NC} ${RED}                                ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    fi
    
    echo
    read -p "Нажмите Enter для продолжения..."
}

# Основной цикл
main() {
    while true; do
        show_header
        show_menu
        
        read -p "Выберите опцию: " choice
        
        case $choice in
            1)
                full_check
                ;;
            2)
                quick_diagnosis
                ;;
            3)
                check_services
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            4)
                check_interface
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            5)
                test_connectivity
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            6)
                check_routes
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            7)
                check_iptables
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            8)
                view_logs
                ;;
            9)
                restart_tunnel
                ;;
            0)
                log "INFO" "Выход из программы"
                echo -e "${GREEN}До свидания!${NC}"
                exit 0
                ;;
            *)
                log "ERROR" "Неверный выбор. Попробуйте снова."
                sleep 2
                ;;
        esac
    done
}

# Обработка аргументов командной строки
if [[ $# -gt 0 ]]; then
    case "$1" in
        --quick|-q)
            show_header
            quick_diagnosis
            exit 0
            ;;
        --full|-f)
            show_header
            full_check
            exit 0
            ;;
        --services|-s)
            show_header
            check_services
            exit 0
            ;;
        --interface|-i)
            show_header
            check_interface
            exit 0
            ;;
        --connectivity|-c)
            show_header
            test_connectivity
            exit 0
            ;;
        --routes|-r)
            show_header
            check_routes
            exit 0
            ;;
        --iptables|-t)
            show_header
            check_iptables
            exit 0
            ;;
        --help|-h)
            echo "Использование: $0 [опции]"
            echo
            echo "Опции:"
            echo "  --quick, -q     Быстрая диагностика"
            echo "  --full, -f      Полная проверка"
            echo "  --services, -s  Проверка служб"
            echo "  --interface, -i Проверка интерфейса"
            echo "  --connectivity, -c Тест связности"
            echo "  --routes, -r    Проверка маршрутов"
            echo "  --iptables, -t Проверка iptables"
            echo "  --help, -h      Показать эту справку"
            echo
            echo "Без опций запускается интерактивный режим"
            exit 0
            ;;
        *)
            echo "Неизвестная опция: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
fi

# Запуск основной функции
main "$@"
