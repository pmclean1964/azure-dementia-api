// Health check endpoint for Azure Functions (HTTP GET /api/healthz)
// - Shallow: returns 200 if function is running
// - Deep DB check (?deep=db): attempts a lightweight DB query (SELECT 1)
//   using env vars provided via Key Vault references:
//   DB_FQDN, DB_NAME, DB_LOGIN, DB_PASSWORD
//   If DB_LOGIN/PASSWORD are absent, attempts Managed Identity authentication.

const sql = require('mssql');
const { ManagedIdentityCredential, DefaultAzureCredential } = require('@azure/identity');

// Acquire an access token for Azure SQL using Managed Identity (preferred) or Default credentials as fallback
async function getAzureSqlAccessToken() {
  // ManagedIdentityCredential works in Azure; DefaultAzureCredential helps local dev (if logged in via Azure CLI)
  const credential = new ManagedIdentityCredential();
  try {
    const token = await credential.getToken('https://database.windows.net/.default');
    return token && token.token;
  } catch (e) {
    // Fallback to DefaultAzureCredential for local debugging scenarios
    const def = new DefaultAzureCredential();
    const token = await def.getToken('https://database.windows.net/.default');
    return token && token.token;
  }
}


// hope thhis works

async function checkDbConnectivity(signal) {
  const server = process.env.DB_FQDN;
  const database = process.env.DB_NAME;
  const user = process.env.DB_LOGIN;
  const password = process.env.DB_PASSWORD;

  if (!server || !database) {
    // Missing minimal configuration to even attempt a connection.
    return { ok: false, reason: 'missing_config', detail: 'DB_FQDN and/or DB_NAME not set' };
  }

  const baseConfig = {
    server,
    database,
    options: {
      encrypt: true,
      enableArithAbort: true,
      trustServerCertificate: false
    }
  };

  let config;
  if (user && password) {
    config = { ...baseConfig, user, password }; // SQL auth
  } else {
    const accessToken = await getAzureSqlAccessToken();
    if (!accessToken) {
      return { ok: false, reason: 'no_token', detail: 'Failed to acquire managed identity token' };
    }
    config = {
      ...baseConfig,
      authentication: {
        type: 'azure-active-directory-access-token',
        options: { token: accessToken }
      }
    };
  }
  //test
  // Support cancellation via AbortSignal (if provided)
  const connection = new sql.ConnectionPool(config);
  let pool;
  const start = Date.now();
  try {
    pool = await connection.connect();
    if (signal && signal.aborted) {
      return { ok: false, reason: 'aborted' };
    }
    const result = await pool.request().query('SELECT 1 AS n');
    const durationMs = Date.now() - start;
    const ok = Array.isArray(result.recordset) && result.recordset.length > 0;
    return { ok, durationMs };
  } catch (err) {
    return { ok: false, reason: 'query_failed', error: `${err.name || 'Error'}: ${err.message || String(err)}` };
  } finally {
    try { if (pool) await pool.close(); } catch (_) {}
  }
}

module.exports = async function (context, req) {
  const deep = (req.query && req.query.deep) || undefined;

  // Always report function is up for shallow health checks
  if (!deep || deep.toLowerCase() !== 'db') {
    context.res = {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: { ok: true, mode: 'shallow', timestamp: new Date().toISOString() }
    };
    return;
  }

  // Deep DB health check with a soft timeout (e.g., 5 seconds)
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);

  const db = await checkDbConnectivity(controller.signal);
  clearTimeout(timeout);

  if (db.ok) {
    context.res = {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: { ok: true, mode: 'deep', timestamp: new Date().toISOString(), db: { status: 'up', durationMs: db.durationMs } }
    };
  } else {
    // Return minimal error information; avoid leaking sensitive details
    context.res = {
      status: 503,
      headers: { 'Content-Type': 'application/json' },
      body: { ok: false, mode: 'deep', timestamp: new Date().toISOString(), db: { status: 'down', reason: db.reason } }
    };
  }
};
