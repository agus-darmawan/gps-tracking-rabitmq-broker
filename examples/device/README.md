# Vehicle Device Simulator (Python)

Python script that simulates a GPS tracking device for testing the RabbitMQ broker and backend.

## 🚀 Features

- Publishes **real-time location**, **status**, **battery**, **maintenance**, and **performance reports**
- Listens for **control commands** (`start_rent`, `end_rent`, `kill_vehicle`)
- Simulates realistic **vehicle movement**
- Simple to run — no external dependencies beyond `pika`

---

## ⚙️ Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Or install pika directly
pip install pika==1.3.2
```

---

## 🧭 Usage

### Localhost Example
```bash
python publisher.py VEHICLE_001
```

### Remote Server
```bash
python3 publisher.py DK1142EMR  amqp://vehicle:vehicle123@103.175.219.138:5672
```

### Simulate Multiple Vehicles
```bash
python publisher.py VEHICLE_001
python publisher.py VEHICLE_002
python publisher.py VEHICLE_003
```

---

## 📡 Published Messages

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
  "front_tire": 85,
  "rear_tire": 82,
  "chain_cvt": 90,
  "engine_oil": 88,
  "battery": 92,
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

---

## 🕹️ Control Commands

| Command | Description |
|----------|--------------|
| `start_rent` | Unlocks vehicle and starts movement simulation |
| `end_rent` | Locks vehicle and publishes final report |
| `kill_vehicle` | Emergency stop — immediately locks vehicle |

---

## 🧪 Testing Flow

1. **Start the simulator**
   ```bash
   python publisher.py VEHICLE_001
   ```

2. **Send control commands**
   ```bash
   curl -X POST http://localhost:3001/api/control/start_rent -H "Content-Type: application/json" -d '{"vehicle_id": "VEHICLE_001"}'
   curl -X POST http://localhost:3001/api/control/end_rent -H "Content-Type: application/json" -d '{"vehicle_id": "VEHICLE_001"}'
   ```

3. **Check data in backend**
   ```bash
   curl http://localhost:3001/api/location/VEHICLE_001
   curl http://localhost:3001/api/status/VEHICLE_001
   curl http://localhost:3001/api/battery/VEHICLE_001
   ```

---

## 🧰 Troubleshooting

### Connection Refused
```bash
docker ps | grep rabbitmq
docker logs tracking-rabbitmq-broker
```

### Authentication Failed
```bash
# Verify credentials in .env
RABBITMQ_USER=vehicle
RABBITMQ_PASS=vehicle123
```

### No Messages Received
```bash
# Check RabbitMQ queue bindings at
http://localhost:15672
```

---

**Author:** Agus Darmawan  
**Project:** Vehicle Device Simulator  
**Version:** 1.0.0  
**License:** MIT
