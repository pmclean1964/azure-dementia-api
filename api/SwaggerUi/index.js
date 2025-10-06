module.exports = async function (context, req) {
  const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Dementia API - Swagger</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist/swagger-ui.css" />
  </head>
  <body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist/swagger-ui-bundle.js"></script>
    <script>
      window.ui = SwaggerUIBundle({
        url: '/swagger.json',
        dom_id: '#swagger-ui',
        presets: [SwaggerUIBundle.presets.apis],
      });
    </script>
  </body>
</html>`;
  return { headers: { 'content-type': 'text/html; charset=utf-8' }, body: html };
}
