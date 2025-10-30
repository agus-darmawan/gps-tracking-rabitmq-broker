#!/usr/bin/env python3
"""
Vehicle GPS Device Simulator (Type-safe version)
Matches the defined TypeScript interfaces for backend/frontend consistency
"""

import pika
import json
import time
import random
import sys
from datetime import datetime


class VehicleDevice:
    def __init__(self, vehicle_id: str, rabbitmq_url: str = "amqp://vehicle:vehicle123@localhost:5672"):
        self.vehicle_id = vehicle_id
        self.rabbitmq_url = rabbitmq_url
        self.connection = None
        self.channel = None
        self.exchange = "vehicle.exchange"

        # Vehicle state
        self.latitude = -6.2088 + random.uniform(-0.1, 0.1)
        self.longitude = 106.8456 + random.uniform(-0.1, 0.1)
        self.speed = 0.0
        self.heading = random.randint(0, 360)
        self.battery_level = random.randint(85, 100)
        self.voltage = 12.6
        self.is_locked = True
        self.is_active = False

    # ==========================
    # RabbitMQ Connection
    # ==========================
    def connect(self):
        try:
            parameters = pika.URLParameters(self.rabbitmq_url)
            self.connection = pika.BlockingConnection(parameters)
            self.channel = self.connection.channel()
            print(f"✅ Connected to RabbitMQ as vehicle device: {self.vehicle_id}")
            return True
        except Exception as e:
            print(f"❌ Failed to connect to RabbitMQ: {e}")
            return False

    # ==========================
    # Publishers
    # ==========================
    def publish_location(self):
        """Publish GPS location (VehicleLocation)"""
        if self.is_active:
            self.latitude += random.uniform(-0.001, 0.001)
            self.longitude += random.uniform(-0.001, 0.001)
            self.speed = random.uniform(20, 60)
            self.heading = (self.heading + random.randint(-10, 10)) % 360
        else:
            self.speed = 0.0

        message = {
            "vehicle_id": self.vehicle_id,
            "latitude": round(self.latitude, 6),
            "longitude": round(self.longitude, 6),
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }

        routing_key = f"realtime.location.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message),
        )
        print(f"📍 Location: ({message['latitude']}, {message['longitude']})")

    def publish_status(self):
        """Publish status (VehicleStatus)"""
        message = {
            "vehicle_id": self.vehicle_id,
            "is_locked": self.is_locked,
            "is_active": self.is_active,
            "speed": round(self.speed, 2),
            "heading": self.heading,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }

        routing_key = f"realtime.status.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message),
        )
        print(f"🔒 Status: Locked={self.is_locked}, Active={self.is_active}")

    def publish_battery(self):
        """Publish battery (VehicleBattery)"""
        if self.is_active:
            self.battery_level = max(0, self.battery_level - random.uniform(0.1, 0.3))
            self.voltage = 10.5 + (self.battery_level / 100) * 2.1

        message = {
            "vehicle_id": self.vehicle_id,
            "battery_level": round(self.battery_level, 2),
            "voltage": round(self.voltage, 2),
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }

        routing_key = f"realtime.battery.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message),
        )
        print(f"🔋 Battery: {message['battery_level']}% ({message['voltage']}V)")

    def publish_maintenance_report(self):
        """Publish maintenance report (MaintenanceReport)"""
        possible_issues = [
            "low tire pressure", "worn brake pads", "low engine oil", "dim lights",
            "old spark plug", "loose chain", "weak battery"
        ]
        detected = random.sample(possible_issues, random.randint(0, 3))

        recommendations = {
            "low tire pressure": "inflate tires to recommended PSI",
            "worn brake pads": "replace front and rear brake pads",
            "low engine oil": "refill engine oil to full mark",
            "dim lights": "check and replace bulbs if needed",
            "old spark plug": "replace spark plugs",
            "loose chain": "adjust and lubricate chain",
            "weak battery": "check battery health or replace"
        }

        recommended = [recommendations[i] for i in detected]

        message = {
            "vehicle_id": self.vehicle_id,
            "issues_detected": detected,
            "recommended_maintenance": recommended,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }

        routing_key = f"report.maintenance.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message),
        )

        if detected:
            print(f"🔧 Maintenance issues: {detected}")
        else:
            print("✅ No maintenance issues detected")

    def publish_performance_report(self):
        """Publish trip performance report (PerformanceReport)"""
        message = {
            "vehicle_id": self.vehicle_id,
            "distance_travelled": round(random.uniform(5, 50), 2),
            "average_speed": round(random.uniform(25, 45), 2),
            "max_speed": round(random.uniform(50, 80), 2),
            "fuel_efficiency": round(random.uniform(15, 25), 2),
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }

        routing_key = f"report.performance.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message),
        )
        print(f"📊 Performance: {message['distance_travelled']} km @ {message['average_speed']} km/h")

    # ==========================
    # Control Command Handler
    # ==========================
    def handle_control_command(self, ch, method, properties, body):
        try:
            command = method.routing_key.split(".")[1]
            print(f"\n🎛️  Received command: {command}")

            if command == "start_rent":
                self.is_locked = False
                self.is_active = True
                print(f"✅ Vehicle {self.vehicle_id} started")

            elif command == "end_rent":
                self.is_locked = True
                self.is_active = False
                self.speed = 0.0
                print(f"✅ Vehicle {self.vehicle_id} stopped")
                self.publish_maintenance_report()
                self.publish_performance_report()

            elif command == "kill_vehicle":
                self.is_locked = True
                self.is_active = False
                self.speed = 0.0
                print(f"🚨 Emergency stop executed for {self.vehicle_id}")

            ch.basic_ack(delivery_tag=method.delivery_tag)

        except Exception as e:
            print(f"❌ Error handling command: {e}")
            ch.basic_nack(delivery_tag=method.delivery_tag)

    # ==========================
    # Main Loop
    # ==========================
    def start_listening_commands(self):
        control_commands = ["start_rent", "end_rent", "kill_vehicle"]
        for command in control_commands:
            queue_name = f"vehicle.control.{command}"
            routing_key = f"control.{command}.{self.vehicle_id}"
            try:
                self.channel.queue_declare(queue=queue_name, durable=True, passive=True)
                self.channel.queue_bind(exchange=self.exchange, queue=queue_name, routing_key=routing_key)
                self.channel.basic_consume(queue=queue_name, on_message_callback=self.handle_control_command, auto_ack=False)
            except Exception as e:
                print(f"⚠️ Could not bind control queue {queue_name}: {e}")
        print("👂 Listening for control commands...")

    def run(self):
        if not self.connect():
            return

        self.start_listening_commands()
        print(f"\n🚗 Vehicle Simulator Started for {self.vehicle_id}\n")

        cycle_count = 0
        try:
            while True:
                self.connection.process_data_events(time_limit=0)
                self.publish_location()
                self.publish_status()

                if cycle_count % 2 == 0:
                    self.publish_battery()

                cycle_count += 1
                time.sleep(5)

        except KeyboardInterrupt:
            print(f"\n⏹️  Stopping vehicle {self.vehicle_id}...")
        finally:
            if self.connection and not self.connection.is_closed:
                self.connection.close()
            print(f"👋 Disconnected {self.vehicle_id}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python publisher.py <VEHICLE_ID> [RABBITMQ_URL]")
        sys.exit(1)

    vehicle_id = sys.argv[1]
    rabbitmq_url = sys.argv[2] if len(sys.argv) > 2 else "amqp://vehicle:vehicle123@localhost:5672"
    device = VehicleDevice(vehicle_id, rabbitmq_url)
    device.run()


if __name__ == "__main__":
    main()
