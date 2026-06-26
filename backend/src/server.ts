import cors from "@fastify/cors";
import Fastify from "fastify";
import { ZodError } from "zod";
import { loadConfig } from "./config.js";
import { createPool, runMigrations, seedLocalMachineToken } from "./db.js";
import { registerIngestRoutes } from "./ingest.js";
import { registerQueryRoutes } from "./queries.js";

const config = loadConfig();
const pool = createPool(config);

const app = Fastify({
  logger: {
    level: config.logLevel,
    redact: ["req.headers.authorization"]
  },
  bodyLimit: 2 * 1024 * 1024
});

app.setErrorHandler((error, _request, reply) => {
  if (error instanceof ZodError) {
    return reply.code(400).send({
      error: "validation_error",
      issues: error.issues
    });
  }

  app.log.error(error);
  return reply.code(500).send({ error: "internal_server_error" });
});

await app.register(cors, { origin: false });

app.get("/health", async () => {
  await pool.query("select 1");
  return { ok: true };
});

await runMigrations(pool, config.migrationsDir);
await seedLocalMachineToken(pool, config);
await registerIngestRoutes(app, pool);
await registerQueryRoutes(app, pool);

const shutdown = async () => {
  app.log.info("Shutting down");
  await app.close();
  await pool.end();
};

process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());

await app.listen({ host: config.host, port: config.port });
