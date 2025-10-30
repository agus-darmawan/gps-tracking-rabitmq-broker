import { connectRabbitMQ } from "./rabbitmq/connection"
import { startConsumers } from "./rabbitmq/consumer"
import { createServer } from "./server"

const RABBIT_URL = "amqp://backend:backend123@103.175.219.138:5672"

const startApp = async () => {
  try {
    await connectRabbitMQ(RABBIT_URL)
    await startConsumers()

    const app = createServer()
    const PORT = 3001
    app.listen(PORT, () => {
      console.log(`🚀 Server running at http://localhost:${PORT}`)
    })
  } catch (err) {
    console.error("❌ Startup failed:", err)
    process.exit(1)
  }
}

startApp()
