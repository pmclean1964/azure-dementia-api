// Redirect /api/doc -> /api/docs
module.exports = async function (context, req) {
  const host = (req.headers && (req.headers['x-forwarded-host'] || req.headers['X-Forwarded-Host'] || req.headers['host'] || req.headers['Host'])) || '';
  const proto = (req.headers && (req.headers['x-forwarded-proto'] || req.headers['X-Forwarded-Proto'])) || 'https';
  const base = host ? `${proto}://${host}` : '';
  const location = base ? `${base}/api/docs` : '/api/docs';

  context.res = {
    status: 302,
    headers: {
      Location: location,
      'Cache-Control': 'no-store'
    },
    body: `Redirecting to ${location}`
  };
};