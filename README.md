# GPS Tracking RabbitMQ Broker

RabbitMQ message broker for GPS Protrack devices to communicate with backend servers. Designed for high-throughput GPS tracking data processing.

## 📁 Project Structure

```
tracking-rabbitmq-broker/
├── docker-compose.yml           # Docker Compose configuration
├── .env.example                 # Environment template
├── .gitignore                   # Git ignore rules
├── setup.sh                     # Management script
├── config/
│   ├── rabbitmq.conf           # RabbitMQ configuration
│   └── definitions.json        # Pre-configured queues & exchanges
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
- Username: `tracking_admin`
- Password: `tracking_secure_2024`

### 3. Run Examples

```bash
# GPS Device Simulator
cd examples
pip install -r requirements.txt
python3 gps_device_publisher.py

# Backend Consumer (Python)
python3 backend_consumer.py

# Backend Consumer (Node.js)
npm install
node backend_consumer.js
```

## 🔧 Configuration

Edit `.env` file:

```bash
RABBITMQ_DEFAULT_USER=tracking_admin
RABBITMQ_DEFAULT_PASS=tracking_secure_2024
RABBITMQ_AMQP_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
RABBITMQ_MQTT_PORT=1883
```

## 📦 Pre-configured Queues

### Location Data
- `gps.tracking.location.raw` - Raw GPS location data from devices
- `gps.tracking.location.processed` - Processed location data

### Alerts
- `gps.tracking.geofence.alert` - Geofence violation alerts
- `gps.tracking.speed.alert` - Speed limit violation alerts

### Device Management
- `gps.tracking.device.status` - Device status updates

### Trip Management
- `gps.tracking.trip.start` - Trip start events
- `gps.tracking.trip.end` - Trip end events

### System
- `gps.tracking.dlq` - Dead letter queue for failed messages

## 🔑 Users & Permissions

### 1. `tracking_admin`
- **Role:** Administrator
- **Permissions:** Full access to all resources
- **Usage:** Management and monitoring

### 2. `gps_device`
- **Role:** GPS Device Publisher
- **Permissions:** Write only to `gps.tracking.*` queues
- **Usage:** GPS devices sending data
- **Password:** `gps_device_password`

### 3. `backend_consumer`
- **Role:** Backend Consumer
- **Permissions:** Read only from `gps.tracking.*` queues
- **Usage:** Backend services consuming data
- **Password:** `backend_consumer_password`

## 📡 Routing Keys

### Location Data
- `location.raw.{device_id}` → `gps.tracking.location.raw`
- `location.processed.{device_id}` → `gps.tracking.location.processed`

### Alerts
- `alert.geofence.{device_id}` → `gps.tracking.geofence.alert`
- `alert.speed.{device_id}` → `gps.tracking.speed.alert`

### Device Status
- `device.status.{device_id}` → `gps.tracking.device.status`

### Trip Events
- `trip.start.{device_id}` → `gps.tracking.trip.start`
- `trip.end.{device_id}` → `gps.tracking.trip.end`

## 💻 Code Examples
### Backend Consumer (Node.js)

```javascript
const amqp = require('amqplib');

async function consume() {
    const connection = await amqp.connect(
        'amqp://backend_consumer:backend_consumer_password@localhost:5672'
    );
    const channel = await connection.createChannel();
    
    await channel.prefetch(10);
    
    channel.consume('gps.tracking.location.raw', async (msg) => {
        const data = JSON.parse(msg.content.toString());
        console.log(`Received location from ${data.device_id}`);
        
        // Process data here
        
        channel.ack(msg);
    });
}

consume();
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
docker exec tracking-rabbitmq-broker rabbitmqctl list_queues
docker exec tracking-rabbitmq-broker rabbitmqctl list_connections
docker exec tracking-rabbitmq-broker rabbitmqctl list_consumers
```

## 📊 Monitoring

### Queue Statistics

```bash
docker exec tracking-rabbitmq-broker rabbitmqctl list_queues name messages consumers
```

### Connection Status

```bash
docker exec tracking-rabbitmq-broker rabbitmqctl list_connections name peer_host peer_port state
```

### Memory Usage

```bash
docker exec tracking-rabbitmq-broker rabbitmqctl status
```

## 🔐 Security Best Practices

1. **Change default passwords** in `.env` file
2. **Use separate credentials** for each service
3. **Enable SSL/TLS** for production
4. **Implement rate limiting** on producers
5. **Monitor failed messages** in DLQ
6. **Set up alerts** for queue thresholds

## 🎯 Message Flow

```
GPS Device → MQTT/AMQP → RabbitMQ Exchange → Queues → Backend Consumers
                              ↓
                       gps.tracking.exchange
                              ↓
        ┌────────────────────┼────────────────────┐
        ↓                    ↓                    ↓
   location.raw      geofence.alert       speed.alert
        ↓                    ↓                    ↓
    Database            Notification        Notification
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

### Queue messages not being consumed

1. Check consumer is connected
2. Verify credentials and permissions
3. Check queue bindings
4. Review consumer logs

### High memory usage

Edit `config/rabbitmq.conf`:
```conf
vm_memory_high_watermark.relative = 0.4
```

## 🔄 Backup & Restore

### Backup

```bash
docker exec tracking-rabbitmq-broker rabbitmqctl export_definitions /tmp/backup.json
docker cp tracking-rabbitmq-broker:/tmp/backup.json ./backup.json
```

### Restore

```bash
docker cp backup.json tracking-rabbitmq-broker:/tmp/
docker exec tracking-rabbitmq-broker rabbitmqctl import_definitions /tmp/backup.json
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

### Consumer Optimization

- Set appropriate prefetch count (10-50)
- Use multiple consumer instances
- Implement batch processing
- Monitor consumer lag

## 📚 Documentation

- [RabbitMQ Docs](https://www.rabbitmq.com/documentation.html)
- [AMQP Protocol](https://www.amqp.org/)
- [MQTT Plugin](https://www.rabbitmq.com/mqtt.html)
- [Pika (Python)](https://pika.readthedocs.io/)
- [amqplib (Node.js)](https://www.squaremobius.net/amqp.node/)