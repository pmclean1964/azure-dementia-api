const sql = require('mssql');
const { DefaultAzureCredential, ManagedIdentityCredential, ChainedTokenCredential } = require('@azure/identity');

const credential = new ChainedTokenCredential(
  new ManagedIdentityCredential(),
  new DefaultAzureCredential()
);

const sqlServer = process.env.SQL_SERVER;      // e.g., dementia-sql-xxxxx.database.windows.net
const sqlDatabase = process.env.SQL_DATABASE;  // e.g., dementia
const encrypt = (process.env.SQL_ENCRYPT || 'true').toLowerCase() !== 'false';

let pool;

async function getAccessToken() {
  const token = await credential.getToken('https://database.windows.net/.default');
  return token && token.token;
}

async function getPool() {
  if (pool && pool.connected) return pool;

  const accessToken = await getAccessToken();
  if (!accessToken) throw new Error('Failed to acquire access token for Azure SQL.');

  const config = {
    server: sqlServer,
    database: sqlDatabase,
    options: {
      encrypt,
      enableArithAbort: true
    },
    authentication: {
      type: 'azure-active-directory-access-token',
      options: { token: accessToken }
    },
    pool: { max: 10, min: 0, idleTimeoutMillis: 30000 }
  };

  pool = await sql.connect(config);

  // Refresh token every ~4 minutes
  setInterval(async () => {
    try {
      const t = await getAccessToken();
      pool.config.authentication.options.token = t;
    } catch (e) {
      console.error('Token refresh failed', e);
    }
  }, 4 * 60 * 1000);

  return pool;
}

module.exports = { getPool };
