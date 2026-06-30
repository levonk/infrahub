#!/bin/sh
set -e

# Healthcheck for OmniRoute — uses node since base image has no wget/nc
PORT="${AI_OMNIROUTE_CONTAINER_PORT:-20128}"
node -e "
  const http = require('http');
  const req = http.get('http://localhost:' + process.env.PORT + '/v1/models', (res) => {
    process.exit(res.statusCode < 500 ? 0 : 1);
  });
  req.on('error', () => process.exit(1));
  req.setTimeout(3000, () => { req.destroy(); process.exit(1); });
" 2>/dev/null
