# Vehicle Rental RabbitMQ Broker

RabbitMQ message broker for vehicle rental system to communicate between backend servers and GPS devices. Designed for high-throughput vehicle tracking and control data processing.

## 📁 Project Structure

```
rental-rabbitmq-broker/
├── docker-compose.yml           # Docker Compose configuration
├── .env.example                 # Environment template
├── .gitignore                   # Git ignore rules
├── setup.sh                     # Management script
├── config/
│   ├── rabbitmq.conf           # RabbitMQ configuration
│   └── definitions.json        # Pre-configured queues & exchanges
├── examples/
│   ├── backend-consumer.js     # Backend data consumer
│   └── package.json            # Node.js dependencies
└── README.md                    # This file
```

## 🚀 Quick Start

### 1. Start the Broker

```bash
# Using setup script (recommended)
chmod +x setup.sh
./setup.sh start

# Or manually
docker-compose up -d
```

### 2. Access Management UI

Open http://localhost:15672

**Default credentials:**
- Username: `admin`
- Password: `@dmin2510`

### 3. Run Backend Examples

```bash
# Install dependencies
cd examples
npm install

# Backend Consumer (receive device data)
node backend-consumer.js
```

## 🔧 Configuration

Edit `.env` file:

```bash
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=@dmin2510
RABBITMQ_AMQP_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
RABBITMQ_MQTT_PORT=1883
```

## 📦 Pre-configured Queues

### Control Messages (Backend → Device)
- `vehicle.control.start_rent` - Start rental command with vehicle ID
- `vehicle.control.end_rent` - End rental command with vehicle ID  
- `vehicle.control.kill_vehicle` - Kill/disable vehicle command with vehicle ID

### Realtime Data (Device → Backend)
- `vehicle.realtime.location` - GPS coordinates (lat, long)
- `vehicle.realtime.status` - Device status (kill status, device active/inactive)
- `vehicle.realtime.battery` - Battery voltage (device battery & vehicle battery)

### Rental Reports (Device → Backend)
- `vehicle.report.maintenance` - Maintenance data per rental (Ban, Rem, Rantai/CVT, Oli, Aki, Lampu, Busi)
- `vehicle.report.performance` - Performance data per rental (Skor Berat, Max Speed, Total Km)

### System
- `vehicle.dlq` - Dead letter queue for failed messages

## 🔑 Users & Permissions

### 1. `admin`
- **Role:** Administrator
- **Permissions:** Full access to all resources
- **Usage:** Management and monitoring
- **Password:** `@dmin2510`

### 2. `gps`
- **Role:** GPS Device Publisher/Consumer
- **Permissions:** Write realtime/report data, Read control messages
- **Usage:** GPS devices sending/receiving data
- **Password:** `9p5data`

### 3. `backend`
- **Role:** Backend Service
- **Permissions:** Write control messages, Read realtime/report data
- **Usage:** Backend services managing vehicles
- **Password:** `b@ckend`

## 📡 Routing Keys

### Control Messages
- `control.start_rent.{vehicle_id}` → `vehicle.control.start_rent`
- `control.end_rent.{vehicle_id}` → `vehicle.control.end_rent`
- `control.kill_vehicle.{vehicle_id}` → `vehicle.control.kill_vehicle`

### Realtime Data
- `realtime.location.{vehicle_id}` → `vehicle.realtime.location`
- `realtime.status.{vehicle_id}` → `vehicle.realtime.status`
- `realtime.battery.{vehicle_id}` → `vehicle.realtime.battery`

### Report Data
- `report.maintenance.{vehicle_id}` → `vehicle.report.maintenance`
- `report.performance.{vehicle_id}` → `vehicle.report.performance`

## 💻 Backend Code Examples

### Backend Consumer - Receive Device Data

```javascript
const amqp = require('amqplib');

class VehicleDataConsumer {
    constructor() {
        this.connection = null;
        this.channel = null;
    }

    async connect() {
        this.connection = await amqp.connect(
            'amqp://backend:b@ckend@localhost:5672'
        );
        this.channel = await this.connection.createChannel();
        
        // Set prefetch for better performance
        await this.channel.prefetch(10);
    }

    async consumeRealtimeLocation() {
        await this.channel.consume('vehicle.realtime.location', async (msg) => {
            try {
                const data = JSON.parse(msg.content.toString());
                console.log(`Location from ${data.vehicle_id}:`, {
                    lat: data.lat,
                    long: data.long,
                    timestamp: data.timestamp
                });

                // Process location data
                await this.processLocationData(data);
                
                this.channel.ack(msg);
            } catch (error) {
                console.error('Error processing location data:', error);
                this.channel.nack(msg, false, false); // Send to DLQ
            }
        });
    }

    async consumeRealtimeStatus() {
        await this.channel.consume('vehicle.realtime.status', async (msg) => {
            try {
                const data = JSON.parse(msg.content.toString());
                console.log(`Status from ${data.vehicle_id}:`, {
                    is_killed: data.is_killed,
                    device_active: data.device_active,
                    timestamp: data.timestamp
                });

                // Process status data
                await this.processStatusData(data);
                
                this.channel.ack(msg);
            } catch (error) {
                console.error('Error processing status data:', error);
                this.channel.nack(msg, false, false);
            }
        });
    }

    async consumeRealtimeBattery() {
        await this.channel.consume('vehicle.realtime.battery', async (msg) => {
            try {
                const data = JSON.parse(msg.content.toString());
                console.log(`Battery from ${data.vehicle_id}:`, {
                    device_voltage: data.device_voltage,
                    vehicle_voltage: data.vehicle_voltage,
                    timestamp: data.timestamp
                });

                // Process battery data
                await this.processBatteryData(data);
                
                this.channel.ack(msg);
            } catch (error) {
                console.error('Error processing battery data:', error);
                this.channel.nack(msg, false, false);
            }
        });
    }

    async consumeMaintenanceReport() {
        await this.channel.consume('vehicle.report.maintenance', async (msg) => {
            try {
                const data = JSON.parse(msg.content.toString());
                console.log(`Maintenance report from ${data.vehicle_id}:`, {
                    ban: data.ban,
                    rem: data.rem,
                    rantai_cvt: data.rantai_cvt,
                    oli: data.oli,
                    aki: data.aki,
                    lampu: data.lampu,
                    busi: data.busi,
                    rental_id: data.rental_id
                });

                // Process maintenance report
                await this.processMaintenanceReport(data);
                
                this.channel.ack(msg);
            } catch (error) {
                console.error('Error processing maintenance report:', error);
                this.channel.nack(msg, false, false);
            }
        });
    }

    async consumePerformanceReport() {
        await this.channel.consume('vehicle.report.performance', async (msg) => {
            try {
                const data = JSON.parse(msg.content.toString());
                console.log(`Performance report from ${data.vehicle_id}:`, {
                    skor_berat: data.skor_berat,
                    max_speed: data.max_speed,
                    total_km: data.total_km,
                    rental_id: data.rental_id
                });

                // Process performance report
                await this.processPerformanceReport(data);
                
                this.channel.ack(msg);
            } catch (error) {
                console.error('Error processing performance report:', error);
                this.channel.nack(msg, false, false);
            }
        });
    }

    // Processing methods
    async processLocationData(data) {
        // Save to database, update real-time dashboard, etc.
        console.log('Processing location data...');
    }

    async processStatusData(data) {
        // Update vehicle status, trigger alerts if killed, etc.
        console.log('Processing status data...');
    }

    async processBatteryData(data) {
        // Monitor battery levels, send low battery alerts, etc.
        console.log('Processing battery data...');
    }

    async processMaintenanceReport(data) {
        // Save maintenance scores, schedule maintenance if needed, etc.
        console.log('Processing maintenance report...');
    }

    async processPerformanceReport(data) {
        // Calculate rental performance scores, update analytics, etc.
        console.log('Processing performance report...');
    }

    async startConsuming() {
        await this.consumeRealtimeLocation();
        await this.consumeRealtimeStatus();
        await this.consumeRealtimeBattery();
        await this.consumeMaintenanceReport();
        await this.consumePerformanceReport();

        console.log('Backend consumer started, waiting for messages...');
    }

    async close() {
        if (this.channel) await this.channel.close();
        if (this.connection) await this.connection.close();
    }
}

// Usage example
async function main() {
    const consumer = new VehicleDataConsumer();
    await consumer.connect();
    await consumer.startConsuming();

    // Keep running
    process.on('SIGTERM', async () => {
        console.log('Shutting down consumer...');
        await consumer.close();
        process.exit(0);
    });
}

main().catch(console.error);
```

## 🛠️ Management Commands

### Using Setup Script

```bash
./setup.sh start      # Start broker
./setup.sh stop       # Stop broker
./setup.sh logs       # View logs
./setup.sh status     # Check status
./setup.sh            # Interactive menu
```

### Using Docker Commands

```bash
# View logs
docker-compose logs -f

# Check status
docker-compose ps

# Execute RabbitMQ commands
docker exec rental-rabbitmq-broker rabbitmqctl list_queues
docker exec rental-rabbitmq-broker rabbitmqctl list_connections
docker exec rental-rabbitmq-broker rabbitmqctl list_consumers
```

## 📊 Monitoring

### Queue Statistics

```bash
docker exec rental-rabbitmq-broker rabbitmqctl list_queues name messages consumers
```

### Connection Status

```bash
docker exec rental-rabbitmq-broker rabbitmqctl list_connections name peer_host peer_port state
```

### Memory Usage

```bash
docker exec rental-rabbitmq-broker rabbitmqctl status
```

## 🎯 Message Flow

```
Backend Service → RabbitMQ Exchange → Control Queues → GPS Devices
                        ↕
GPS Devices → RabbitMQ Exchange → Data Queues → Backend Service
                        ↓
              vehicle.exchange
                        ↓
        ┌───────────────┼───────────────┐
        ↓               ↓               ↓
   control.*       realtime.*      report.*
        ↓               ↓               ↓
   GPS Devices     Backend API     Analytics
```

## 🐛 Troubleshooting

### Broker won't start

```bash
docker-compose logs
docker volume ls
```

### Port already in use

Edit `.env`:
```bash
RABBITMQ_AMQP_PORT=5673
RABBITMQ_MANAGEMENT_PORT=15673
```

### Messages not being consumed

1. Check backend consumer is running
2. Verify credentials and permissions
3. Check queue bindings
4. Review consumer logs
5. Check dead letter queue for failed messages

### High memory usage

Edit `config/rabbitmq.conf`:
```conf
vm_memory_high_watermark.relative = 0.4
```

## 🔄 Backup & Restore

### Backup

```bash
docker exec rental-rabbitmq-broker rabbitmqctl export_definitions /tmp/backup.json
docker cp rental-rabbitmq-broker:/tmp/backup.json ./backup.json
```

### Restore

```bash
docker cp backup.json rental-rabbitmq-broker:/tmp/
docker exec rental-rabbitmq-broker rabbitmqctl import_definitions /tmp/backup.json
```

## 📈 Performance Tuning

### High Throughput Setup

```conf
# config/rabbitmq.conf
channel_max = 2047
frame_max = 131072
heartbeat = 60
vm_memory_high_watermark.relative = 0.6
```

### Backend Consumer Optimization

- Set appropriate prefetch count (10-50)
- Use multiple consumer instances
- Implement batch processing for reports
- Monitor consumer lag
- Use connection pooling for high load

## 📚 Documentation

- [RabbitMQ Docs](https://www.rabbitmq.com/documentation.html)
- [AMQP Protocol](https://www.amqp.org/)
- [amqplib (Node.js)](https://www.squaremobius.net/amqp.node/)
- [RabbitMQ Management Plugin](https://www.rabbitmq.com/management.html)