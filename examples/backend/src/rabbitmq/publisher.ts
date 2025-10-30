import { getChannel } from "./connection"

export const publishCommand = async (
  command: "start_rent" | "end_rent" | "kill_vehicle",
  vehicle_id: string
) => {
  const channel = await getChannel()
  const exchange = "vehicle.exchange"
  const routingKey = `control.${command}.${vehicle_id}`

  const message = {
    vehicle_id,
    timestamp: new Date().toISOString(),
  }

  await channel.publish(exchange, routingKey, Buffer.from(JSON.stringify(message)))
  console.log(`📡 Published ${command} for vehicle ${vehicle_id}`)
}
