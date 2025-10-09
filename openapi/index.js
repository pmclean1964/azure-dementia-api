// OpenAPI JSON generator for the API
// Route: GET /api/openapi.json

module.exports = async function (context, req) {
  const serverUrl = inferServerUrl(req);

  const openapi = {
    openapi: '3.0.3',
    info: {
      title: 'Dementia API - Serverless',
      version: '1.0.0',
      description: 'API documentation for the Dementia Serverless project.'
    },
    servers: [
      { url: serverUrl }
    ],
    paths: {
      '/healthz': {
        get: {
          summary: 'Health check',
          description: 'Shallow or deep health check. Use ?deep=db to perform a DB connectivity check.',
          parameters: [
            {
              name: 'deep',
              in: 'query',
              required: false,
              schema: { type: 'string', enum: ['db'] },
              description: 'If set to "db", performs a database connectivity check.'
            }
          ],
          responses: {
            '200': {
              description: 'Service healthy',
              content: {
                'application/json': {
                  schema: {
                    type: 'object',
                    properties: {
                      ok: { type: 'boolean', example: true },
                      mode: { type: 'string', enum: ['shallow', 'deep'] },
                      db: {
                        type: 'object',
                        nullable: true,
                        properties: {
                          status: { type: 'string', enum: ['up'] },
                          durationMs: { type: 'number' }
                        }
                      }
                    }
                  }
                }
              }
            },
            '503': {
              description: 'Service unhealthy (DB down when deep=db)',
              content: {
                'application/json': {
                  schema: {
                    type: 'object',
                    properties: {
                      ok: { type: 'boolean', example: false },
                      mode: { type: 'string', enum: ['deep'] },
                      db: {
                        type: 'object',
                        properties: {
                          status: { type: 'string', enum: ['down'] },
                          reason: { type: 'string' }
                        }
                      }
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

  context.res = {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store'
    },
    body: openapi
  };
};

function inferServerUrl(req) {
  try {
    const proto = req.headers && (req.headers['x-forwarded-proto'] || req.headers['X-Forwarded-Proto']);
    const host = req.headers && (req.headers['x-forwarded-host'] || req.headers['X-Forwarded-Host'] || req.headers['host'] || req.headers['Host']);
    let base = null;
    if (proto && host) {
      base = `${proto}://${host}`;
    } else if (host) {
      base = `https://${host}`;
    }
    // Azure Functions default route prefix is /api
    if (base) return `${base}/api`;
  } catch (_) {}
  // Fallback relative path base
  return '/api';
}
