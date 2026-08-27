const fs = require('fs');

const prefixes = (process.env.API_PATH_PREFIXES || process.env.API_PATH_PREFIX || '')
  .split(',')
  .map((prefix) => prefix.trim())
  .filter(Boolean);
if (!prefixes.length) {
  throw new Error('API_PATH_PREFIX or API_PATH_PREFIXES must be set');
}

const sourcePath = './api/openbanking.json';
const outputPath = './api/service.json';
const spec = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));

spec.paths = Object.fromEntries(
  Object.entries(spec.paths).filter(([path]) =>
    prefixes.some((prefix) => path === prefix || path.startsWith(`${prefix}/`)),
  ),
);

if (process.env.API_SERVER_URL) {
  spec.servers = [{ url: process.env.API_SERVER_URL }];
}

fs.writeFileSync(outputPath, JSON.stringify(spec, null, 2));
