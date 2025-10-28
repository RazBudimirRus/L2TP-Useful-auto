#!/bin/bash

# L2TP IPSec Tunnel Restore Script
# Автоматическое восстановление L2TP IPSec туннеля после перезагрузки сервера
# Автор: PROJECT7
# Версия: 1.0

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/l2tp-tunnel-restore.log"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.conf"
MAX_RETRIES=1
PING_COUNT=10
PING_TIMEOUT=5
TUNNEL_INTERFACE="ppp0"
TUNNEL_GATEWAY="172.20.179.1"
TARGET_NETWORK="192.168.179.0/24"
L2TP_CONTROL="/var/run/xl2tpd/l2tp-control"
L2TP_CONNECTION="razbudimir"
L2TP_SERVER_HOST="main.razbudimir.com"
L2TP_SERVER_IP="78.107.255.229"

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

# Функция проверки доступности L2TP сервера
check_l2tp_server_availability() {
    log "INFO" "=== Проверка доступности L2TP сервера ==="
    
    local server_available=false
    
    # Проверяем доступность по IP адресу
    log "INFO" "Проверяем доступность L2TP сервера по IP: $L2TP_SERVER_IP"
    if ping -c 10 -W 3 "$L2TP_SERVER_IP" >/dev/null 2>&1; then
        log "INFO" "✓ L2TP сервер доступен по IP: $L2TP_SERVER_IP"
        server_available=true
        
        # Показываем детальный пинг
        echo -e "${BLUE}Детальный пинг до L2TP сервера ($L2TP_SERVER_IP):${NC}"
        ping -c 10 "$L2TP_SERVER_IP"
        echo
    else
        log "WARN" "⚠ L2TP сервер недоступен по IP: $L2TP_SERVER_IP"
    fi
    
    # Проверяем доступность по доменному имени
    log "INFO" "Проверяем доступность L2TP сервера по домену: $L2TP_SERVER_HOST"
    if ping -c 10 -W 3 "$L2TP_SERVER_HOST" >/dev/null 2>&1; then
        log "INFO" "✓ L2TP сервер доступен по домену: $L2TP_SERVER_HOST"
        server_available=true
        
        # Показываем детальный пинг
        echo -e "${BLUE}Детальный пинг до L2TP сервера ($L2TP_SERVER_HOST):${NC}"
        ping -c 10 "$L2TP_SERVER_HOST"
        echo
    else
        log "WARN" "⚠ L2TP сервер недоступен по домену: $L2TP_SERVER_HOST"
    fi
    
    if [[ "$server_available" == "true" ]]; then
        log "INFO" "✓ L2TP сервер доступен, продолжаем восстановление туннеля"
        return 0
    else
        log "ERROR" "✗ L2TP сервер недоступен, отменяем восстановление туннеля"
        return 1
    fi
}

# Функция проверки прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
}

# Функция загрузки конфигурации
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "INFO" "Загружаем конфигурацию из $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log "WARN" "Файл конфигурации $CONFIG_FILE не найден, используем значения по умолчанию"
    fi
}

# Функция проверки и перезапуска службы
check_and_restart_service() {
    local service_name="$1"
    local retry_count=0
    
    log "INFO" "Проверяем статус службы $service_name"
    
    while [[ $retry_count -le $MAX_RETRIES ]]; do
        if systemctl is-active --quiet "$service_name"; then
            log "INFO" "Служба $service_name активна"
            return 0
        else
            log "WARN" "Служба $service_name неактивна, попытка $((retry_count + 1))/$((MAX_RETRIES + 1))"
            
            if [[ $retry_count -lt $MAX_RETRIES ]]; then
                log "INFO" "Перезапускаем службу $service_name"
                systemctl restart "$service_name"
                sleep 3
                
                if systemctl is-active --quiet "$service_name"; then
                    log "INFO" "Служба $service_name успешно перезапущена"
                    return 0
                fi
            fi
            
            retry_count=$((retry_count + 1))
        fi
    done
    
    log "ERROR" "Не удалось запустить службу $service_name после $MAX_RETRIES попыток"
    return 1
}

# Функция поднятия IPSec туннеля
start_ipsec_tunnel() {
    log "INFO" "Поднимаем IPSec туннель"
    
    if command -v ipsec >/dev/null 2>&1; then
        ipsec up l2tp-client
    log "INFO" "IPSec туннель поднят, ждем 10 секунд для стабилизации"
    sleep 10
    else
        log "ERROR" "Команда ipsec не найдена"
        return 1
    fi
}

# Функция запуска L2TP туннеля
start_l2tp_tunnel() {
    log "INFO" "Запускаем L2TP туннель"
    
    # Дополнительная диагностика xl2tpd
    log "INFO" "Проверяем статус xl2tpd перед запуском L2TP"
    if ! systemctl is-active --quiet xl2tpd; then
        log "WARN" "xl2tpd неактивен, перезапускаем"
        systemctl restart xl2tpd
        sleep 3
    fi
    
    # Проверяем существование control файла
    if [[ ! -d "$(dirname "$L2TP_CONTROL")" ]]; then
        log "ERROR" "Директория $(dirname "$L2TP_CONTROL") не существует"
        return 1
    fi
    
    # Создаем control файл если не существует
    if [[ ! -f "$L2TP_CONTROL" ]]; then
        log "WARN" "Control файл $L2TP_CONTROL не существует, создаем"
        touch "$L2TP_CONTROL"
        chmod 600 "$L2TP_CONTROL"
    fi
    
    # Проверяем, что xl2tpd слушает на нужном порту
    log "INFO" "Проверяем, что xl2tpd слушает на порту 1701"
    if ! netstat -uln | grep -q ":1701"; then
        log "WARN" "xl2tpd не слушает на порту 1701, перезапускаем"
        systemctl restart xl2tpd
        sleep 5
    fi
    
    # Отправляем команду подключения
    echo "c $L2TP_CONNECTION" > "$L2TP_CONTROL"
    log "INFO" "Команда подключения L2TP отправлена"
    
    # Ждем появления интерфейса
    local wait_time=0
    local max_wait=60  # Увеличиваем время ожидания до 60 секунд
    
    log "INFO" "Ожидаем появления интерфейса $TUNNEL_INTERFACE (максимум $max_wait секунд)..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        if ip link show "$TUNNEL_INTERFACE" >/dev/null 2>&1; then
            log "INFO" "Интерфейс $TUNNEL_INTERFACE обнаружен через $wait_time секунд"
            return 0
        fi
        
        # Показываем прогресс каждые 10 секунд
        if [[ $((wait_time % 10)) -eq 0 && $wait_time -gt 0 ]]; then
            log "INFO" "Ожидание интерфейса $TUNNEL_INTERFACE... ($wait_time/$max_wait секунд)"
        fi
        
        sleep 1
        wait_time=$((wait_time + 1))
    done
    
    log "ERROR" "Интерфейс $TUNNEL_INTERFACE не появился в течение $max_wait секунд"
    
    # Дополнительная диагностика
    log "INFO" "Выполняем дополнительную диагностику..."
    
    # Проверяем статус xl2tpd
    log "INFO" "Статус xl2tpd:"
    systemctl status xl2tpd --no-pager -l | head -10
    
    # Проверяем логи xl2tpd
    log "INFO" "Последние логи xl2tpd:"
    journalctl -u xl2tpd --no-pager -l --since "5 minutes ago" | tail -10
    
    # Проверяем, что слушает xl2tpd
    log "INFO" "Порты, слушаемые xl2tpd:"
    netstat -uln | grep -E "(1701|500|4500)" || log "WARN" "xl2tpd не слушает на ожидаемых портах"
    
    # Проверяем control файл
    if [[ -f "$L2TP_CONTROL" ]]; then
        log "INFO" "Содержимое control файла:"
        cat "$L2TP_CONTROL" || log "WARN" "Не удалось прочитать control файл"
    else
        log "WARN" "Control файл не существует"
    fi
    
    return 1
}

# Функция проверки интерфейса и получения IP
check_tunnel_interface() {
    log "INFO" "Проверяем интерфейс $TUNNEL_INTERFACE"
    
    if ip link show "$TUNNEL_INTERFACE" >/dev/null 2>&1; then
        local tunnel_ip=$(ip addr show "$TUNNEL_INTERFACE" | grep -oP 'inet \K[0-9.]+' | head -1)
        if [[ -n "$tunnel_ip" ]]; then
            log "INFO" "Интерфейс $TUNNEL_INTERFACE активен с IP: $tunnel_ip"
            return 0
        else
            log "ERROR" "Интерфейс $TUNNEL_INTERFACE не имеет IP адреса"
            return 1
        fi
    else
        log "ERROR" "Интерфейс $TUNNEL_INTERFACE не найден"
        return 1
    fi
}

# Функция проверки пинга до шлюза
test_tunnel_connectivity() {
    log "INFO" "Тестируем связность с шлюзом $TUNNEL_GATEWAY"
    
    if ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$TUNNEL_GATEWAY" >/dev/null 2>&1; then
        log "INFO" "Пинг до шлюза $TUNNEL_GATEWAY успешен"
        return 0
    else
        log "ERROR" "Пинг до шлюза $TUNNEL_GATEWAY неудачен"
        return 1
    fi
}

# Функция проверки и добавления маршрута
check_and_add_route() {
    log "INFO" "Проверяем маршрут до сети $TARGET_NETWORK"
    
    if ip route show | grep -q "$TARGET_NETWORK"; then
        log "INFO" "Маршрут до $TARGET_NETWORK уже существует"
    else
        log "INFO" "Добавляем маршрут до $TARGET_NETWORK через $TUNNEL_GATEWAY"
        if ip route add "$TARGET_NETWORK" via "$TUNNEL_GATEWAY" dev "$TUNNEL_INTERFACE"; then
            log "INFO" "Маршрут успешно добавлен"
        else
            log "ERROR" "Не удалось добавить маршрут"
            return 1
        fi
    fi
}

# Функция проверки iptables правил
check_iptables_rules() {
    log "INFO" "Проверяем правила iptables"
    
    # Проверяем MASQUERADE для ppp0
    if iptables -t nat -L POSTROUTING | grep -q "MASQUERADE.*ppp0"; then
        log "INFO" "MASQUERADE правило для ppp0 найдено"
    else
        log "WARN" "MASQUERADE правило для ppp0 не найдено"
        log "INFO" "Добавляем MASQUERADE правило для ppp0"
        if iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE; then
            log "INFO" "MASQUERADE правило для ppp0 добавлено"
        else
            log "ERROR" "Не удалось добавить MASQUERADE правило для ppp0"
            return 1
        fi
    fi
    
    # Проверяем MASQUERADE для eth0
    if iptables -t nat -L POSTROUTING | grep -q "MASQUERADE.*eth0"; then
        log "INFO" "MASQUERADE правило для eth0 найдено"
    else
        log "WARN" "MASQUERADE правило для eth0 не найдено"
        log "INFO" "Добавляем MASQUERADE правило для eth0"
        if iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; then
            log "INFO" "MASQUERADE правило для eth0 добавлено"
        else
            log "ERROR" "Не удалось добавить MASQUERADE правило для eth0"
            return 1
        fi
    fi
}

# Функция сохранения правил iptables
save_iptables_rules() {
    log "INFO" "Сохраняем правила iptables"
    
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4
        log "INFO" "Правила iptables сохранены в /etc/iptables/rules.v4"
    else
        log "WARN" "iptables-save не найден, правила не сохранены"
    fi
}

# Основная функция
main() {
    log "INFO" "=== Запуск восстановления L2TP IPSec туннеля ==="
    
    check_root
    load_config
    
    # Проверяем доступность L2TP сервера перед началом восстановления
    if ! check_l2tp_server_availability; then
        log "ERROR" "L2TP сервер недоступен, завершаем работу"
        exit 1
    fi
    
    local exit_code=0
    
    # Шаг 1: Проверяем и перезапускаем службы
    log "INFO" "Шаг 1: Проверка служб"
    if ! check_and_restart_service "ipsec"; then
        exit_code=1
    fi
    
    if ! check_and_restart_service "xl2tpd"; then
        exit_code=1
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        log "ERROR" "Не удалось запустить необходимые службы"
        exit $exit_code
    fi
    
    # Шаг 2: Поднимаем IPSec туннель
    log "INFO" "Шаг 2: Поднятие IPSec туннеля"
    if ! start_ipsec_tunnel; then
        log "ERROR" "Не удалось поднять IPSec туннель"
        exit 1
    fi
    
    # Шаг 3: Запускаем L2TP туннель
    log "INFO" "Шаг 3: Запуск L2TP туннеля"
    if ! start_l2tp_tunnel; then
        log "ERROR" "Не удалось запустить L2TP туннель"
        exit 1
    fi
    
    # Шаг 4: Проверяем интерфейс
    log "INFO" "Шаг 4: Проверка интерфейса туннеля"
    if ! check_tunnel_interface; then
        log "ERROR" "Проблемы с интерфейсом туннеля"
        exit 1
    fi
    
    # Шаг 5: Тестируем связность
    log "INFO" "Шаг 5: Тестирование связности"
    if ! test_tunnel_connectivity; then
        log "ERROR" "Проблемы со связностью туннеля"
        exit 1
    fi
    
    # Шаг 6: Проверяем маршруты и iptables
    log "INFO" "Шаг 6: Проверка маршрутов и iptables"
    if ! check_and_add_route; then
        log "ERROR" "Проблемы с маршрутизацией"
        exit 1
    fi
    
    if ! check_iptables_rules; then
        log "ERROR" "Проблемы с iptables"
        exit 1
    fi
    
    # Сохраняем правила iptables
    save_iptables_rules
    
    log "INFO" "=== Восстановление туннеля завершено успешно ==="
    
    # Показываем статус
    log "INFO" "Текущий статус:"
    ip route show | grep -E "(ppp0|192\.168\.179)" || true
    iptables -t nat -L POSTROUTING | grep -E "(ppp0|eth0)" || true
}

# Обработка сигналов
trap 'log "WARN" "Получен сигнал прерывания, завершаем работу"; exit 130' INT TERM

# Запуск основной функции
main "$@"
