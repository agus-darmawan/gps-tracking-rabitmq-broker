#!/usr/bin/env python3
"""
Vehicle GPS Device Simulator (Type-safe, Multi-Vehicle Version)
- Realtime messages: location, status, battery
- Non-realtime (report): sent at end_rent
- Kill command: waits until speed < 10 before killing
"""

import pika
import json
import time
import random
import sys
import threading
from datetime import datetime


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
            print(f"❌ Connection error for {self.vehicle_id}: {e}")
            sys.exit(1)

    # ======================================
    # Publisher Methods
    # ======================================
    def publish(self, routing_key, message):
        """Helper publish function"""
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message),
        )

    def publish_location(self):
        if self.is_active:
            self.latitude += random.uniform(-0.001, 0.001)
            self.longitude += random.uniform(-0.001, 0.001)
            self.heading = (self.heading + random.randint(-10, 10)) % 360
            self.speed = max(0.0, self.speed + random.uniform(-5, 5))
        else:
            # gradually slow down
            self.speed = max(0.0, self.speed - random.uniform(1, 3))

        msg = {
            "vehicle_id": self.vehicle_id,
            "latitude": round(self.latitude, 6),
            "longitude": round(self.longitude, 6),
            "altitude": round(10 + random.uniform(-5, 5), 2),
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
        self.publish(f"realtime.location.{self.vehicle_id}", msg)
        print(f"📍 [{self.vehicle_id}] Location: ({msg['latitude']}, {msg['longitude']})")

    def publish_status(self):
        msg = {
            "vehicle_id": self.vehicle_id,
            "is_active": self.is_active,
            "is_kill_cmd_accepted": not self.is_active,
            "is_killed": not self.is_active,
            "is_tampered": random.choice([True, False]) if not self.is_active else False,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
        self.publish(f"realtime.status.{self.vehicle_id}", msg)
        print(f"🔒 [{self.vehicle_id}] Status: Active={self.is_active}, Locked={self.is_locked}")

    def publish_battery(self):
        if self.is_active:
            self.battery_level = max(0, self.battery_level - random.uniform(0.1, 0.3))
            self.voltage = 10.5 + (self.battery_level / 100) * 2.1

        msg = {
            "vehicle_id": self.vehicle_id,
            "device_voltage": round(self.voltage, 2),
            "device_battery_level": round(self.battery_level, 2),
            "vehicle_voltage": round(self.voltage, 2),
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
        self.publish(f"realtime.battery.{self.vehicle_id}", msg)
        print(f"🔋 [{self.vehicle_id}] Battery: {msg['device_battery_level']}% ({msg['vehicle_voltage']}V)")

    def publish_maintenance_report(self):
        msg = {
            "vehicle_id": self.vehicle_id,
            "weight_score": random.choice(["ringan", "sedang", "berat"]),
            "front_tire": random.randint(2000, 10000),
            "rear_tire": random.randint(2000, 10000),
            "brake_pad": random.randint(2000, 10000),
            "engine_oil": random.randint(2000, 10000),
            "chain_or_cvt": random.randint(2000, 10000),
            "engine": random.randint(2000, 10000),
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
        self.publish(f"report.maintenance.{self.vehicle_id}", msg)
        print(f"🧰 [{self.vehicle_id}] Maintenance report sent")

    def publish_performance_report(self):
        msg = {
            "vehicle_id": self.vehicle_id,
            "distance_travelled": round(random.uniform(5, 50), 2),
            "average_speed": round(random.uniform(25, 45), 2),
            "max_speed": round(random.uniform(50, 80), 2),
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
        self.publish(f"report.performance.{self.vehicle_id}", msg)
        print(f"📊 [{self.vehicle_id}] Performance report sent")

    # ======================================
    # Command Handling
    # ======================================
    def handle_command(self, ch, method, props, body):
        try:
            command = method.routing_key.split(".")[1]
            print(f"\n🎛️ [{self.vehicle_id}] Received command: {command}")

            if command == "start_rent":
                self.is_locked = False
                self.is_active = True
                self.kill_scheduled = False
                self.speed = random.uniform(20, 40)
                print(f"✅ [{self.vehicle_id}] Rent started")

            elif command == "end_rent":
                self.is_active = False
                self.is_locked = True
                self.publish_maintenance_report()
                self.publish_performance_report()
                print(f"✅ [{self.vehicle_id}] Rent ended")

            elif command == "kill_vehicle":
                # schedule kill instead of immediate
                self.kill_scheduled = True
                print(f"⚠️ [{self.vehicle_id}] Kill scheduled (waiting speed < 10)...")

            ch.basic_ack(delivery_tag=method.delivery_tag)

        except Exception as e:
            print(f"❌ Command error [{self.vehicle_id}]: {e}")
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
                print(f"⚠️ [{self.vehicle_id}] Cannot bind queue {q_name}: {e}")
        print(f"👂 [{self.vehicle_id}] Listening for control commands...")

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

                # check if kill scheduled
                if self.kill_scheduled and self.speed < 10:
                    self.is_active = False
                    self.is_locked = True
                    self.kill_scheduled = False
                    print(f"💀 [{self.vehicle_id}] Kill executed (speed < 10)")

                cycle += 1
                time.sleep(5)

            except KeyboardInterrupt:
                print(f"\n⏹️ [{self.vehicle_id}] Stopping...")
                break
            except Exception as e:
                print(f"❌ Loop error [{self.vehicle_id}]: {e}")
                break

        if self.connection and not self.connection.is_closed:
            self.connection.close()
        print(f"👋 [{self.vehicle_id}] Disconnected")


# ======================================
# Entry Point
# ======================================
def main():
    if len(sys.argv) < 2:
        print("Usage: python publisher.py <VEHICLE_ID> [<VEHICLE_ID_2> ...] [RABBITMQ_URL]")
        sys.exit(1)

    *vehicle_ids, last_arg = sys.argv[1:]
    # detect if last arg is URL
    if last_arg.startswith("amqp://"):
        rabbitmq_url = last_arg
        vehicle_ids = vehicle_ids[:-1]
    else:
        rabbitmq_url = "amqp://vehicle:vehicle123@103.175.219.138:5672"

    threads = []
    for vid in vehicle_ids:
        t = threading.Thread(target=VehicleDevice(vid, rabbitmq_url).loop, daemon=True)
        t.start()
        threads.append(t)

    print(f"🚀 Running {len(vehicle_ids)} vehicle simulators...")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Simulation stopped.")


if __name__ == "__main__":
    main()
