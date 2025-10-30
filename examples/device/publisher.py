#!/usr/bin/env python3
"""
Vehicle GPS Device Simulator
Simulates a GPS tracking device that publishes location, status, and battery data
Also listens for control commands from the backend
"""

import pika
import json
import time
import random
import sys
from datetime import datetime
from typing import Dict, Any

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
        self.is_renting = False
        
    def connect(self):
        """Connect to RabbitMQ"""
        try:
            parameters = pika.URLParameters(self.rabbitmq_url)
            self.connection = pika.BlockingConnection(parameters)
            self.channel = self.connection.channel()
            print(f"✅ Connected to RabbitMQ as vehicle device: {self.vehicle_id}")
            return True
        except Exception as e:
            print(f"❌ Failed to connect to RabbitMQ: {e}")
            return False
    
    def publish_location(self):
        """Publish GPS location data"""
        # Simulate vehicle movement if active
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
            "speed": round(self.speed, 2),
            "heading": self.heading,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        routing_key = f"realtime.location.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message)
        )
        print(f"📍 Location: ({message['latitude']}, {message['longitude']}) Speed: {message['speed']} km/h")
    
    def publish_status(self):
        """Publish vehicle status"""
        message = {
            "vehicle_id": self.vehicle_id,
            "is_locked": self.is_locked,
            "is_active": self.is_active,
            "speed": round(self.speed, 2),
            "heading": self.heading,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        routing_key = f"realtime.status.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message)
        )
        print(f"🔒 Status: Locked={self.is_locked}, Active={self.is_active}")
    
    def publish_battery(self):
        """Publish battery data"""
        # Simulate battery drain if active
        if self.is_active:
            self.battery_level = max(0, self.battery_level - random.uniform(0.1, 0.3))
            self.voltage = 10.5 + (self.battery_level / 100) * 2.1
        
        message = {
            "vehicle_id": self.vehicle_id,
            "battery_level": round(self.battery_level, 2),
            "voltage": round(self.voltage, 2),
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        routing_key = f"realtime.battery.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message)
        )
        print(f"🔋 Battery: {message['battery_level']}% ({message['voltage']}V)")
    
    def publish_maintenance_report(self):
        """Publish maintenance report with component health scores"""
        message = {
            "vehicle_id": self.vehicle_id,
            "rental_id": f"RENT_{int(time.time())}",
            "tire_front_left": random.randint(75, 95),
            "tire_front_right": random.randint(75, 95),
            "tire_rear_left": random.randint(75, 95),
            "tire_rear_right": random.randint(75, 95),
            "brake_pads": random.randint(70, 90),
            "chain_cvt": random.randint(80, 95),
            "engine_oil": random.randint(75, 92),
            "battery": random.randint(80, 95),
            "lights": random.randint(85, 98),
            "spark_plug": random.randint(75, 92),
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        # Calculate overall score
        components = [
            message["tire_front_left"], message["tire_front_right"],
            message["tire_rear_left"], message["tire_rear_right"],
            message["brake_pads"], message["chain_cvt"],
            message["engine_oil"], message["battery"],
            message["lights"], message["spark_plug"]
        ]
        message["overall_score"] = round(sum(components) / len(components), 2)
        message["maintenance_required"] = message["overall_score"] < 80
        
        routing_key = f"report.maintenance.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message)
        )
        print(f"🔧 Maintenance Report: Overall Score = {message['overall_score']}%")
    
    def publish_performance_report(self):
        """Publish trip performance report"""
        message = {
            "vehicle_id": self.vehicle_id,
            "rental_id": f"RENT_{int(time.time())}",
            "distance_travelled": round(random.uniform(5, 50), 2),
            "average_speed": round(random.uniform(25, 45), 2),
            "max_speed": round(random.uniform(50, 80), 2),
            "fuel_efficiency": round(random.uniform(15, 25), 2),
            "trip_duration_minutes": random.randint(15, 120),
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        routing_key = f"report.performance.{self.vehicle_id}"
        self.channel.basic_publish(
            exchange=self.exchange,
            routing_key=routing_key,
            body=json.dumps(message)
        )
        print(f"📊 Performance: {message['distance_travelled']} km, Avg Speed: {message['average_speed']} km/h")
    
    def handle_control_command(self, ch, method, properties, body):
        """Handle control commands from backend"""
        try:
            command_data = json.loads(body)
            command = method.routing_key.split('.')[1]  # Extract command from routing key
            
            print(f"\n🎛️  Received command: {command}")
            
            if command == "start_rent":
                self.is_locked = False
                self.is_active = True
                self.is_renting = True
                print(f"✅ Rental started for {self.vehicle_id}")
                
            elif command == "end_rent":
                self.is_locked = True
                self.is_active = False
                self.is_renting = False
                self.speed = 0.0
                print(f"✅ Rental ended for {self.vehicle_id}")
                # Publish final reports
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
    
    def start_listening_commands(self):
        """Listen for control commands"""
        # Bind to control queues
        control_commands = ["start_rent", "end_rent", "kill_vehicle"]
        
        for command in control_commands:
            queue_name = f"vehicle.control.{command}"
            routing_key = f"control.{command}.{self.vehicle_id}"
            
            # Declare queue (should already exist from definitions.json)
            self.channel.queue_declare(queue=queue_name, durable=True, passive=True)
            
            # Bind queue to exchange with routing key for this specific vehicle
            self.channel.queue_bind(
                exchange=self.exchange,
                queue=queue_name,
                routing_key=routing_key
            )
            
            # Start consuming
            self.channel.basic_consume(
                queue=queue_name,
                on_message_callback=self.handle_control_command,
                auto_ack=False
            )
            
        print(f"👂 Listening for control commands...")
    
    def run(self):
        """Main loop to publish data and listen for commands"""
        if not self.connect():
            return
        
        # Start listening for commands
        self.start_listening_commands()
        
        print(f"\n{'='*60}")
        print(f"🚗 Vehicle Device Simulator Started")
        print(f"📱 Vehicle ID: {self.vehicle_id}")
        print(f"📍 Initial Position: ({self.latitude:.6f}, {self.longitude:.6f})")
        print(f"{'='*60}\n")
        
        cycle_count = 0
        
        try:
            while True:
                # Process any pending messages (non-blocking)
                self.connection.process_data_events(time_limit=0)
                
                # Publish location every cycle (5 seconds)
                self.publish_location()
                
                # Publish status every cycle
                self.publish_status()
                
                # Publish battery every 2 cycles (10 seconds)
                if cycle_count % 2 == 0:
                    self.publish_battery()
                
                # Publish maintenance report every 20 cycles (100 seconds)
                if cycle_count % 20 == 0 and cycle_count > 0:
                    self.publish_maintenance_report()
                
                # Publish performance report when rental ends
                # (handled in end_rent command)
                
                cycle_count += 1
                print("-" * 60)
                time.sleep(5)  # Publish every 5 seconds
                
        except KeyboardInterrupt:
            print(f"\n\n⏹️  Stopping vehicle device {self.vehicle_id}...")
        finally:
            if self.connection and not self.connection.is_closed:
                self.connection.close()
            print(f"👋 Device {self.vehicle_id} disconnected")

def main():
    if len(sys.argv) < 2:
        print("Usage: python publisher.py <VEHICLE_ID> [RABBITMQ_URL]")
        print("\nExample:")
        print("  python publisher.py VEHICLE_001")
        print("  python publisher.py VEHICLE_002 amqp://vehicle:vehicle123@103.175.219.138:5672")
        sys.exit(1)
    
    vehicle_id = sys.argv[1]
    rabbitmq_url = sys.argv[2] if len(sys.argv) > 2 else "amqp://vehicle:vehicle123@localhost:5672"
    
    device = VehicleDevice(vehicle_id, rabbitmq_url)
    device.run()

if __name__ == "__main__":
    main()