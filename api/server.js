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
  components: {
    securitySchemes: {
      ApiKeyAuth: {
        type: 'apiKey',
        in: 'header',
        name: 'X-API-Key',
        description: 'Provide the API key. In CI/CD, this should be supplied from the GitHub Secrets API_KEY.'
      }
    }
  },
  security: [{ ApiKeyAuth: [] }],
  paths: {
    '/api/hello': {
      get: {
        summary: 'Hello world sample',
        description: 'Returns a simple greeting message. Requires a valid API key.',
        security: [{ ApiKeyAuth: [] }],
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
          },
          '401': {
            description: 'Missing API key'
          },
          '403': {
            description: 'Invalid API key'
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
          },
          '401': {
            description: 'Missing API key'
          },
          '403': {
            description: 'Invalid API key'
          }
        }
      }
    }
  }
};

// API key middleware
const requireApiKey = (req, res, next) => {
  const configuredKey = process.env.API_KEY;
  if (!configuredKey) {
    // Service misconfiguration: no API key set
    return res.status(500).json({ error: 'Server configuration error: API key is not set' });
  }
  const headerKey = req.header('X-API-Key') || '';
  // Also allow Authorization: Bearer <key>
  const auth = req.header('Authorization') || '';
  let token = headerKey;
  if (!token && auth.toLowerCase().startsWith('bearer ')) {
    token = auth.slice(7).trim();
  }
  if (!token) {
    return res.status(401).json({ error: 'API key required' });
  }
  if (token !== configuredKey) {
    return res.status(403).json({ error: 'Invalid API key' });
  }
  return next();
};

// Swagger UI setup (public)
app.use('/api/doc', swaggerUi.serve, swaggerUi.setup(swaggerSpec, { explorer: true, swaggerOptions: { persistAuthorization: true } }));

// Apply API key authentication to all routes except Swagger docs
app.use((req, res, next) => {
  if (req.path.startsWith('/api/doc')) return next();
  return requireApiKey(req, res, next);
});

// Health probe endpoint for Azure/App Service or k8s style probes
app.get('/healthz', (req, res) => {
  res.json({ status: 'ok' });
});

// Sample API endpoint (protected by API key)
app.get('/api/hello', requireApiKey, (req, res) => {
  res.json({ message: 'hello world' });
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  // Single line, clear startup log useful for container logs and App Service logs
  console.log(`Server started: http://localhost:${port} (pid ${process.pid})`);
});
