#!/bin/bash
# Script to update docker-compose.yml - convert 6 containers to restart=no
# Containers: dmr-watchdog, dmr-lan-proxy, linkedin-mcp-server, linkedin-browser-sidecar, facebook-browser-sidecar, stack-ops

cd /home/tbaltzakis/cu130-slim

# Create backup
cp docker-compose.yml docker-compose.yml.bak.$(date +%Y%m%d_%H%M%S)

# Use sed to replace restart policies for specific services
# We need to be careful - only change the restart line within each service block

# For dmr-watchdog: change "restart: unless-stopped" to "restart: no"
sed -i '/^  dmr-watchdog:/,/^  [a-z]/ s/^\(    restart: \)unless-stopped/\1no/' docker-compose.yml

# For dmr-lan-proxy: change "restart: unless-stopped" to "restart: no"
sed -i '/^  dmr-lan-proxy:/,/^  [a-z]/ s/^\(    restart: \)unless-stopped/\1no/' docker-compose.yml

# For linkedin-mcp-server: change "restart: unless-stopped" to "restart: no"
sed -i '/^  linkedin-mcp-server:/,/^  [a-z]/ s/^\(    restart: \)unless-stopped/\1no/' docker-compose.yml

# For linkedin-browser-sidecar: change "restart: unless-stopped" to "restart: no"
sed -i '/^  linkedin-browser-sidecar:/,/^  [a-z]/ s/^\(    restart: \)unless-stopped/\1no/' docker-compose.yml

# For facebook-browser-sidecar: change "restart: unless-stopped" to "restart: no"
sed -i '/^  facebook-browser-sidecar:/,/^  [a-z]/ s/^\(    restart: \)unless-stopped/\1no/' docker-compose.yml

# For stack-ops: change "restart: always" to "restart: no"
sed -i '/^  stack-ops:/,/^  [a-z]/ s/^\(    restart: \)always/\1no/' docker-compose.yml

echo "docker-compose.yml updated successfully"

# Verify changes
echo "=== Verification ==="
grep -A 2 -E "^  (dmr-watchdog|dmr-lan-proxy|linkedin-mcp-server|linkedin-browser-sidecar|facebook-browser-sidecar|stack-ops):" docker-compose.yml | grep -E "(^[  ]*[a-z]|restart:)"