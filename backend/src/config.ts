export type AppConfig = {
  nodeEnv: string;
  host: string;
  port: number;
  logLevel: string;
  databaseUrl: string;
  migrationsDir: string;
  seedServerKey?: string;
  seedServerName?: string;
  seedMachineToken?: string;
};

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function loadConfig(): AppConfig {
  return {
    nodeEnv: process.env.NODE_ENV ?? "development",
    host: process.env.API_HOST ?? "0.0.0.0",
    port: Number(process.env.API_PORT ?? "3000"),
    logLevel: process.env.LOG_LEVEL ?? "info",
    databaseUrl: required("DATABASE_URL"),
    migrationsDir: process.env.MIGRATIONS_DIR ?? "../database/migrations",
    seedServerKey: process.env.GRP9_SERVER_KEY,
    seedServerName: process.env.GRP9_SERVER_NAME,
    seedMachineToken: process.env.GRP9_MACHINE_TOKEN
  };
}
