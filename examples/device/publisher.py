#!/usr/bin/env python3
"""
Vehicle GPS Device Simulator (Single Vehicle)
- Simulates location, status, and battery updates.
- Handles commands: start_rent, end_rent, kill_vehicle.
- Stores and reuses ORDER_ID between start/end rent.
"""

import pika
import json
import time
import random
import sys
from datetime import datetime, UTC


class VehicleDevice:
    def __init__(self, vehicle_id: str, rabbitmq_url: str):
        self.vehicle_id = vehicle_id
        self.rabbitmq_url = rabbitmq_url
        self.exchange = "vehicle.exchange"
        self.connection = None
        self.channel = None

        # State
        self.latitude = -6.2088 + random.uniform(-0.1, 0.1)
        self.longitude = 106.8456 + random.uniform(-0.1, 0.1)
        self.speed = 0.0
        self.heading = random.randint(0, 360)
        self.battery_level = random.uniform(85, 100)
        self.voltage = 12.6
        self.is_locked = True
        self.is_active = False
        self.kill_scheduled = False

        # Store order ID (for start_rent → end_rent continuity)
        self.order_id = None

    # ======================================
    # Connection
    # ======================================
    def connect(self):
        try:
            params = pika.URLParameters(self.rabbitmq_url)
            self.connection = pika.BlockingConnection(params)
            self.channel = self.connection.channel()
            print(f"✅ Connected to RabbitMQ as {self.vehicle_id}")
        except Exception as e:
            print(f"❌ Connection error: {e}")
            sys.exit(1)

    # ======================================
    # Utility
    # ======================================
    def utc_now(self) -> str:
        return datetime.now(UTC).isoformat()

    def publish(self, routing_key: str, message: dict):
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message),
        )

    # ======================================
    # Publishers
    # ======================================
    def publish_location(self):
        if self.is_active:
            self.latitude += random.uniform(-0.001, 0.001)
            self.longitude += random.uniform(-0.001, 0.001)
            self.heading = (self.heading + random.randint(-10, 10)) % 360
            self.speed = max(0.0, self.speed + random.uniform(-5, 5))
        else:
            self.speed = max(0.0, self.speed - random.uniform(1, 3))

        msg = {
            "vehicle_id": self.vehicle_id,
            "latitude": round(self.latitude, 6),
            "longitude": round(self.longitude, 6),
            "altitude": round(10 + random.uniform(-5, 5), 2),
            "timestamp": self.utc_now(),
        }
        self.publish(f"realtime.location.{self.vehicle_id}", msg)
        print(f"📍 Location: ({msg['latitude']}, {msg['longitude']})")

    def publish_status(self):
        msg = {
            "vehicle_id": self.vehicle_id,
            "is_active": self.is_active,
            "is_locked": self.is_locked,
            "is_killed": not self.is_active,
            "timestamp": self.utc_now(),
        }
        self.publish(f"realtime.status.{self.vehicle_id}", msg)
        print(f"🔒 Status: Active={self.is_active}, Locked={self.is_locked}")

    def publish_battery(self):
        if self.is_active:
            self.battery_level = max(0, self.battery_level - random.uniform(0.1, 0.3))
            self.voltage = 10.5 + (self.battery_level / 100) * 2.1

        msg = {
            "vehicle_id": self.vehicle_id,
            "device_voltage": round(self.voltage, 2),
            "device_battery_level": round(self.battery_level, 2),
            "timestamp": self.utc_now(),
        }
        self.publish(f"realtime.battery.{self.vehicle_id}", msg)
        print(f"🔋 Battery: {msg['device_battery_level']}% ({msg['device_voltage']}V)")

    def publish_performance_report(self):
        msg = {
            "vehicle_id": self.vehicle_id,
            "order_id": self.order_id,
            "weight_score": random.choice(["ringan", "sedang", "berat"]),
            "front_tire": random.randint(2000, 10000),
            "rear_tire": random.randint(2000, 10000),
            "brake_pad": random.randint(2000, 10000),
            "engine_oil": random.randint(2000, 10000),
            "chain_or_cvt": random.randint(2000, 10000),
            "engine": random.randint(2000, 10000),
            "distance_travelled": round(random.uniform(5, 50), 2),
            "average_speed": round(random.uniform(25, 45), 2),
            "max_speed": round(random.uniform(50, 80), 2),
            "timestamp": self.utc_now(),
        }
        self.publish(f"report.performance.{self.vehicle_id}", msg)
        print(f"📊 Performance report sent (order_id: {self.order_id})")

    # ======================================
    # Command Handling
    # ======================================
    def handle_command(self, ch, method, props, body):
        try:
            command = method.routing_key.split(".")[1]
            print(f"\n🎛️ Received command: {command}")

            try:
                data = json.loads(body)
            except:
                data = {}

            if command == "start_rent":
                self.is_locked = False
                self.is_active = True
                self.kill_scheduled = False
                self.speed = random.uniform(20, 40)
                self.order_id = data.get("order_id") or f"ORD-{self.vehicle_id}-{int(time.time())}"
                print(f"✅ Rent started (order_id: {self.order_id})")

            elif command == "end_rent":
                self.is_active = False
                self.is_locked = True
                self.publish_performance_report()
                print(f"✅ Rent ended (order_id: {self.order_id})")
                self.order_id = None

            elif command == "kill_vehicle":
                self.kill_scheduled = True
                print(f"⚠️ Kill scheduled (waiting speed < 10)...")

            ch.basic_ack(delivery_tag=method.delivery_tag)

        except Exception as e:
            print(f"❌ Command error: {e}")
            ch.basic_nack(delivery_tag=method.delivery_tag)

    def start_listening_commands(self):
        commands = ["start_rent", "end_rent", "kill_vehicle"]
        for cmd in commands:
            q_name = f"vehicle.control.{cmd}"
            rk = f"control.{cmd}.{self.vehicle_id}"
            try:
                self.channel.queue_declare(queue=q_name, durable=True, passive=True)
                self.channel.queue_bind(exchange=self.exchange, queue=q_name, routing_key=rk)
                self.channel.basic_consume(queue=q_name, on_message_callback=self.handle_command, auto_ack=False)
            except Exception as e:
                print(f"⚠️ Cannot bind queue {q_name}: {e}")
        print(f"👂 Listening for control commands...")

    # ======================================
    # Main Loop
    # ======================================
    def loop(self):
        self.connect()
        self.start_listening_commands()

        print(f"\n🚗 Vehicle Simulator started for {self.vehicle_id}\n")
        cycle = 0

        while True:
            try:
                self.connection.process_data_events(time_limit=0)
                self.publish_location()
                self.publish_status()
                if cycle % 2 == 0:
                    self.publish_battery()

                if self.kill_scheduled and self.speed < 10:
                    self.is_active = False
                    self.is_locked = True
                    self.kill_scheduled = False
                    print(f"💀 Kill executed (speed < 10)")

                cycle += 1
                time.sleep(5)

            except KeyboardInterrupt:
                print("\n⏹️ Stopping...")
                break
            except Exception as e:
                print(f"❌ Loop error: {e}")
                break

        if self.connection and not self.connection.is_closed:
            self.connection.close()
        print("👋 Disconnected")


# ======================================
# Entry Point
# ======================================
def main():
    if len(sys.argv) < 2:
        print("Usage: python publisher.py <VEHICLE_ID> [RABBITMQ_URL]")
        sys.exit(1)

    vehicle_id = sys.argv[1]
    rabbitmq_url = (
        sys.argv[2] if len(sys.argv) > 2 and sys.argv[2].startswith("amqp://")
        else "amqp://vehicle:vehicle123@103.175.219.138:5672"
    )

    device = VehicleDevice(vehicle_id, rabbitmq_url)
    device.loop()


if __name__ == "__main__":
    main()
