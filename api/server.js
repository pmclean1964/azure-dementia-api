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
    },
    schemas: {
      Family: {
        type: 'object',
        properties: {
          id: { type: 'string', example: 'fam_123' },
          name: { type: 'string', example: 'Smith Family' },
          members: {
            type: 'array',
            items: { type: 'string' },
            example: ['Alice', 'Bob']
          },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' }
        },
        required: ['id', 'name', 'createdAt', 'updatedAt']
      },
      FamilyCreate: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          members: { type: 'array', items: { type: 'string' } }
        },
        required: ['name']
      },
      FamilyUpdate: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          members: { type: 'array', items: { type: 'string' } }
        }
      },
      FamiliesPage: {
        type: 'object',
        properties: {
          items: {
            type: 'array',
            items: { $ref: '#/components/schemas/Family' }
          },
          page: { type: 'integer', example: 1 },
          pageSize: { type: 'integer', example: 10 },
          total: { type: 'integer', example: 25 }
        }
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
    },
    '/api/v1/families': {
      get: {
        summary: 'List families',
        description: 'Returns a paginated list of families with optional search by name.',
        parameters: [
          { in: 'query', name: 'search', schema: { type: 'string' }, required: false, description: 'Search by name (case-insensitive)' },
          { in: 'query', name: 'page', schema: { type: 'integer', minimum: 1, default: 1 }, required: false },
          { in: 'query', name: 'pageSize', schema: { type: 'integer', minimum: 1, maximum: 100, default: 10 }, required: false }
        ],
        responses: {
          '200': {
            description: 'Paged families',
            content: { 'application/json': { schema: { $ref: '#/components/schemas/FamiliesPage' } } }
          },
          '401': { description: 'Missing API key' },
          '403': { description: 'Invalid API key' }
        }
      },
      post: {
        summary: 'Create family',
        requestBody: {
          required: true,
          content: {
            'application/json': { schema: { $ref: '#/components/schemas/FamilyCreate' } }
          }
        },
        responses: {
          '201': { description: 'Created', content: { 'application/json': { schema: { $ref: '#/components/schemas/Family' } } } },
          '400': { description: 'Validation error' },
          '401': { description: 'Missing API key' },
          '403': { description: 'Invalid API key' }
        }
      }
    },
    '/api/v1/families/{family_id}': {
      get: {
        summary: 'Get family by ID',
        parameters: [ { in: 'path', name: 'family_id', required: true, schema: { type: 'string' } } ],
        responses: {
          '200': { description: 'Family', content: { 'application/json': { schema: { $ref: '#/components/schemas/Family' } } } },
          '404': { description: 'Not found' },
          '401': { description: 'Missing API key' },
          '403': { description: 'Invalid API key' }
        }
      },
      patch: {
        summary: 'Update family',
        parameters: [ { in: 'path', name: 'family_id', required: true, schema: { type: 'string' } } ],
        requestBody: {
          required: true,
          content: {
            'application/json': { schema: { $ref: '#/components/schemas/FamilyUpdate' } }
          }
        },
        responses: {
          '200': { description: 'Updated', content: { 'application/json': { schema: { $ref: '#/components/schemas/Family' } } } },
          '400': { description: 'Validation error' },
          '404': { description: 'Not found' },
          '401': { description: 'Missing API key' },
          '403': { description: 'Invalid API key' }
        }
      },
      delete: {
        summary: 'Delete family',
        parameters: [ { in: 'path', name: 'family_id', required: true, schema: { type: 'string' } } ],
        responses: {
          '204': { description: 'Deleted' },
          '404': { description: 'Not found' },
          '401': { description: 'Missing API key' },
          '403': { description: 'Invalid API key' }
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

// ----- Mock Families Endpoints -----
// In-memory mock store
const families = [
  {
    id: 'fam_001',
    name: 'Smith Family',
    members: ['Alice', 'Bob'],
    createdAt: new Date('2024-01-01T10:00:00Z').toISOString(),
    updatedAt: new Date('2024-01-01T10:00:00Z').toISOString()
  },
  {
    id: 'fam_002',
    name: 'Johnson Household',
    members: ['Carol'],
    createdAt: new Date('2024-02-15T12:30:00Z').toISOString(),
    updatedAt: new Date('2024-02-15T12:30:00Z').toISOString()
  },
  {
    id: 'fam_003',
    name: 'Garcia',
    members: [],
    createdAt: new Date('2024-03-20T09:15:00Z').toISOString(),
    updatedAt: new Date('2024-03-20T09:15:00Z').toISOString()
  }
];

const genId = () => 'fam_' + Math.random().toString(36).slice(2, 8);

// GET /api/v1/families?search=&page=&pageSize=
app.get('/api/v1/families', (req, res) => {
  const search = String(req.query.search || '').trim().toLowerCase();
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize, 10) || 10, 1), 100);

  let filtered = families;
  if (search) {
    filtered = families.filter(f => f.name.toLowerCase().includes(search));
  }

  const total = filtered.length;
  const start = (page - 1) * pageSize;
  const items = filtered.slice(start, start + pageSize);

  res.json({ items, page, pageSize, total });
});

// GET /api/v1/families/:family_id
app.get('/api/v1/families/:family_id', (req, res) => {
  const { family_id } = req.params;
  const family = families.find(f => f.id === family_id);
  if (!family) return res.status(404).json({ error: 'Family not found' });
  res.json(family);
});

// POST /api/v1/families
app.post('/api/v1/families', (req, res) => {
  const { name, members } = req.body || {};
  if (!name || typeof name !== 'string' || !name.trim()) {
    return res.status(400).json({ error: 'Name is required' });
  }
  if (members && !Array.isArray(members)) {
    return res.status(400).json({ error: 'Members must be an array of strings' });
  }
  const now = new Date().toISOString();
  const newFamily = {
    id: genId(),
    name: name.trim(),
    members: Array.isArray(members) ? members.map(String) : [],
    createdAt: now,
    updatedAt: now
  };
  families.push(newFamily);
  res.status(201).json(newFamily);
});

// PATCH /api/v1/families/:family_id
app.patch('/api/v1/families/:family_id', (req, res) => {
  const { family_id } = req.params;
  const family = families.find(f => f.id === family_id);
  if (!family) return res.status(404).json({ error: 'Family not found' });

  const { name, members } = req.body || {};
  if (name !== undefined) {
    if (typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({ error: 'Name must be a non-empty string' });
    }
    family.name = name.trim();
  }
  if (members !== undefined) {
    if (!Array.isArray(members)) {
      return res.status(400).json({ error: 'Members must be an array of strings' });
    }
    family.members = members.map(String);
  }
  family.updatedAt = new Date().toISOString();
  res.json(family);
});

// DELETE /api/v1/families/:family_id
app.delete('/api/v1/families/:family_id', (req, res) => {
  const { family_id } = req.params;
  const idx = families.findIndex(f => f.id === family_id);
  if (idx === -1) return res.status(404).json({ error: 'Family not found' });
  families.splice(idx, 1);
  res.status(204).send();
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  // Single line, clear startup log useful for container logs and App Service logs
  console.log(`Server started: http://localhost:${port} (pid ${process.pid})`);
});
