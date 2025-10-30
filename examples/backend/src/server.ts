import express from "express"
import cors from "cors"
import bodyParser from "body-parser"
import { memoryData } from "./rabbitmq/consumer"
import { publishCommand } from "./rabbitmq/publisher"

export const createServer = () => {
  const app = express()
  app.use(cors())
  app.use(bodyParser.json())

  
    // ========================
  //  Hello World
  // ========================
  app.get("/", (req, res) => {
    res.json("🚗 Vehicle Fleet Management Backend is running!")
    }
  )
  // ========================
  // 📍 GET Vehicle Data
  // ========================
  app.get("/api/:type/:vehicle_id", (req, res) => {
    const { type, vehicle_id } = req.params
    const data = memoryData[type]?.[vehicle_id]
    if (!data) return res.status(404).json({ error: "Data not found" })
    res.json(data)
  })

  app.get("/api/:type", (req, res) => {
    const { type } = req.params
    const data = memoryData[type]
    if (!data) return res.status(404).json({ error: "Invalid type" })
    res.json(Object.values(data))
  })

  // ========================
  // ⚙️ Control Commands
  // ========================
  app.post("/api/control/:command", async (req, res) => {
    const { command } = req.params
    const { vehicle_id } = req.body
    if (!vehicle_id) return res.status(400).json({ error: "Missing vehicle_id" })

    if (!["start_rent", "end_rent", "kill_vehicle"].includes(command))
      return res.status(400).json({ error: "Invalid command" })

    await publishCommand(command as any, vehicle_id)
    res.json({ success: true, command, vehicle_id })
  })

  return app
}
