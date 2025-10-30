import amqp from "amqplib"

let connection: amqp.Connection | null = null
let channel: amqp.Channel | null = null

export const connectRabbitMQ = async (url: string) => {
  if (connection && channel) return { connection, channel }

  connection = await amqp.connect(url)
  channel = await connection.createChannel()

  console.log("✅ Connected to RabbitMQ")

  connection.on("close", () => {
    console.error("⚠️ RabbitMQ connection closed.")
    connection = null
    channel = null
  })

  return { connection, channel }
}

export const getChannel = async () => {
  if (!channel) throw new Error("Channel not initialized. Call connectRabbitMQ() first.")
  return channel
}
