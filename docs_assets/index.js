// Serve local Swagger UI assets from node_modules/swagger-ui-dist
// Route: GET /api/docs/assets/{*path}
// Only allows a small whitelist of files we reference in docs/index.js

const path = require('path');
const fs = require('fs');

module.exports = async function (context, req) {
  try {
    const rawPath = (context.bindingData && (context.bindingData.path || context.bindingData["*path"])) || '';
    const requested = path.posix.normalize(String(rawPath || ''));

    // Whitelist of allowed files
    const allowed = new Set([
      'swagger-ui.css',
      'swagger-ui-bundle.js'
    ]);

    const fileName = path.posix.basename(requested);
    if (!allowed.has(fileName)) {
      context.res = { status: 404, body: 'Not found' };
      return;
    }

    const filePath = path.join(__dirname, '..', 'node_modules', 'swagger-ui-dist', fileName);

    // Determine content type
    const contentType = fileName.endsWith('.css')
      ? 'text/css; charset=utf-8'
      : 'application/javascript; charset=utf-8';

    const data = fs.readFileSync(filePath);

    context.res = {
      status: 200,
      headers: {
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=86400'
      },
      body: data
    };
  } catch (err) {
    context.res = { status: 500, body: `Asset error: ${err && err.message ? err.message : String(err)}` };
  }
};