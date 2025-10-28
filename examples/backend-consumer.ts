import amqp, { Connection, Channel, ConsumeMessage } from 'amqplib'

// Types for vehicle data
interface VehicleLocation {
  vehicle_id: string
  lat: number
  long: number
  timestamp: string
}

interface VehicleStatus {
  vehicle_id: string
  is_killed: boolean
  device_active: boolean
  timestamp: string
}

interface VehicleBattery {
  vehicle_id: string
  device_voltage: number
  vehicle_voltage: number
  timestamp: string
}

interface MaintenanceReport {
  vehicle_id: string
  rental_id: string
  ban: number
  rem: number
  rantai_cvt: number
  oli: number
  aki: number
  lampu: number
  busi: number
  timestamp: string
}

interface PerformanceReport {
  vehicle_id: string
  rental_id: string
  skor_berat: number
  max_speed: number
  total_km: number
  timestamp: string
}

class VehicleDataConsumer {
  private connection: Connection | null = null
  private channel: Channel | null = null
  private isConnected = false
  private reconnectAttempts = 0
  private maxReconnectAttempts = 5
  private reconnectDelay = 5000

  constructor(
    private rabbitmqUrl = 'amqp://backend:b@ckend@localhost:5672'
  ) {}

  async connect(): Promise<void> {
    try {
      console.log('🔌 Connecting to RabbitMQ...')
      this.connection = await amqp.connect(this.rabbitmqUrl)
      this.channel = await this.connection.createChannel()

      // Set prefetch for better performance
      await this.channel.prefetch(10)

      // Handle connection events
      this.connection.on('error', this.handleConnectionError.bind(this))
      this.connection.on('close', this.handleConnectionClose.bind(this))

      this.isConnected = true
      this.reconnectAttempts = 0
      console.log('✅ Connected to RabbitMQ successfully')
    } catch (error) {
      console.error('❌ Failed to connect to RabbitMQ:', error)
      await this.handleReconnect()
    }
  }

  private async handleConnectionError(error: Error): Promise<void> {
    console.error('🚨 RabbitMQ connection error:', error)
    this.isConnected = false
    await this.handleReconnect()
  }

  private async handleConnectionClose(): Promise<void> {
    console.warn('⚠️ RabbitMQ connection closed')
    this.isConnected = false
    await this.handleReconnect()
  }

  private async handleReconnect(): Promise<void> {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('💀 Max reconnection attempts reached. Exiting...')
      process.exit(1)
    }

    this.reconnectAttempts++
    console.log(`🔄 Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts})...`)
    
    setTimeout(async () => {
      await this.connect()
      if (this.isConnected) {
        await this.startConsuming()
      }
    }, this.reconnectDelay)
  }

  private async consumeQueue<T>(
    queueName: string,
    processor: (data: T) => Promise<void>
  ): Promise<void> {
    if (!this.channel) {
      throw new Error('Channel not initialized')
    }

    await this.channel.consume(queueName, async (msg: ConsumeMessage | null) => {
      if (!msg) return

      try {
        const data = JSON.parse(msg.content.toString()) as T
        console.log(`📨 Received message from ${queueName}:`, data)

        await processor(data)
        
        this.channel?.ack(msg)
        console.log(`✅ Processed message from ${queueName}`)
      } catch (error) {
        console.error(`❌ Error processing message from ${queueName}:`, error)
        
        // Send to dead letter queue
        this.channel?.nack(msg, false, false)
      }
    })

    console.log(`👂 Listening to queue: ${queueName}`)
  }

  // Data processors
  private async processLocationData(data: VehicleLocation): Promise<void> {
    console.log(`📍 Processing location for vehicle ${data.vehicle_id}:`, {
      coordinates: `${data.lat}, ${data.long}`,
      timestamp: data.timestamp
    })

    // TODO: Implement your business logic here
    // - Save to database
    // - Update real-time dashboard
    // - Check geofencing rules
    // - Trigger location-based alerts
    
    // Example: Save to database
    // await this.saveLocationToDatabase(data)
    
    // Example: Update real-time tracking
    // await this.updateRealTimeTracking(data)
  }

  private async processStatusData(data: VehicleStatus): Promise<void> {
    console.log(`🔋 Processing status for vehicle ${data.vehicle_id}:`, {
      is_killed: data.is_killed,
      device_active: data.device_active,
      timestamp: data.timestamp
    })

    // TODO: Implement your business logic here
    // - Update vehicle status in database
    // - Trigger alerts if vehicle is killed unexpectedly
    // - Monitor device connectivity
    
    if (data.is_killed) {
      console.warn(`⚠️ Vehicle ${data.vehicle_id} has been killed!`)
      // await this.handleVehicleKilled(data)
    }

    if (!data.device_active) {
      console.warn(`📵 Device for vehicle ${data.vehicle_id} is inactive!`)
      // await this.handleDeviceInactive(data)
    }
  }

  private async processBatteryData(data: VehicleBattery): Promise<void> {
    console.log(`🔋 Processing battery for vehicle ${data.vehicle_id}:`, {
      device_voltage: `${data.device_voltage}V`,
      vehicle_voltage: `${data.vehicle_voltage}V`,
      timestamp: data.timestamp
    })

    // TODO: Implement your business logic here
    // - Monitor battery levels
    // - Send low battery alerts
    // - Predict maintenance needs
    
    if (data.device_voltage < 3.3) {
      console.warn(`🪫 Low device battery for vehicle ${data.vehicle_id}: ${data.device_voltage}V`)
      // await this.sendLowBatteryAlert(data)
    }

    if (data.vehicle_voltage < 12.0) {
      console.warn(`🪫 Low vehicle battery for vehicle ${data.vehicle_id}: ${data.vehicle_voltage}V`)
      // await this.sendVehicleBatteryAlert(data)
    }
  }

  private async processMaintenanceReport(data: MaintenanceReport): Promise<void> {
    console.log(`🔧 Processing maintenance report for vehicle ${data.vehicle_id}:`, {
      rental_id: data.rental_id,
      scores: {
        ban: data.ban,
        rem: data.rem,
        rantai_cvt: data.rantai_cvt,
        oli: data.oli,
        aki: data.aki,
        lampu: data.lampu,
        busi: data.busi
      },
      timestamp: data.timestamp
    })

    // TODO: Implement your business logic here
    // - Save maintenance scores to database
    // - Calculate overall vehicle health score
    // - Schedule maintenance if scores are low
    // - Update vehicle maintenance history
    
    const averageScore = (
      data.ban + data.rem + data.rantai_cvt + data.oli + 
      data.aki + data.lampu + data.busi
    ) / 7

    console.log(`📊 Average maintenance score: ${averageScore.toFixed(2)}`)

    if (averageScore < 60) {
      console.warn(`⚠️ Vehicle ${data.vehicle_id} needs maintenance! Average score: ${averageScore.toFixed(2)}`)
      // await this.scheduleMaintenanceAlert(data, averageScore)
    }
  }

  private async processPerformanceReport(data: PerformanceReport): Promise<void> {
    console.log(`🏁 Processing performance report for vehicle ${data.vehicle_id}:`, {
      rental_id: data.rental_id,
      performance: {
        skor_berat: data.skor_berat,
        max_speed: `${data.max_speed} km/h`,
        total_km: `${data.total_km} km`
      },
      timestamp: data.timestamp
    })

    // TODO: Implement your business logic here
    // - Save performance data to database
    // - Calculate driver behavior scores
    // - Update vehicle analytics
    // - Generate rental completion reports
    
    if (data.max_speed > 80) {
      console.warn(`⚠️ High speed detected for vehicle ${data.vehicle_id}: ${data.max_speed} km/h`)
      // await this.handleSpeedViolation(data)
    }

    console.log(`📈 Rental ${data.rental_id} completed: ${data.total_km}km, max speed: ${data.max_speed}km/h`)
  }

  async startConsuming(): Promise<void> {
    if (!this.isConnected || !this.channel) {
      throw new Error('Not connected to RabbitMQ')
    }

    console.log('🚀 Starting vehicle data consumers...')

    // Start consuming from all queues
    await Promise.all([
      this.consumeQueue<VehicleLocation>('vehicle.realtime.location', this.processLocationData.bind(this)),
      this.consumeQueue<VehicleStatus>('vehicle.realtime.status', this.processStatusData.bind(this)),
      this.consumeQueue<VehicleBattery>('vehicle.realtime.battery', this.processBatteryData.bind(this)),
      this.consumeQueue<MaintenanceReport>('vehicle.report.maintenance', this.processMaintenanceReport.bind(this)),
      this.consumeQueue<PerformanceReport>('vehicle.report.performance', this.processPerformanceReport.bind(this))
    ])

    console.log('👂 All consumers started, waiting for messages...')
  }

  async close(): Promise<void> {
    console.log('🛑 Shutting down consumer...')
    
    if (this.channel) {
      await this.channel.close()
      this.channel = null
    }
    
    if (this.connection) {
      await this.connection.close()
      this.connection = null
    }
    
    this.isConnected = false
    console.log('✅ Consumer shut down successfully')
  }

  getConnectionStatus(): { connected: boolean; attempts: number } {
    return {
      connected: this.isConnected,
      attempts: this.reconnectAttempts
    }
  }
}

// Export the consumer class for use in other modules
export { VehicleDataConsumer }
export type {
  VehicleLocation,
  VehicleStatus,
  VehicleBattery,
  MaintenanceReport,
  PerformanceReport
}

// Example usage (commented out)
/*
async function example() {
  const consumer = new VehicleDataConsumer()
  
  try {
    await consumer.connect()
    await consumer.startConsuming()
    
    console.log('Consumer started successfully')
    
    // Keep running until manually stopped
    // In real application, you would integrate this with your main service
    
  } catch (error) {
    console.error('Failed to start consumer:', error)
    await consumer.close()
  }
}

// Uncomment to run
// example()
*/