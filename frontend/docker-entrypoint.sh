#!/bin/sh
# Runtime config: backend URL comes from the API_URL env var of the container.
echo "window.__CONFIG__ = { API_URL: \"${API_URL:-http://localhost:8080}\" };" > /usr/share/nginx/html/config.js
