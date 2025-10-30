export interface VehicleLocation {
  vehicle_id: string
  latitude: number
  longitude: number
  timestamp: string
}

export interface VehicleStatus {
  vehicle_id: string
  is_locked: boolean
  is_active: boolean
  speed: number
  heading: number
  timestamp: string
}

export interface VehicleBattery {
  vehicle_id: string
  battery_level: number
  voltage: number
  timestamp: string
}

export interface MaintenanceReport {
  vehicle_id: string
  issues_detected: string[]
  recommended_maintenance: string[]
  timestamp: string
}

export interface PerformanceReport {
  vehicle_id: string
  distance_travelled: number
  average_speed: number
  max_speed: number
  fuel_efficiency: number
  timestamp: string
}
