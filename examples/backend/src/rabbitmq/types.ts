export interface VehicleLocation {
  vehicle_id: string
  latitude: number
  longitude: number
  altitude: number
  timestamp: string
}

export interface VehicleStatus {
  vehicle_id: string
  is_locked: boolean
  is_active: boolean
  is_kill_cmd_accepted: boolean
  is_killed: boolean
  is_tampered: boolean
  speed: number
  heading: number
  timestamp: string
}

export interface VehicleBattery {
  vehicle_id: string
  device_battery_level: number
  device_voltage: number
  vehicle_voltage: number
  timestamp: string
}

export interface MaintenanceReport {
  vehicle_id: string
  weight_score: 'ringan' | 'sedang' | 'berat'
  front_tire: number
  rear_tire: number
  brake_pad: number
  engine_oil: number
  chain_or_cvt: number
  engine: number
  timestamp: string
}

export interface PerformanceReport {
  vehicle_id: string
  distance_travelled: number
  average_speed: number
  max_speed: number
  timestamp: string
}
