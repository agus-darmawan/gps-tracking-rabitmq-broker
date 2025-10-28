#!/bin/bash

# Vehicle Rental RabbitMQ Broker - Management Script
# Comprehensive management tool for the vehicle rental messaging system

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Status indicators
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
print_header() { echo -e "${BLUE}$1${NC}"; }
print_subheader() { echo -e "${PURPLE}$1${NC}"; }

# Configuration
CONTAINER_NAME="vehicle-rabbitmq-broker"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"
BACKUP_DIR="backups"

# Utility functions
check_requirements() {
    print_info "Checking system requirements..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        echo "  Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker found: $(docker --version | cut -d' ' -f3)"
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        echo "  Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose found: $(docker-compose --version | cut -d' ' -f3)"
}

setup_environment() {
    print_info "Setting up environment configuration..."
    
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example "$ENV_FILE"
            print_success "Environment file created from template"
            print_warning "Please review and update $ENV_FILE with your settings"
        else
            print_error ".env.example template not found"
            exit 1
        fi
    else
        print_info "Environment file already exists"
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    print_success "Backup directory ready: $BACKUP_DIR"
}

start_broker() {
    print_header "Starting Vehicle Rental RabbitMQ Broker"
    print_info "Initializing message broker services..."
    
    # Check if already running
    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_warning "RabbitMQ broker is already running"
        show_connection_info
        return 0
    fi
    
    # Clean up any existing stopped containers
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    # Validate configuration files
    print_info "Validating configuration files..."
    if [ ! -f "config/definitions.json" ]; then
        print_error "Missing config/definitions.json file"
        return 1
    fi
    
    # Check if definitions.json is valid JSON
    if ! python3 -m json.tool config/definitions.json > /dev/null 2>&1; then
        print_error "Invalid JSON in config/definitions.json"
        return 1
    fi
    
    # Start services with fallback strategy
    print_info "Starting RabbitMQ with basic configuration..."
    
    if ! docker-compose up -d; then
        print_error "Failed to start with main configuration, trying minimal setup..."
        
        # Fallback to minimal configuration
        if [ -f "docker-compose.minimal.yml" ]; then
            print_info "Using minimal configuration as fallback..."
            docker-compose -f docker-compose.minimal.yml up -d
        else
            print_error "No fallback configuration available"
            return 1
        fi
    fi
    
    print_info "Waiting for RabbitMQ to initialize..."
    
    # Extended wait with progress indicator
    local wait_time=0
    local max_wait=120
    
    while [ $wait_time -lt $max_wait ]; do
        if docker ps | grep -q "$CONTAINER_NAME"; then
            if docker exec "$CONTAINER_NAME" rabbitmq-diagnostics ping &>/dev/null; then
                break
            fi
        fi
        
        printf "."
        sleep 2
        wait_time=$((wait_time + 2))
    done
    echo ""
    
    # Health check with detailed diagnostics
    if check_broker_health; then
        print_success "RabbitMQ broker started successfully"
        show_connection_info
        show_queue_summary
        
        # Additional validation
        print_info "Running post-startup validation..."
        docker exec "$CONTAINER_NAME" rabbitmqctl status > /dev/null && print_success "Node status: OK"
        docker exec "$CONTAINER_NAME" rabbitmqctl list_queues > /dev/null && print_success "Queues accessible"
        
    else
        print_error "RabbitMQ broker failed to start properly"
        print_info "Checking logs for errors..."
        echo ""
        print_subheader "Recent logs:"
        docker-compose logs --tail=20 vehicle-rabbitmq
        echo ""
        print_subheader "Container status:"
        docker ps -a | grep "$CONTAINER_NAME"
        
        print_info "Troubleshooting suggestions:"
        echo "  1. Check TROUBLESHOOTING.md for configuration issues"
        echo "  2. Try: docker-compose down -v && docker-compose up -d"
        echo "  3. Use minimal setup: docker-compose -f docker-compose.minimal.yml up -d"
        echo "  4. Check available disk space and memory"
        
        return 1
    fi
}

stop_broker() {
    print_header "Stopping Vehicle Rental RabbitMQ Broker"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_warning "RabbitMQ broker is not running"
        return 0
    fi
    
    print_info "Gracefully shutting down broker..."
    docker-compose down
    print_success "Broker stopped successfully"
}

restart_broker() {
    print_header "Restarting Vehicle Rental RabbitMQ Broker"
    stop_broker
    sleep 3
    start_broker
}

check_broker_health() {
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec "$CONTAINER_NAME" rabbitmq-diagnostics ping &> /dev/null; then
            return 0
        fi
        
        print_info "Health check attempt $attempt/$max_attempts..."
        sleep 3
        ((attempt++))
    done
    
    return 1
}

show_connection_info() {
    local mgmt_port=$(grep RABBITMQ_MANAGEMENT_PORT "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
    local amqp_port=$(grep RABBITMQ_AMQP_PORT "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
    local user=$(grep RABBITMQ_DEFAULT_USER "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
    
    echo ""
    print_header "════════════════════════════════════════════════════════════"
    print_header "    Vehicle Rental RabbitMQ Broker - Connection Info        "
    print_header "════════════════════════════════════════════════════════════"
    echo ""
    echo "🌐 Management Interface:  http://localhost:${mgmt_port:-15672}"
    echo "👤 Username:              ${user:-admin}"
    echo "🔑 Password:              (check $ENV_FILE file)"
    echo ""
    echo "📡 Connection Ports:"
    echo "   • AMQP:                ${amqp_port:-5672}"
    echo "   • Management:          ${mgmt_port:-15672}"
    echo "   • MQTT:                1883"
    echo ""
    echo "🔗 Connection URLs:"
    echo "   • Backend Service:     amqp://backend_service:backend_secure_2024@localhost:${amqp_port:-5672}"
    echo "   • GPS Devices:         amqp://gps_device:gps_secure_2024@localhost:${amqp_port:-5672}"
    echo ""
}

show_logs() {
    print_header "RabbitMQ Broker Logs"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "RabbitMQ broker is not running"
        return 1
    fi
    
    print_info "Showing real-time logs (Press Ctrl+C to exit)..."
    docker-compose logs -f --tail=50 vehicle-rabbitmq
}

show_status() {
    print_header "Vehicle Rental RabbitMQ Status"
    
    # Container status
    print_subheader "Container Status:"
    docker-compose ps
    echo ""
    
    if docker ps | grep -q "$CONTAINER_NAME"; then
        # RabbitMQ status
        print_subheader "RabbitMQ Node Status:"
        docker exec "$CONTAINER_NAME" rabbitmqctl node_health_check
        echo ""
        
        # Memory and disk usage
        print_subheader "Resource Usage:"
        docker exec "$CONTAINER_NAME" rabbitmqctl status | grep -E "(Memory|Disk|Erlang)"
        echo ""
        
        # User information
        print_subheader "User Accounts:"
        docker exec "$CONTAINER_NAME" rabbitmqctl list_users
        echo ""
        
    else
        print_warning "RabbitMQ broker is not running"
    fi
}

show_queues() {
    print_header "Message Queue Status"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "RabbitMQ broker is not running"
        return 1
    fi
    
    print_subheader "Queue Overview:"
    docker exec "$CONTAINER_NAME" rabbitmqctl list_queues name messages consumers message_stats.publish_details.rate | \
        column -t -s $'\t'
    echo ""
    
    print_subheader "Exchange Bindings:"
    docker exec "$CONTAINER_NAME" rabbitmqctl list_bindings source_name destination_name routing_key | \
        grep -v "^$" | column -t -s $'\t'
}

show_queue_summary() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        return 1
    fi
    
    print_subheader "Pre-configured Queues:"
    echo "  Control Commands:"
    echo "    • vehicle.control.start_rental    - Start rental sessions"
    echo "    • vehicle.control.end_rental      - End rental sessions"
    echo "    • vehicle.control.kill_engine     - Emergency engine control"
    echo "    • vehicle.control.lock            - Vehicle lock commands"
    echo "    • vehicle.control.unlock          - Vehicle unlock commands"
    echo ""
    echo "  Real-time Data:"
    echo "    • vehicle.realtime.location       - GPS coordinates"
    echo "    • vehicle.realtime.status         - Vehicle status updates"
    echo "    • vehicle.realtime.battery        - Battery monitoring"
    echo "    • vehicle.realtime.speed          - Speed monitoring"
    echo ""
    echo "  Reports:"
    echo "    • vehicle.report.maintenance      - Component condition"
    echo "    • vehicle.report.performance      - Trip performance"
    echo "    • vehicle.report.tire_condition   - Tire monitoring (front/rear)"
    echo ""
    echo "  System:"
    echo "    • vehicle.alerts                  - System notifications"
    echo "    • vehicle.dlq                     - Failed messages"
    echo ""
}

show_connections() {
    print_header "Active Connections"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "RabbitMQ broker is not running"
        return 1
    fi
    
    print_subheader "Client Connections:"
    docker exec "$CONTAINER_NAME" rabbitmqctl list_connections name peer_host peer_port state user | \
        column -t -s $'\t'
    echo ""
    
    print_subheader "Active Consumers:"
    docker exec "$CONTAINER_NAME" rabbitmqctl list_consumers queue_name consumer_tag | \
        column -t -s $'\t'
}

backup_configuration() {
    print_header "Backing Up Configuration"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "RabbitMQ broker is not running"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/rabbitmq_backup_$timestamp.json"
    
    print_info "Creating configuration backup..."
    docker exec "$CONTAINER_NAME" rabbitmqctl export_definitions /tmp/backup.json
    docker cp "$CONTAINER_NAME:/tmp/backup.json" "$backup_file"
    
    print_success "Backup saved: $backup_file"
    
    # Clean old backups (keep last 10)
    ls -t "$BACKUP_DIR"/rabbitmq_backup_*.json 2>/dev/null | tail -n +11 | xargs -r rm
    print_info "Old backups cleaned (keeping last 10)"
}

restore_configuration() {
    print_header "Restoring Configuration"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "RabbitMQ broker is not running"
        return 1
    fi
    
    # List available backups
    print_subheader "Available Backups:"
    ls -la "$BACKUP_DIR"/rabbitmq_backup_*.json 2>/dev/null | nl
    echo ""
    
    read -p "Enter backup file name (or press Enter to cancel): " backup_file
    
    if [ -z "$backup_file" ]; then
        print_info "Restore cancelled"
        return 0
    fi
    
    if [ ! -f "$BACKUP_DIR/$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    print_warning "This will overwrite current configuration!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Restore cancelled"
        return 0
    fi
    
    docker cp "$BACKUP_DIR/$backup_file" "$CONTAINER_NAME:/tmp/restore.json"
    docker exec "$CONTAINER_NAME" rabbitmqctl import_definitions /tmp/restore.json
    
    print_success "Configuration restored from: $backup_file"
}

# Start broker with minimal configuration
start_broker_minimal() {
    print_header "Starting RabbitMQ with Minimal Configuration"
    print_info "Using minimal setup for testing and troubleshooting..."
    
    # Stop any existing containers
    docker-compose down 2>/dev/null || true
    
    # Start with minimal config
    if [ -f "docker-compose.minimal.yml" ]; then
        docker-compose -f docker-compose.minimal.yml up -d
        
        print_info "Waiting for RabbitMQ to initialize..."
        sleep 20
        
        if check_broker_health; then
            print_success "RabbitMQ started with minimal configuration"
            show_connection_info
        else
            print_error "Failed to start even with minimal configuration"
            docker-compose -f docker-compose.minimal.yml logs --tail=20
        fi
    else
        print_error "Minimal configuration file not found"
    fi
}

# Start broker with production configuration
start_broker_production() {
    print_header "Starting RabbitMQ with Production Configuration"
    print_warning "This will use production settings and resource limits"
    
    if [ ! -f ".env.production" ]; then
        print_error "Production environment file (.env.production) not found"
        print_info "Please create .env.production with your production settings"
        return 1
    fi
    
    # Stop any existing containers
    docker-compose down 2>/dev/null || true
    
    # Start with production config
    if [ -f "docker-compose.production.yml" ]; then
        docker-compose -f docker-compose.production.yml up -d
        
        print_info "Waiting for RabbitMQ to initialize (production startup may take longer)..."
        sleep 30
        
        if check_broker_health; then
            print_success "RabbitMQ started with production configuration"
            show_connection_info
            
            # Additional production checks
            print_info "Running production health checks..."
            docker exec "$CONTAINER_NAME" rabbitmqctl status | grep -E "(Memory|Disk)" || true
        else
            print_error "Failed to start with production configuration"
            docker-compose -f docker-compose.production.yml logs --tail=20
        fi
    else
        print_error "Production configuration file not found"
    fi
}

# Fix configuration issues
fix_configuration() {
    print_header "Configuration Issue Fixer"
    print_info "Checking and fixing common configuration problems..."
    
    # Check for common issues
    local issues_found=0
    
    # Check definitions.json
    if [ -f "config/definitions.json" ]; then
        if ! python3 -m json.tool config/definitions.json > /dev/null 2>&1; then
            print_warning "Invalid JSON in config/definitions.json"
            issues_found=$((issues_found + 1))
        else
            print_success "definitions.json is valid"
        fi
    else
        print_error "Missing config/definitions.json"
        issues_found=$((issues_found + 1))
    fi
    
    # Check environment file
    if [ -f ".env" ]; then
        print_success ".env file exists"
        
        # Check for required variables
        if ! grep -q "RABBITMQ_DEFAULT_USER" .env; then
            print_warning "Missing RABBITMQ_DEFAULT_USER in .env"
            issues_found=$((issues_found + 1))
        fi
    else
        print_warning "No .env file found - using defaults"
    fi
    
    # Check Docker Compose syntax
    if docker-compose config > /dev/null 2>&1; then
        print_success "docker-compose.yml syntax is valid"
    else
        print_error "docker-compose.yml has syntax errors"
        issues_found=$((issues_found + 1))
    fi
    
    # Check for conflicting containers
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        print_info "Found existing container, cleaning up..."
        docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    fi
    
    # Summary
    echo ""
    if [ $issues_found -eq 0 ]; then
        print_success "No configuration issues found"
        print_info "Try starting the broker with: ./setup.sh start"
    else
        print_warning "Found $issues_found configuration issues"
        print_info "Review the messages above and fix the issues"
        print_info "You can also try the minimal configuration: ./setup.sh start-minimal"
    fi
    
    # Offer to view troubleshooting guide
    echo ""
    read -p "Would you like to view the troubleshooting guide? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "TROUBLESHOOTING.md" ]; then
            less TROUBLESHOOTING.md
        else
            print_info "Troubleshooting guide not found"
            print_info "Check README.md for troubleshooting information"
        fi
    fi
}

backup_configuration() {
    print_header "Backing Up Configuration"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "RabbitMQ broker is not running"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/rabbitmq_backup_$timestamp.json"
    
    print_info "Creating configuration backup..."
    docker exec "$CONTAINER_NAME" rabbitmqctl export_definitions /tmp/backup.json
    docker cp "$CONTAINER_NAME:/tmp/backup.json" "$backup_file"
    
    print_success "Backup saved: $backup_file"
    
    # Clean old backups (keep last 10)
    ls -t "$BACKUP_DIR"/rabbitmq_backup_*.json 2>/dev/null | tail -n +11 | xargs -r rm
    print_info "Old backups cleaned (keeping last 10)"
}

restore_configuration() {
    print_header "Restoring Configuration"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "RabbitMQ broker is not running"
        return 1
    fi
    
    # List available backups
    print_subheader "Available Backups:"
    ls -la "$BACKUP_DIR"/rabbitmq_backup_*.json 2>/dev/null | nl
    echo ""
    
    read -p "Enter backup file name (or press Enter to cancel): " backup_file
    
    if [ -z "$backup_file" ]; then
        print_info "Restore cancelled"
        return 0
    fi
    
    if [ ! -f "$BACKUP_DIR/$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    print_warning "This will overwrite current configuration!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Restore cancelled"
        return 0
    fi
    
    docker cp "$BACKUP_DIR/$backup_file" "$CONTAINER_NAME:/tmp/restore.json"
    docker exec "$CONTAINER_NAME" rabbitmqctl import_definitions /tmp/restore.json
    
    print_success "Configuration restored from: $backup_file"
}

purge_queue() {
    print_header "Purge Message Queue"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "RabbitMQ broker is not running"
        return 1
    fi
    
    print_subheader "Available Queues:"
    docker exec "$CONTAINER_NAME" rabbitmqctl list_queues name messages | column -t -s $'\t'
    echo ""
    
    read -p "Enter queue name to purge (or press Enter to cancel): " queue_name
    
    if [ -z "$queue_name" ]; then
        print_info "Purge cancelled"
        return 0
    fi
    
    print_warning "This will delete all messages in queue: $queue_name"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Purge cancelled"
        return 0
    fi
    
    docker exec "$CONTAINER_NAME" rabbitmqctl purge_queue "$queue_name"
    print_success "Queue purged: $queue_name"
}

run_examples() {
    print_header "Vehicle Rental Examples"
    
    cd examples 2>/dev/null || {
        print_error "Examples directory not found"
        return 1
    }
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        print_info "Installing dependencies..."
        npm install
    fi
    
    echo ""
    print_subheader "Available Examples:"
    echo "1) Full Demo (Consumer + Publisher Simulation)"
    echo "2) Backend Consumer Only"
    echo "3) Vehicle Data Publisher Only"
    echo "4) Control Commands Demo"
    echo "5) Install Dependencies Only"
    echo ""
    
    read -p "Select example (1-5): " example_choice
    
    case $example_choice in
        1)
            print_info "Starting full demo with simulation..."
            DEMO_MODE=true npm run dev
            ;;
        2)
            print_info "Starting backend consumer..."
            npm run dev:consumer
            ;;
        3)
            print_info "Starting vehicle data publisher..."
            npm run dev:publisher
            ;;
        4)
            print_info "Starting control commands demo..."
            npm run dev:control
            ;;
        5)
            print_info "Installing dependencies..."
            npm install
            print_success "Dependencies installed"
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    cd - > /dev/null
}

health_monitor() {
    print_header "RabbitMQ Health Monitor"
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "RabbitMQ broker is not running"
        return 1
    fi
    
    print_info "Monitoring broker health (Press Ctrl+C to stop)..."
    
    while true; do
        clear
        echo "$(date): RabbitMQ Health Status"
        echo "================================"
        
        # Node health
        if docker exec "$CONTAINER_NAME" rabbitmqctl node_health_check &> /dev/null; then
            print_success "Node Health: OK"
        else
            print_error "Node Health: FAILED"
        fi
        
        # Memory usage
        memory_info=$(docker exec "$CONTAINER_NAME" rabbitmqctl status | grep -A2 "Memory usage")
        echo "$memory_info"
        
        # Queue statistics
        echo ""
        echo "Queue Messages:"
        docker exec "$CONTAINER_NAME" rabbitmqctl list_queues name messages | head -10
        
        # Connection count
        conn_count=$(docker exec "$CONTAINER_NAME" rabbitmqctl list_connections | wc -l)
        echo ""
        echo "Active Connections: $((conn_count - 1))"
        
        sleep 10
    done
}

clean_all() {
    print_header "Clean All Data"
    print_warning "This will remove all containers, volumes, and data!"
    print_error "All message data will be permanently lost!"
    echo ""
    
    read -p "Are you absolutely sure? Type 'DELETE' to confirm: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    print_info "Removing all containers and volumes..."
    docker-compose down -v --remove-orphans
    
    # Remove any leftover containers
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    # Remove volumes
    docker volume rm $(docker volume ls -q | grep vehicle) 2>/dev/null || true
    
    print_success "All data removed"
}

show_menu() {
    clear
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           Vehicle Rental RabbitMQ Broker Manager            ║"
    echo "║                     Management Console                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo " 🚀 Broker Operations:"
    echo "  1) Start Broker (Standard)"
    echo "  2) Start Broker (Minimal Config)"
    echo "  3) Start Broker (Production)"
    echo "  4) Stop Broker"
    echo "  5) Restart Broker"
    echo "  6) Show Status"
    echo ""
    echo " 📊 Monitoring:"
    echo "  7) Show Logs"
    echo "  8) Show Queues"
    echo "  9) Show Connections"
    echo " 10) Health Monitor"
    echo ""
    echo " 🔧 Maintenance:"
    echo " 11) Backup Configuration"
    echo " 12) Restore Configuration"
    echo " 13) Purge Queue"
    echo " 14) Fix Configuration Issues"
    echo ""
    echo " 🎮 Development:"
    echo " 15) Health Check"
    echo ""
    echo " ⚠️  Danger Zone:"
    echo " 16) Clean All Data"
    echo ""
    echo " 17) Exit"
    echo ""
}

main() {
    # Check system requirements
    check_requirements
    
    # Handle command line arguments
    case "${1:-}" in
        "start")
            setup_environment
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
        "status")
            show_status
            exit 0
            ;;
        "logs")
            show_logs
            exit 0
            ;;
        "health")
            health_monitor
            exit 0
            ;;
        "backup")
            backup_configuration
            exit 0
            ;;
        "clean")
            clean_all
            exit 0
            ;;
        "--help"|"-h")
            echo "Vehicle Rental RabbitMQ Broker Management Script"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start     Start the broker"
            echo "  stop      Stop the broker"
            echo "  restart   Restart the broker"
            echo "  status    Show broker status"
            echo "  logs      Show broker logs"
            echo "  health    Monitor broker health"
            echo "  backup    Backup configuration"
            echo "  clean     Remove all data"
            echo "  --help    Show this help"
            echo ""
            echo "Run without arguments for interactive mode."
            exit 0
            ;;
    esac
    
    # Interactive menu mode
    while true; do
        show_menu
        read -p "Select option (1-18): " choice
        
        case $choice in
            1) setup_environment; start_broker ;;
            2) setup_environment; start_broker_minimal ;;
            3) setup_environment; start_broker_production ;;
            4) stop_broker ;;
            5) restart_broker ;;
            6) show_status ;;
            7) show_logs ;;
            8) show_queues ;;
            9) show_connections ;;
            10) health_monitor ;;
            11) backup_configuration ;;
            12) restore_configuration ;;
            13) purge_queue ;;
            14) fix_configuration ;;
            15) run_examples ;;
            16) check_broker_health && print_success "Health check passed" || print_error "Health check failed" ;;
            17) clean_all ;;
            18) print_info "Goodbye! 👋"; exit 0 ;;
            *) print_error "Invalid option. Please try again." ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"