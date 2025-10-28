import amqp, { Connection, Channel, ConsumeMessage } from 'amqplib'

// Vehicle Data Types
interface VehicleLocation {
  vehicle_id: string
  latitude: number
  longitude: number
  speed: number          // km/h
  heading: number        // degrees (0-360)
  altitude?: number      // meters
  accuracy?: number      // meters
  timestamp: string
}

interface VehicleStatus {
  vehicle_id: string
  is_engine_killed: boolean
  device_active: boolean
  is_locked: boolean
  ignition_on: boolean
  timestamp: string
}

interface VehicleBattery {
  vehicle_id: string
  device_voltage: number    // Device internal battery (V)
  vehicle_voltage: number   // Vehicle main battery (V)
  charging_status: boolean
  battery_health: number    // 0-100%
  timestamp: string
}

interface MaintenanceReport {
  vehicle_id: string
  rental_id: string
  
  // Tire condition scores (0-100) - separated front/rear
  tire_front_left: number
  tire_front_right: number
  tire_rear_left: number
  tire_rear_right: number
  
  // Component condition scores (0-100)
  brake_pads: number
  chain_cvt: number
  engine_oil: number
  battery: number
  lights: number
  spark_plug: number
  
  // Calculated fields
  overall_score: number
  maintenance_required: boolean
  critical_issues: string[]
  
  timestamp: string
}

interface PerformanceReport {
  vehicle_id: string
  rental_id: string
  
  // Trip metrics
  weight_score: number      // Driver weight impact (0-100)
  max_speed: number        // km/h
  total_distance: number   // kilometers
  trip_duration: number    // minutes
  fuel_efficiency: number  // km/liter equivalent
  
  // Driving behavior
  harsh_acceleration_count: number
  harsh_braking_count: number
  speeding_violations: number
  driving_score: number    // 0-100
  
  timestamp: string
}

interface TireConditionReport {
  vehicle_id: string
  rental_id?: string
  
  // Front tire details
  front_left_pressure: number     // PSI
  front_left_tread_depth: number  // mm
  front_left_temperature: number  // Celsius
  front_left_condition_score: number // 0-100
  
  front_right_pressure: number
  front_right_tread_depth: number
  front_right_temperature: number
  front_right_condition_score: number
  
  // Rear tire details
  rear_left_pressure: number
  rear_left_tread_depth: number
  rear_left_temperature: number
  rear_left_condition_score: number
  
  rear_right_pressure: number
  rear_right_tread_depth: number
  rear_right_temperature: number
  rear_right_condition_score: number
  
  // Overall tire assessment
  overall_tire_score: number
  tire_replacement_needed: boolean
  recommended_maintenance: string[]
  
  timestamp: string
}

interface AlertMessage {
  vehicle_id: string
  alert_type: 'speed_limit' | 'geofence' | 'battery_low' | 'maintenance' | 'emergency'
  severity: 'low' | 'medium' | 'high' | 'critical'
  message: string
  data?: any
  timestamp: string
}

// Configuration interface
interface ConsumerConfig {
  url: string
  prefetch?: number
  reconnectAttempts?: number
  reconnectDelay?: number
}

export class VehicleDataConsumer {
  private connection: Connection | null = null
  private channel: Channel | null = null
  private isConnected = false
  private reconnectAttempts = 0
  private readonly maxReconnectAttempts: number
  private readonly reconnectDelay: number
  private readonly rabbitmqUrl: string
  private readonly prefetch: number

  constructor(config: ConsumerConfig) {
    this.rabbitmqUrl = config.url
    this.prefetch = config.prefetch || 10
    this.maxReconnectAttempts = config.reconnectAttempts || 5
    this.reconnectDelay = config.reconnectDelay || 5000
  }

  async connect(): Promise<void> {
    try {
      console.log('🔌 Connecting to RabbitMQ...')
      this.connection = await amqp.connect(this.rabbitmqUrl)
      this.channel = await this.connection.createChannel()

      // Set prefetch for better performance
      await this.channel.prefetch(this.prefetch)

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

      const startTime = Date.now()
      try {
        const data = JSON.parse(msg.content.toString()) as T
        console.log(`📨 [${queueName}] Received message:`, {
          vehicle_id: (data as any).vehicle_id,
          timestamp: (data as any).timestamp
        })

        await processor(data)
        
        this.channel?.ack(msg)
        const processingTime = Date.now() - startTime
        console.log(`✅ [${queueName}] Processed in ${processingTime}ms`)
      } catch (error) {
        console.error(`❌ [${queueName}] Processing error:`, error)
        
        // Send to dead letter queue after 3 retries
        const retryCount = (msg.properties.headers?.['x-retry-count'] || 0) as number
        if (retryCount < 3) {
          // Requeue with retry count
          msg.properties.headers = { ...msg.properties.headers, 'x-retry-count': retryCount + 1 }
          this.channel?.nack(msg, false, true)
        } else {
          // Send to DLQ
          this.channel?.nack(msg, false, false)
        }
      }
    })

    console.log(`👂 Listening to queue: ${queueName}`)
  }

  // Data Processing Methods
  private async processLocationData(data: VehicleLocation): Promise<void> {
    console.log(`📍 Processing location for vehicle ${data.vehicle_id}:`, {
      coordinates: `${data.latitude}, ${data.longitude}`,
      speed: `${data.speed} km/h`,
      heading: `${data.heading}°`,
      timestamp: data.timestamp
    })

    // Business logic implementations:
    
    // 1. Real-time tracking update
    await this.updateRealTimeTracking(data)
    
    // 2. Geofence checking
    await this.checkGeofenceViolations(data)
    
    // 3. Speed limit monitoring
    if (data.speed > 80) {
      await this.handleSpeedViolation(data)
    }
    
    // 4. Route optimization data
    await this.updateRouteAnalytics(data)
  }

  private async processStatusData(data: VehicleStatus): Promise<void> {
    console.log(`🔋 Processing status for vehicle ${data.vehicle_id}:`, {
      engine_killed: data.is_engine_killed,
      device_active: data.device_active,
      locked: data.is_locked,
      ignition: data.ignition_on,
      timestamp: data.timestamp
    })

    // Critical status alerts
    if (data.is_engine_killed) {
      await this.handleEngineKilled(data)
    }

    if (!data.device_active) {
      await this.handleDeviceInactive(data)
    }

    // Update vehicle status in database
    await this.updateVehicleStatus(data)
  }

  private async processBatteryData(data: VehicleBattery): Promise<void> {
    console.log(`🔋 Processing battery for vehicle ${data.vehicle_id}:`, {
      device_voltage: `${data.device_voltage}V`,
      vehicle_voltage: `${data.vehicle_voltage}V`,
      charging: data.charging_status,
      health: `${data.battery_health}%`,
      timestamp: data.timestamp
    })

    // Low battery alerts
    if (data.device_voltage < 3.3) {
      await this.sendLowBatteryAlert(data, 'device')
    }

    if (data.vehicle_voltage < 12.0) {
      await this.sendLowBatteryAlert(data, 'vehicle')
    }

    // Battery health monitoring
    if (data.battery_health < 50) {
      await this.scheduleMaintenanceAlert(data.vehicle_id, 'battery_replacement')
    }

    await this.updateBatteryMetrics(data)
  }

  private async processMaintenanceReport(data: MaintenanceReport): Promise<void> {
    console.log(`🔧 Processing maintenance report for vehicle ${data.vehicle_id}:`, {
      rental_id: data.rental_id,
      overall_score: data.overall_score,
      maintenance_required: data.maintenance_required,
      critical_issues: data.critical_issues,
      tire_scores: {
        front_left: data.tire_front_left,
        front_right: data.tire_front_right,
        rear_left: data.tire_rear_left,
        rear_right: data.tire_rear_right
      },
      timestamp: data.timestamp
    })

    // Calculate tire-specific maintenance needs
    const tireScores = [
      data.tire_front_left,
      data.tire_front_right,
      data.tire_rear_left,
      data.tire_rear_right
    ]
    
    const avgTireScore = tireScores.reduce((a, b) => a + b, 0) / tireScores.length
    
    if (avgTireScore < 60) {
      await this.scheduleMaintenanceAlert(data.vehicle_id, 'tire_inspection')
    }

    // Component-specific alerts
    if (data.brake_pads < 40) {
      await this.scheduleMaintenanceAlert(data.vehicle_id, 'brake_service')
    }

    if (data.engine_oil < 50) {
      await this.scheduleMaintenanceAlert(data.vehicle_id, 'oil_change')
    }

    await this.saveMaintenanceReport(data)
  }

  private async processPerformanceReport(data: PerformanceReport): Promise<void> {
    console.log(`🏁 Processing performance report for vehicle ${data.vehicle_id}:`, {
      rental_id: data.rental_id,
      distance: `${data.total_distance} km`,
      duration: `${data.trip_duration} min`,
      max_speed: `${data.max_speed} km/h`,
      driving_score: data.driving_score,
      efficiency: `${data.fuel_efficiency} km/L`,
      timestamp: data.timestamp
    })

    // Performance analytics
    if (data.driving_score < 60) {
      await this.flagDrivingBehavior(data)
    }

    if (data.harsh_acceleration_count > 5 || data.harsh_braking_count > 5) {
      await this.reportAggressiveDriving(data)
    }

    await this.updatePerformanceMetrics(data)
    await this.generateRentalReport(data)
  }

  private async processTireConditionReport(data: TireConditionReport): Promise<void> {
    console.log(`🛞 Processing tire condition for vehicle ${data.vehicle_id}:`, {
      rental_id: data.rental_id,
      overall_score: data.overall_tire_score,
      replacement_needed: data.tire_replacement_needed,
      front_condition: {
        left: `${data.front_left_condition_score}% (${data.front_left_pressure} PSI)`,
        right: `${data.front_right_condition_score}% (${data.front_right_pressure} PSI)`
      },
      rear_condition: {
        left: `${data.rear_left_condition_score}% (${data.rear_left_pressure} PSI)`,
        right: `${data.rear_right_condition_score}% (${data.rear_right_pressure} PSI)`
      },
      recommended_maintenance: data.recommended_maintenance,
      timestamp: data.timestamp
    })

    // Critical tire pressure alerts
    const pressures = [
      data.front_left_pressure,
      data.front_right_pressure,
      data.rear_left_pressure,
      data.rear_right_pressure
    ]

    const lowPressureTires = pressures.filter(p => p < 25) // Below 25 PSI
    if (lowPressureTires.length > 0) {
      await this.sendCriticalTireAlert(data)
    }

    // Tire replacement alerts
    if (data.tire_replacement_needed) {
      await this.scheduleMaintenanceAlert(data.vehicle_id, 'tire_replacement')
    }

    await this.saveTireConditionReport(data)
  }

  private async processAlertMessage(data: AlertMessage): Promise<void> {
    console.log(`🚨 Processing alert for vehicle ${data.vehicle_id}:`, {
      type: data.alert_type,
      severity: data.severity,
      message: data.message,
      timestamp: data.timestamp
    })

    // Route alerts based on severity
    switch (data.severity) {
      case 'critical':
        await this.handleCriticalAlert(data)
        break
      case 'high':
        await this.handleHighPriorityAlert(data)
        break
      case 'medium':
        await this.handleMediumPriorityAlert(data)
        break
      case 'low':
        await this.handleLowPriorityAlert(data)
        break
    }

    await this.logAlert(data)
  }

  // Business Logic Helper Methods (implement based on your needs)
  private async updateRealTimeTracking(data: VehicleLocation): Promise<void> {
    // Implement real-time tracking update
    console.log(`📍 Updating real-time tracking for ${data.vehicle_id}`)
  }

  private async checkGeofenceViolations(data: VehicleLocation): Promise<void> {
    // Implement geofence checking logic
    console.log(`🗺️ Checking geofence for ${data.vehicle_id}`)
  }

  private async handleSpeedViolation(data: VehicleLocation): Promise<void> {
    console.warn(`⚠️ Speed violation: ${data.vehicle_id} going ${data.speed} km/h`)
  }

  private async handleEngineKilled(data: VehicleStatus): Promise<void> {
    console.warn(`🛑 Engine killed for vehicle ${data.vehicle_id}`)
  }

  private async sendLowBatteryAlert(data: VehicleBattery, type: 'device' | 'vehicle'): Promise<void> {
    console.warn(`🪫 Low ${type} battery for ${data.vehicle_id}`)
  }

  private async scheduleMaintenanceAlert(vehicleId: string, type: string): Promise<void> {
    console.warn(`🔧 Maintenance needed for ${vehicleId}: ${type}`)
  }

  private async saveMaintenanceReport(data: MaintenanceReport): Promise<void> {
    // Implement database save
    console.log(`💾 Saving maintenance report for ${data.vehicle_id}`)
  }

  private async generateRentalReport(data: PerformanceReport): Promise<void> {
    // Implement rental report generation
    console.log(`📊 Generating rental report for ${data.rental_id}`)
  }

  private async sendCriticalTireAlert(data: TireConditionReport): Promise<void> {
    console.error(`🚨 CRITICAL: Tire pressure issue for ${data.vehicle_id}`)
  }

  private async handleCriticalAlert(data: AlertMessage): Promise<void> {
    console.error(`🚨 CRITICAL ALERT: ${data.message}`)
    // Implement emergency response procedures
  }

  // Add more helper methods as needed...
  private async updateVehicleStatus(data: VehicleStatus): Promise<void> { /* Implementation */ }
  private async updateBatteryMetrics(data: VehicleBattery): Promise<void> { /* Implementation */ }
  private async updateRouteAnalytics(data: VehicleLocation): Promise<void> { /* Implementation */ }
  private async handleDeviceInactive(data: VehicleStatus): Promise<void> { /* Implementation */ }
  private async updatePerformanceMetrics(data: PerformanceReport): Promise<void> { /* Implementation */ }
  private async flagDrivingBehavior(data: PerformanceReport): Promise<void> { /* Implementation */ }
  private async reportAggressiveDriving(data: PerformanceReport): Promise<void> { /* Implementation */ }
  private async saveTireConditionReport(data: TireConditionReport): Promise<void> { /* Implementation */ }
  private async handleHighPriorityAlert(data: AlertMessage): Promise<void> { /* Implementation */ }
  private async handleMediumPriorityAlert(data: AlertMessage): Promise<void> { /* Implementation */ }
  private async handleLowPriorityAlert(data: AlertMessage): Promise<void> { /* Implementation */ }
  private async logAlert(data: AlertMessage): Promise<void> { /* Implementation */ }

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
      this.consumeQueue<PerformanceReport>('vehicle.report.performance', this.processPerformanceReport.bind(this)),
      this.consumeQueue<TireConditionReport>('vehicle.report.tire_condition', this.processTireConditionReport.bind(this)),
      this.consumeQueue<AlertMessage>('vehicle.alerts', this.processAlertMessage.bind(this))
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

// Export types for external use
export type {
  VehicleLocation,
  VehicleStatus,
  VehicleBattery,
  MaintenanceReport,
  PerformanceReport,
  TireConditionReport,
  AlertMessage,
  ConsumerConfig
}