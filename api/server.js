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

// Swagger UI setup at /api/doc
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = {
  openapi: '3.0.0',
  info: {
    title: 'Dementia API',
    version: '1.0.0',
    description: 'API documentation for Dementia App (serverless)'
  },
  servers: [
    { url: '/', description: 'Current server' }
  ],
  paths: {
    '/api/hello': {
      get: {
        summary: 'Hello world sample',
        description: 'Returns a simple greeting message.',
        responses: {
          '200': {
            description: 'Successful response',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    message: { type: 'string', example: 'hello world' }
                  }
                }
              }
            }
          }
        }
      }
    },
    '/healthz': {
      get: {
        summary: 'Health probe',
        description: 'Liveness/health check endpoint.',
        responses: {
          '200': {
            description: 'Service is healthy',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    status: { type: 'string', example: 'ok' }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
};
app.use('/api/doc', swaggerUi.serve, swaggerUi.setup(swaggerSpec, { explorer: true }));

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
