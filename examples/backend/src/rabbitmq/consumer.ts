import { getChannel } from "./connection"
import {
  VehicleBattery,
  VehicleLocation,
  VehicleStatus,
  MaintenanceReport,
  PerformanceReport,
} from "./types.js"

export const memoryData: Record<string, any> = {
  location: {},
  status: {},
  battery: {},
  maintenance: {},
  performance: {},
}

export const startConsumers = async () => {
  const channel = await getChannel()

  const queues = [
    "vehicle.realtime.location",
    "vehicle.realtime.status",
    "vehicle.realtime.battery",
    "vehicle.report.maintenance",
    "vehicle.report.performance",
  ]

  for (const queue of queues) {
    await channel.consume(queue, (msg : any) => {
      if (!msg) return
      const data = JSON.parse(msg.content.toString())
      const type = queue.split(".").slice(-1)[0]

      memoryData[type][data.vehicle_id] = data
      channel.ack(msg)
    })
    console.log(`📥 Listening to ${queue}`)
  }
}
