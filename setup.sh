#!/bin/bash

# Vehicle Tracking RabbitMQ Broker - Setup Script
# Management script for Vehicle Tracking RabbitMQ

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }
print_header() { echo -e "${BLUE}$1${NC}"; }

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi
    print_success "Docker found"
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose not found. Please install Docker Compose first."
        exit 1
    fi
    print_success "Docker Compose found"
}

setup_env() {
    if [ ! -f .env ]; then
        print_info ".env file not found, creating from template..."
        if [ -f .env.example ]; then
            cp .env.example .env
            print_success ".env file created from template"
        else
            print_error ".env.example not found"
            exit 1
        fi
    else
        print_info ".env file already exists"
    fi
}

# Check if using docker-compose or docker compose
get_compose_command() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

wait_for_rabbitmq() {
    print_info "Waiting for RabbitMQ to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec tracking-rabbitmq-broker rabbitmq-diagnostics ping &> /dev/null; then
            print_success "RabbitMQ is ready!"
            return 0
        fi
        
        print_info "Attempt $attempt/$max_attempts - waiting..."
        sleep 5
        ((attempt++))
    done
    
    print_error "RabbitMQ failed to start within expected time"
    show_logs
    return 1
}

start_broker() {
    local compose_cmd=$(get_compose_command)
    
    print_info "Starting Vehicle Tracking RabbitMQ Broker..."
    
    # Check if config files exist
    if [ ! -f "config/definitions.json" ]; then
        print_error "config/definitions.json not found"
        exit 1
    fi
    
    if [ ! -f "config/rabbitmq.conf" ]; then
        print_error "config/rabbitmq.conf not found"
        exit 1
    fi
    
    $compose_cmd up -d
    
    if [ $? -eq 0 ]; then
        print_success "Broker containers started successfully"
    else
        print_error "Failed to start broker containers"
        exit 1
    fi
    
    # Wait for RabbitMQ to be ready
    if wait_for_rabbitmq; then
        print_success "RabbitMQ broker is running and healthy"
        
        # Get configuration values
        RABBITMQ_USER=$(grep RABBITMQ_DEFAULT_USER .env | cut -d '=' -f2)
        RABBITMQ_PASS=$(grep RABBITMQ_DEFAULT_PASS .env | cut -d '=' -f2)
        RABBITMQ_MGMT_PORT=$(grep RABBITMQ_MANAGEMENT_PORT .env | cut -d '=' -f2)
        RABBITMQ_AMQP_PORT=$(grep RABBITMQ_AMQP_PORT .env | cut -d '=' -f2)
        RABBITMQ_MQTT_PORT=$(grep RABBITMQ_MQTT_PORT .env | cut -d '=' -f2)
        
        echo ""
        print_header "═══════════════════════════════════════════════════"
        print_header "  Vehicle Tracking RabbitMQ Broker Started Successfully"
        print_header "═══════════════════════════════════════════════════"
        echo ""
        echo "Management UI: http://localhost:${RABBITMQ_MGMT_PORT:-15672}"
        echo "Username: ${RABBITMQ_USER:-admin}"
        echo "Password: ${RABBITMQ_PASS:-***}"
        echo ""
        echo "Connection Ports:"
        echo "  - AMQP: ${RABBITMQ_AMQP_PORT:-5672}"
        echo "  - MQTT: ${RABBITMQ_MQTT_PORT:-1883}"
        echo "  - Management: ${RABBITMQ_MGMT_PORT:-15672}"
        echo ""
        echo "Pre-configured Queues:"
        echo "  - vehicle.control.start_rent"
        echo "  - vehicle.control.end_rent"
        echo "  - vehicle.control.kill_vehicle"
        echo "  - vehicle.realtime.location"
        echo "  - vehicle.realtime.status"
        echo "  - vehicle.realtime.battery"
        echo "  - vehicle.report.maintenance"
        echo "  - vehicle.report.performance"
        echo "  - vehicle.dlq (Dead Letter Queue)"
        echo ""
        echo "Exchange: vehicle.exchange (topic)"
        echo ""
    else
        print_error "RabbitMQ failed to start properly"
        exit 1
    fi
}

stop_broker() {
    local compose_cmd=$(get_compose_command)
    print_info "Stopping Vehicle Tracking RabbitMQ Broker..."
    $compose_cmd down
    if [ $? -eq 0 ]; then
        print_success "Broker stopped successfully"
    else
        print_error "Failed to stop broker"
        exit 1
    fi
}

restart_broker() {
    local compose_cmd=$(get_compose_command)
    print_info "Restarting Vehicle Tracking RabbitMQ Broker..."
    $compose_cmd restart
    if [ $? -eq 0 ]; then
        print_success "Broker restarted successfully"
        wait_for_rabbitmq
    else
        print_error "Failed to restart broker"
        exit 1
    fi
}

show_logs() {
    local compose_cmd=$(get_compose_command)
    print_info "Showing RabbitMQ logs..."
    $compose_cmd logs -f tracking-rabbitmq
}

show_status() {
    local compose_cmd=$(get_compose_command)
    print_info "Docker Container Status:"
    $compose_cmd ps
    echo ""
    
    if docker ps | grep -q tracking-rabbitmq-broker; then
        print_info "RabbitMQ Health Status:"
        if docker exec tracking-rabbitmq-broker rabbitmq-diagnostics ping &> /dev/null; then
            print_success "RabbitMQ is healthy"
            echo ""
            print_info "RabbitMQ Status Details:"
            docker exec tracking-rabbitmq-broker rabbitmqctl status | head -n 20
        else
            print_error "RabbitMQ is not responding"
        fi
    else
        print_error "RabbitMQ container is not running"
    fi
}

show_queues() {
    if docker ps | grep -q tracking-rabbitmq-broker; then
        if docker exec tracking-rabbitmq-broker rabbitmq-diagnostics ping &> /dev/null; then
            print_info "Queue Status:"
            docker exec tracking-rabbitmq-broker rabbitmqctl list_queues name messages consumers | column -t
        else
            print_error "RabbitMQ is not responding"
        fi
    else
        print_error "RabbitMQ broker not running"
    fi
}

show_connections() {
    if docker ps | grep -q tracking-rabbitmq-broker; then
        if docker exec tracking-rabbitmq-broker rabbitmq-diagnostics ping &> /dev/null; then
            print_info "Active Connections:"
            docker exec tracking-rabbitmq-broker rabbitmqctl list_connections name peer_host peer_port state | column -t
        else
            print_error "RabbitMQ is not responding"
        fi
    else
        print_error "RabbitMQ broker not running"
    fi
}

backup_config() {
    if docker ps | grep -q tracking-rabbitmq-broker; then
        if docker exec tracking-rabbitmq-broker rabbitmq-diagnostics ping &> /dev/null; then
            BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).json"
            print_info "Creating configuration backup..."
            docker exec tracking-rabbitmq-broker rabbitmqctl export_definitions /tmp/backup.json
            docker cp tracking-rabbitmq-broker:/tmp/backup.json ./${BACKUP_FILE}
            print_success "Backup saved: ${BACKUP_FILE}"
        else
            print_error "RabbitMQ is not responding"
        fi
    else
        print_error "RabbitMQ broker not running"
    fi
}

purge_queue() {
    if docker ps | grep -q tracking-rabbitmq-broker; then
        if docker exec tracking-rabbitmq-broker rabbitmq-diagnostics ping &> /dev/null; then
            echo ""
            print_info "Available queues:"
            docker exec tracking-rabbitmq-broker rabbitmqctl list_queues name
            echo ""
            read -p "Enter queue name to purge: " queue_name
            if [ ! -z "$queue_name" ]; then
                docker exec tracking-rabbitmq-broker rabbitmqctl purge_queue "$queue_name"
                if [ $? -eq 0 ]; then
                    print_success "Queue purged: $queue_name"
                else
                    print_error "Failed to purge queue: $queue_name"
                fi
            else
                print_info "No queue name provided"
            fi
        else
            print_error "RabbitMQ is not responding"
        fi
    else
        print_error "RabbitMQ broker not running"
    fi
}

test_connection() {
    if docker ps | grep -q tracking-rabbitmq-broker; then
        if docker exec tracking-rabbitmq-broker rabbitmq-diagnostics ping &> /dev/null; then
            print_success "RabbitMQ connection test passed"
            
            # Test management API
            RABBITMQ_MGMT_PORT=$(grep RABBITMQ_MANAGEMENT_PORT .env | cut -d '=' -f2)
            if curl -s http://localhost:${RABBITMQ_MGMT_PORT:-15672}/api/overview &> /dev/null; then
                print_success "Management API is accessible"
            else
                print_error "Management API is not accessible"
            fi
        else
            print_error "RabbitMQ connection test failed"
        fi
    else
        print_error "RabbitMQ broker not running"
    fi
}

clean_all() {
    local compose_cmd=$(get_compose_command)
    print_info "This will remove all containers, volumes, and data..."
    read -p "Are you sure? All data will be lost! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Stopping and removing containers..."
        $compose_cmd down -v --remove-orphans
        
        # Remove named volumes if they exist
        docker volume rm tracking_rabbitmq_data tracking_rabbitmq_logs 2>/dev/null || true
        
        print_success "All containers and volumes removed"
    else
        print_info "Operation cancelled"
    fi
}

show_menu() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║       Vehicle Tracking RabbitMQ Broker Manager      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo " 1) Start Broker"
    echo " 2) Stop Broker"
    echo " 3) Restart Broker"
    echo " 4) Show Logs"
    echo " 5) Show Status"
    echo " 6) Show Queues"
    echo " 7) Show Connections"
    echo " 8) Test Connection"
    echo " 9) Backup Configuration"
    echo "10) Purge Queue"
    echo "11) Clean All (Delete volumes)"
    echo "12) Exit"
    echo ""
}

main() {
    clear
    check_docker
    check_docker_compose
    
    # Command line arguments
    case "$1" in
        "start")
            setup_env
            start_broker
            exit 0
            ;;
        "stop")
            stop_broker
            exit 0
            ;;
        "restart")
            restart_broker
            exit 0
            ;;
        "logs")
            show_logs
            exit 0
            ;;
        "status")
            show_status
            exit 0
            ;;
        "test")
            test_connection
            exit 0
            ;;
        "clean")
            clean_all
            exit 0
            ;;
    esac
    
    # Interactive menu
    while true; do
        show_menu
        read -p "Select option (1-12): " choice
        
        case $choice in
            1) setup_env; start_broker ;;
            2) stop_broker ;;
            3) restart_broker ;;
            4) show_logs ;;
            5) show_status ;;
            6) show_queues ;;
            7) show_connections ;;
            8) test_connection ;;
            9) backup_config ;;
            10) purge_queue ;;
            11) clean_all ;;
            12) print_info "Goodbye!"; exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

main "$@"