function checkApiKey(req) {
  const headerKey = (req.headers && (req.headers['x-api-key'] || req.headers['X-API-KEY'])) || undefined;
  const expected = process.env.API_KEY;
  if (!expected) {
    const e = new Error('API key not configured'); e.status = 500; throw e;
  }
  if (!headerKey || headerKey !== expected) {
    const e = new Error('Unauthorized: missing or invalid API key'); e.status = 401; throw e;
  }
}

module.exports = { checkApiKey };
