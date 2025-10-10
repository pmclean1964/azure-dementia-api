``````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````// Minimal Express server for Azure App Service
// - Node 20
// - CORS enabled
// - JSON responses
// - Health probe endpoint
// - Binds to process.env.PORT (defaults to 3000 locally)

const express = require('express');
const cors = require('cors');

const app = express();

// Enable CORS for all routes. Customize origin in production as needed.
app.use(cors());

// Parse JSON if needed later (kept minimal now)
app.use(express.json());

// Health probe endpoint for Azure/App Service or k8s style probes
app.get('/healthz', (req, res) => {
  res.json({ status: 'ok' });
});

// Sample API endpoint
app.get('/api/hello', (req, res) => {
  res.json({ message: 'hello world' });
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  // Single line, clear startup log useful for container logs and App Service logs
  console.log(`Server started: http://localhost:${port} (pid ${process.pid})`);
});
