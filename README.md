# Vehicle Rental RabbitMQ Broker

A high-performance RabbitMQ message broker for vehicle rental systems, enabling real-time communication between backend servers and GPS tracking devices. Designed for scalable vehicle tracking, control commands, and maintenance reporting.

## 🏗️ Project Structure

```
vehicle-rental-rabbitmq/
├── docker-compose.yml           # Docker Compose configuration
├── .env.example                 # Environment template
├── setup.sh                     # Management script
├── config/
│   ├── rabbitmq.conf           # RabbitMQ configuration
│   └── definitions.json        # Pre-configured queues & exchanges
├── examples/
│   ├── backend-consumer.ts     # TypeScript backend consumer
│   ├── vehicle-publisher.ts    # Vehicle data publisher example
│   └── package.json            # Node.js dependencies
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
├── scripts/
│   ├── health-check.sh         # Health monitoring
│   └── backup.sh               # Backup utilities
└── README.md                   # This file
```

## 🚀 Quick Start

### 1. Environment Setup

```bash
# Clone and setup
git clone <your-repo>
cd vehicle-rental-rabbitmq

# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

### 2. Start the Broker

```bash
# Make script executable
chmod +x setup.sh

# Start broker
./setup.sh start

# Or using Docker directly
docker-compose up -d
```

### 3. Access Management Interface

Open [http://localhost:15672](http://localhost:15672)

**Default credentials:**
- Username: `admin`
- Password: `admin123`

### 4. Run Examples

```bash
cd examples
npm install

# Backend consumer
npm run dev:consumer

# Vehicle data publisher
npm run dev:publisher
```

## 🔧 Configuration

### Environment Variables (.env)

```bash
# RabbitMQ Authentication
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=admin123
RABBITMQ_DEFAULT_VHOST=/

# Port Configuration
RABBITMQ_AMQP_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
RABBITMQ_MQTT_PORT=1883

```

## 📦 Message Queues & Routing

### Control Commands (Backend → Vehicle)
| Queue | Purpose | Routing Key Pattern |
|-------|---------|-------------------|
| `vehicle.control.start_rental` | Start rental session | `control.start_rental.{vehicle_id}` |
| `vehicle.control.end_rental` | End rental session | `control.end_rental.{vehicle_id}` |
| `vehicle.control.kill_engine` | Emergency engine disable | `control.kill_engine.{vehicle_id}` |
| `vehicle.control.unlock` | Unlock vehicle | `control.unlock.{vehicle_id}` |
| `vehicle.control.lock` | Lock vehicle | `control.lock.{vehicle_id}` |

### Real-time Data (Vehicle → Backend)
| Queue | Purpose | Routing Key Pattern |
|-------|---------|-------------------|
| `vehicle.realtime.location` | GPS coordinates | `realtime.location.{vehicle_id}` |
| `vehicle.realtime.status` | Engine & device status | `realtime.status.{vehicle_id}` |
| `vehicle.realtime.battery` | Battery levels | `realtime.battery.{vehicle_id}` |
| `vehicle.realtime.speed` | Current speed | `realtime.speed.{vehicle_id}` |

### Maintenance Reports (Vehicle → Backend)
| Queue | Purpose | Routing Key Pattern |
|-------|---------|-------------------|
| `vehicle.report.maintenance` | Component condition scores | `report.maintenance.{vehicle_id}` |
| `vehicle.report.performance` | Trip performance metrics | `report.performance.{vehicle_id}` |
| `vehicle.report.tire_condition` | Front & rear tire status | `report.tire_condition.{vehicle_id}` |

### System Queues
| Queue | Purpose |
|-------|---------|
| `vehicle.dlq` | Dead letter queue for failed messages |
| `vehicle.alerts` | System alerts and notifications |

## 🔑 User Roles & Permissions

### Administrator (`admin`)
- **Password:** `admin123`
- **Permissions:** Full access to all resources
- **Usage:** System management and monitoring

### GPS Device (`vehicle`)
- **Password:** `vehicle123`
- **Permissions:** 
  - **Publish:** realtime data, maintenance reports
  - **Subscribe:** control commands
- **Usage:** GPS tracking devices

### Backend Service (`backend`)
- **Password:** `backend123`
- **Permissions:**
  - **Publish:** control commands
  - **Subscribe:** realtime data, reports
- **Usage:** Backend APIs and services

## 💻 Code Examples

### Backend Consumer (TypeScript)

```typescript
import { VehicleDataConsumer } from './examples/backend-consumer'

const consumer = new VehicleDataConsumer({
  url: 'amqp://backend_service:backend_secure_2024@localhost:5672',
  prefetch: 10
})

await consumer.connect()
await consumer.startConsuming()
```

### Publish Control Command

```typescript
import { VehicleController } from './examples/vehicle-controller'

const controller = new VehicleController()
await controller.connect()

// Start rental
await controller.startRental('VEHICLE_001', {
  rental_id: 'RENT_12345',
  user_id: 'USER_789',
  duration_minutes: 60
})

// Kill engine in emergency
await controller.killEngine('VEHICLE_001', {
  reason: 'emergency_stop',
  operator_id: 'ADMIN_001'
})
```

### Vehicle Data Publisher

```typescript
import { VehicleDataPublisher } from './examples/vehicle-publisher'

const publisher = new VehicleDataPublisher('VEHICLE_001')
await publisher.connect()

// Send location update
await publisher.publishLocation({
  latitude: -6.2088,
  longitude: 106.8456,
  speed: 45.5,
  heading: 180
})

// Send maintenance report
await publisher.publishMaintenanceReport({
  rental_id: 'RENT_12345',
  tire_front_left: 85,
  tire_front_right: 87,
  tire_rear_left: 82,
  tire_rear_right: 84,
  brake_pads: 75,
  chain_cvt: 90,
  engine_oil: 88,
  battery: 92,
  lights: 95,
  spark_plug: 89
})
```

## 🏭 Data Models

### Maintenance Report Schema
```typescript
interface MaintenanceReport {
  vehicle_id: string
  rental_id: string
  timestamp: string
  
  // Tire condition (0-100 score)
  tire_front_left: number
  tire_front_right: number
  tire_rear_left: number
  tire_rear_right: number
  
  // Component scores (0-100)
  brake_pads: number
  chain_cvt: number
  engine_oil: number
  battery: number
  lights: number
  spark_plug: number
  
  // Overall scores
  overall_score: number
  maintenance_required: boolean
}
```

### Location Data Schema
```typescript
interface LocationData {
  vehicle_id: string
  timestamp: string
  latitude: number
  longitude: number
  speed: number        // km/h
  heading: number      // degrees
  altitude?: number    // meters
  accuracy?: number    // meters
}
```

## 🛠️ Management Commands

### Using Setup Script

```bash
./setup.sh start      # Start broker
./setup.sh stop       # Stop broker
./setup.sh restart    # Restart broker
./setup.sh logs       # View logs
./setup.sh status     # Check status
./setup.sh backup     # Backup configuration
./setup.sh health     # Health check
```

### Direct Docker Commands

```bash
# View real-time logs
docker-compose logs -f

# Execute RabbitMQ commands
docker exec vehicle-rabbitmq rabbitmqctl list_queues
docker exec vehicle-rabbitmq rabbitmqctl list_connections
docker exec vehicle-rabbitmq rabbitmqctl list_consumers

# Performance monitoring
docker exec vehicle-rabbitmq rabbitmqctl status
```

## 📊 Monitoring & Health Checks

### Queue Metrics
```bash
# Queue statistics
docker exec vehicle-rabbitmq rabbitmqctl list_queues name messages consumers

# Message rates
docker exec vehicle-rabbitmq rabbitmqctl list_queues name message_stats.publish_details.rate

# Connection status
docker exec vehicle-rabbitmq rabbitmqctl list_connections name peer_host state
```

### Health Monitoring Script
```bash
# Run health check
./scripts/health-check.sh

# Expected output:
# ✅ RabbitMQ is running
# ✅ All queues are responding
# ✅ Memory usage: 45%
# ✅ Disk space: 78% available
```

## 🚀 Deployment & CI/CD

### VPS Deployment

The project includes GitHub Actions workflow for automatic deployment to VPS:

1. **Push to main branch** → Triggers CI/CD
2. **Build & Test** → Validates configuration
3. **Deploy to VPS** → Updates production environment
4. **Health Check** → Verifies deployment success

### Environment Setup for VPS

```bash
# Production environment
cp .env.example .env.production

# Update for production
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=YOUR_SECURE_PASSWORD
RABBITMQ_MEMORY_LIMIT=0.8
RABBITMQ_LOG_LEVEL=warning
```

## 🔍 Troubleshooting

### Common Issues

**Broker won't start**
```bash
# Check logs
docker-compose logs vehicle-rabbitmq

# Check port conflicts
netstat -tulpn | grep :5672
```

**High memory usage**
```bash
# Adjust memory limit in config/rabbitmq.conf
vm_memory_high_watermark.relative = 0.4

# Restart broker
./setup.sh restart
```

**Messages not being consumed**
```bash
# Check consumer connections
docker exec vehicle-rabbitmq rabbitmqctl list_consumers

# Check dead letter queue
docker exec vehicle-rabbitmq rabbitmqctl list_queues | grep dlq
```

## 📈 Performance Optimization

### High Throughput Configuration

For production environments handling high message volumes:

```conf
# config/rabbitmq.conf
channel_max = 2047
frame_max = 131072
heartbeat = 60
vm_memory_high_watermark.relative = 0.8
collect_statistics_interval = 10000
```

### Consumer Optimization

```typescript
// Set appropriate prefetch for consumers
await channel.prefetch(50)

// Use multiple consumer instances
const consumerCount = 4
for (let i = 0; i < consumerCount; i++) {
  const consumer = new VehicleDataConsumer()
  await consumer.connect()
  await consumer.startConsuming()
}
```

## 📚 Documentation Links

- [RabbitMQ Official Documentation](https://www.rabbitmq.com/documentation.html)
- [AMQP 0-9-1 Protocol](https://www.amqp.org/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [TypeScript amqplib Guide](https://www.npmjs.com/package/amqplib)
