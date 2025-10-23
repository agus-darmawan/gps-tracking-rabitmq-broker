#!/bin/bash

# Tracking RabbitMQ Broker - Setup Script
# Management script for GPS Tracking RabbitMQ

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
    if ! command -v docker-compose &> /dev/null; then
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

start_broker() {
    print_info "Starting Tracking RabbitMQ Broker..."
    docker-compose up -d
    print_success "Broker started successfully"
    
    print_info "Waiting for RabbitMQ to be ready..."
    sleep 10
    
    if docker ps | grep -q tracking-rabbitmq-broker; then
        print_success "RabbitMQ broker is running"
        
        RABBITMQ_USER=$(grep RABBITMQ_DEFAULT_USER .env | cut -d '=' -f2)
        RABBITMQ_PORT=$(grep RABBITMQ_MANAGEMENT_PORT .env | cut -d '=' -f2)
        
        echo ""
        print_header "═══════════════════════════════════════════════════"
        print_header "   Tracking RabbitMQ Broker Started Successfully   "
        print_header "═══════════════════════════════════════════════════"
        echo ""
        echo "Management UI: http://localhost:${RABBITMQ_PORT}"
        echo "Username: ${RABBITMQ_USER}"
        echo "Password: (check .env file)"
        echo ""
        echo "Ports:"
        echo "  - AMQP: $(grep RABBITMQ_AMQP_PORT .env | cut -d '=' -f2)"
        echo "  - Management: ${RABBITMQ_PORT}"
        echo "  - MQTT: $(grep RABBITMQ_MQTT_PORT .env | cut -d '=' -f2)"
        echo ""
        echo "Pre-configured Queues:"
        echo "  - gps.tracking.location.raw"
        echo "  - gps.tracking.location.processed"
        echo "  - gps.tracking.geofence.alert"
        echo "  - gps.tracking.speed.alert"
        echo "  - gps.tracking.device.status"
        echo "  - gps.tracking.trip.start"
        echo "  - gps.tracking.trip.end"
        echo "  - gps.tracking.dlq"
        echo ""
    else
        print_error "Failed to start RabbitMQ broker"
        docker-compose logs
        exit 1
    fi
}

stop_broker() {
    print_info "Stopping Tracking RabbitMQ Broker..."
    docker-compose down
    print_success "Broker stopped successfully"
}

restart_broker() {
    print_info "Restarting Tracking RabbitMQ Broker..."
    docker-compose restart
    print_success "Broker restarted successfully"
}

show_logs() {
    print_info "Showing RabbitMQ logs..."
    docker-compose logs -f tracking-rabbitmq
}

show_status() {
    print_info "RabbitMQ Status:"
    docker-compose ps
    echo ""
    
    if docker ps | grep -q tracking-rabbitmq-broker; then
        print_info "RabbitMQ Stats:"
        docker exec tracking-rabbitmq-broker rabbitmqctl status | head -n 20
    fi
}

show_queues() {
    if docker ps | grep -q tracking-rabbitmq-broker; then
        print_info "Queues:"
        docker exec tracking-rabbitmq-broker rabbitmqctl list_queues name messages consumers | column -t
    else
        print_error "RabbitMQ broker not running"
    fi
}

show_connections() {
    if docker ps | grep -q tracking-rabbitmq-broker; then
        print_info "Connections:"
        docker exec tracking-rabbitmq-broker rabbitmqctl list_connections name peer_host peer_port state | column -t
    else
        print_error "RabbitMQ broker not running"
    fi
}

backup_config() {
    BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).json"
    print_info "Creating backup..."
    docker exec tracking-rabbitmq-broker rabbitmqctl export_definitions /tmp/backup.json
    docker cp tracking-rabbitmq-broker:/tmp/backup.json ./${BACKUP_FILE}
    print_success "Backup saved: ${BACKUP_FILE}"
}

purge_queue() {
    if docker ps | grep -q tracking-rabbitmq-broker; then
        echo ""
        print_info "Available queues:"
        docker exec tracking-rabbitmq-broker rabbitmqctl list_queues name
        echo ""
        read -p "Enter queue name to purge: " queue_name
        if [ ! -z "$queue_name" ]; then
            docker exec tracking-rabbitmq-broker rabbitmqctl purge_queue "$queue_name"
            print_success "Queue purged: $queue_name"
        fi
    else
        print_error "RabbitMQ broker not running"
    fi
}

run_example() {
    echo ""
    print_header "Available Examples:"
    echo "1) GPS Device Publisher (Python)"
    echo "2) Backend Consumer (Python)"
    echo "3) Backend Consumer (Node.js)"
    echo ""
    read -p "Select example (1-3): " example_choice
    
    case $example_choice in
        1)
            if [ -f examples/gps_device_publisher.py ]; then
                print_info "Starting GPS Device Publisher..."
                cd examples
                python3 gps_device_publisher.py
            else
                print_error "Example file not found"
            fi
            ;;
        2)
            if [ -f examples/backend_consumer.py ]; then
                print_info "Starting Backend Consumer (Python)..."
                cd examples
                python3 backend_consumer.py
            else
                print_error "Example file not found"
            fi
            ;;
        3)
            if [ -f examples/backend_consumer.js ]; then
                print_info "Starting Backend Consumer (Node.js)..."
                cd examples
                npm install
                node backend_consumer.js
            else
                print_error "Example file not found"
            fi
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

clean_all() {
    print_info "Removing all containers and volumes..."
    read -p "Are you sure? All data will be lost! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose down -v
        print_success "All containers and volumes removed"
    else
        print_info "Cancelled"
    fi
}

show_menu() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║     GPS Tracking RabbitMQ Broker Manager        ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo " 1) Start Broker"
    echo " 2) Stop Broker"
    echo " 3) Restart Broker"
    echo " 4) Show Logs"
    echo " 5) Show Status"
    echo " 6) Show Queues"
    echo " 7) Show Connections"
    echo " 8) Backup Configuration"
    echo " 9) Purge Queue"
    echo "10) Run Example"
    echo "11) Clean All (Delete volumes)"
    echo "12) Exit"
    echo ""
}

main() {
    clear
    check_docker
    check_docker_compose
    
    # Command line arguments
    if [ "$1" == "start" ]; then
        setup_env
        start_broker
        exit 0
    elif [ "$1" == "stop" ]; then
        stop_broker
        exit 0
    elif [ "$1" == "restart" ]; then
        restart_broker
        exit 0
    elif [ "$1" == "logs" ]; then
        show_logs
        exit 0
    elif [ "$1" == "status" ]; then
        show_status
        exit 0
    fi
    
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
            8) backup_config ;;
            9) purge_queue ;;
            10) run_example ;;
            11) clean_all ;;
            12) print_info "Goodbye!"; exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

main "$@"