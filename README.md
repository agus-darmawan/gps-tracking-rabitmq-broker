# Vehicle Tracking RabbitMQ Broker

A lightweight RabbitMQ message broker for vehicle rental systems with real-time GPS tracking and vehicle control.

## Quick Start

```bash
# 1. Setup environment
cp .env.example .env

# 2. Start broker
chmod +x setup.sh
./setup.sh start

# 3. Access management UI
# http://localhost:15672
# Username: admin
# Password: admin123
```

## Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Device    │ ──pub──>│  RabbitMQ   │ ──sub──>│   Backend   │
│  (Python)   │         │   Broker    │         │    (TS)     │
└─────────────┘         └─────────────┘         └─────────────┘
       │                       │                       │
       └───────────────sub─────┘                       │
                               └──────────pub──────────┘
```

## Message Queues

### Control Commands (Backend → Device)
- `vehicle.control.start_rent` - Start rental session
- `vehicle.control.end_rent` - End rental session  
- `vehicle.control.kill_vehicle` - Emergency engine disable

### Real-time Data (Device → Backend)
- `vehicle.realtime.location` - GPS coordinates
- `vehicle.realtime.status` - Vehicle status
- `vehicle.realtime.battery` - Battery level

### Reports (Device → Backend)
- `vehicle.report.maintenance` - Component health scores
- `vehicle.report.performance` - Trip performance metrics

## Users & Credentials

| User | Password | Purpose |
|------|----------|---------|
| admin | admin123 | Management |
| vehicle | vehicle123 | GPS Devices |
| backend | backend123 | Backend Services |

## Running the Examples

### 1. Start RabbitMQ Broker
```bash
./setup.sh start
```

### 2. Start Backend Server
```bash
cd examples/backend
npm install
npm run dev
# Server runs on http://localhost:3001
```

### 3. Simulate Device (Python)
```bash
cd examples/device
pip install -r requirements.txt
python publisher.py VEHICLE_001
```

### 4. Test with Postman
Import `postman_collection.json` and test the API endpoints.

## API Endpoints

### Get Vehicle Data
```bash
GET /api/location/VEHICLE_001
GET /api/status/VEHICLE_001
GET /api/battery/VEHICLE_001
GET /api/maintenance/VEHICLE_001
```

### Send Control Commands
```bash
POST /api/control/start_rent
Body: {"vehicle_id": "VEHICLE_001"}

POST /api/control/end_rent
Body: {"vehicle_id": "VEHICLE_001"}

POST /api/control/kill_vehicle
Body: {"vehicle_id": "VEHICLE_001"}
```

## Configuration

Edit `.env` file:
```bash
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=admin123
RABBITMQ_AMQP_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
RABBITMQ_MQTT_PORT=1883
```

## Management Commands

```bash
./setup.sh start      # Start broker
./setup.sh stop       # Stop broker
./setup.sh restart    # Restart broker
./setup.sh logs       # View logs
./setup.sh status     # Check status
```

## Monitoring

### Queue Status
```bash
docker exec tracking-rabbitmq-broker rabbitmqctl list_queues
```

### Active Connections
```bash
docker exec tracking-rabbitmq-broker rabbitmqctl list_connections
```

### Health Check
```bash
curl http://localhost:15672/api/health/checks/alarms
```

## Troubleshooting

**Broker won't start:**
```bash
# Check logs
docker-compose logs tracking-rabbitmq

# Check port conflicts
netstat -tulpn | grep 5672
```

**Connection refused:**
```bash
# Verify broker is running
docker ps | grep tracking-rabbitmq

# Test connection
./setup.sh test
```

## Tech Stack

- **Broker:** RabbitMQ 3.12
- **Backend:** Node.js + Express + TypeScript
- **Device Simulator:** Python 3.x
- **Protocol:** AMQP 0-9-1
