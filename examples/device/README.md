# Vehicle Device Simulator (Python)

Python script that simulates a GPS tracking device for testing the RabbitMQ broker and backend.

## Features

- Publishes real-time location data (every 5 seconds)
- Publishes vehicle status (locked/active state)
- Publishes battery level and voltage
- Publishes maintenance reports (component health scores)
- Publishes performance reports (trip metrics)
- Listens for control commands (start_rent, end_rent, kill_vehicle)
- Simulates vehicle movement when active

## Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Or install pika directly
pip install pika==1.3.2
```

## Usage

### Basic Usage (localhost)
```bash
python publisher.py VEHICLE_001
```

### Remote Server
```bash
python publisher.py VEHICLE_001 amqp://vehicle:vehicle123@103.175.219.138:5672
```

### Multiple Vehicles
```bash
# Terminal 1
python publisher.py VEHICLE_001

# Terminal 2
python publisher.py VEHICLE_002

# Terminal 3
python publisher.py VEHICLE_003
```

## Published Messages

### Location (every 5 seconds)
```json
{
  "vehicle_id": "VEHICLE_001",
  "latitude": -6.208934,
  "longitude": 106.845678,
  "speed": 45.5,
  "heading": 180,
  "timestamp": "2025-10-30T10:30:00Z"
}
```

### Status (every 5 seconds)
```json
{
  "vehicle_id": "VEHICLE_001",
  "is_locked": false,
  "is_active": true,
  "speed": 45.5,
  "heading": 180,
  "timestamp": "2025-10-30T10:30:00Z"
}
```

### Battery (every 10 seconds)
```json
{
  "vehicle_id": "VEHICLE_001",
  "battery_level": 95.5,
  "voltage": 12.6,
  "timestamp": "2025-10-30T10:30:00Z"
}
```

### Maintenance Report (every 100 seconds)
```json
{
  "vehicle_id": "VEHICLE_001",
  "rental_id": "RENT_1730283000",
  "tire_front_left": 85,
  "tire_front_right": 87,
  "tire_rear_left": 82,
  "tire_rear_right": 84,
  "brake_pads": 75,
  "chain_cvt": 90,
  "engine_oil": 88,
  "battery": 92,
  "lights": 95,
  "spark_plug": 89,
  "overall_score": 86.7,
  "maintenance_required": false,
  "timestamp": "2025-10-30T10:30:00Z"
}
```

### Performance Report (on rental end)
```json
{
  "vehicle_id": "VEHICLE_001",
  "rental_id": "RENT_1730283000",
  "distance_travelled": 25.5,
  "average_speed": 35.8,
  "max_speed": 65.2,
  "fuel_efficiency": 20.5,
  "trip_duration_minutes": 45,
  "timestamp": "2025-10-30T10:30:00Z"
}
```

## Control Commands

The device listens and responds to these commands:

### Start Rental
- Command: `start_rent`
- Action: Unlocks vehicle, activates engine, starts movement simulation

### End Rental
- Command: `end_rent`
- Action: Locks vehicle, deactivates engine, stops movement, publishes final reports

### Emergency Stop
- Command: `kill_vehicle`
- Action: Immediately locks vehicle and stops engine

## Testing Flow

1. **Start the device simulator:**
   ```bash
   python publisher.py VEHICLE_001
   ```

2. **Send commands using the backend API:**
   ```bash
   # Start rental
   curl -X POST http://localhost:3001/api/control/start_rent \
     -H "Content-Type: application/json" \
     -d '{"vehicle_id": "VEHICLE_001"}'

   # End rental
   curl -X POST http://localhost:3001/api/control/end_rent \
     -H "Content-Type: application/json" \
     -d '{"vehicle_id": "VEHICLE_001"}'
   ```

3. **Check data in backend:**
   ```bash
   # Get location
   curl http://localhost:3001/api/location/VEHICLE_001

   # Get status
   curl http://localhost:3001/api/status/VEHICLE_001

   # Get battery
   curl http://localhost:3001/api/battery/VEHICLE_001
   ```

## Troubleshooting

**Connection Refused:**
```bash
# Check if RabbitMQ is running
docker ps | grep rabbitmq

# Check RabbitMQ logs
docker logs tracking-rabbitmq-broker
```

**Authentication Failed:**
```bash
# Verify credentials in .env file
# Default: vehicle:vehicle123
```

**No messages received:**
```bash
# Check queue bindings in RabbitMQ management UI
# http://localhost:15672
```