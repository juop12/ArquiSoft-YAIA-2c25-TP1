import cluster from "cluster";
import os from "os";

if (cluster.isPrimary) {
  const n = Number(process.env.WORKERS || Math.floor(os.cpus().length / 3));
  console.log(`[master] starting ${n} workers...`);

  for (let i = 0; i < n; i++) {
    const env = { ...process.env };
    // Only the first worker will write to disk, to prevent invalid states
    if (i === 0) env.STATE_WRITER = "1";
    cluster.fork(env);
  }

  cluster.on("exit", (worker, code, signal) => {
    console.warn(`[master] worker ${worker.process.pid} died (code=${code}, signal=${signal}). respawning...`);
    const env = { ...process.env };
    cluster.fork(env);
  });
} else {
  // Each worker starts the Express server
  await import("./app.js");
}
