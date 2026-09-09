
# Deploy one portfolio-infra service from its GHCR image, then prove what shipped.
#
# Pipe this to the droplet over stdin from the PowerShell tool, which avoids the
# quote stripping that mangles inline remote commands:
#
#   $s = [System.IO.File]::ReadAllText($path)
#   $s = $s.TrimStart([char]0xFEFF) -replace "`r",""
#   $s | ssh -o BatchMode=yes portfolio bash -s
#
# Set SERVICE and SHA below. The blank first line is deliberate: it absorbs a BOM
# that survives the pipe. Expect the ssh call to exit 127 from that BOM and from a
# trailing carriage return even when every step passed. Read the output, not the
# exit code.
#
# set -u only, never set -eu: one failed probe must not abort the report.

set -u

SERVICE=portfolio-hub
SHA=REPLACE_WITH_FULL_COMMIT_SHA
IMG=ghcr.io/msschermer/$SERVICE

cd ~/portfolio-infra || exit 1

if docker compose version >/dev/null 2>&1; then COMPOSE="docker compose"; else COMPOSE="docker-compose"; fi
echo "service=$SERVICE compose=$COMPOSE"

echo "=== 1. pre-deploy image (ROLLBACK POINT: record this) ==="
docker inspect "$SERVICE" --format '{{.Image}}'

echo "=== 2. volumes: is this service stateless? ==="
docker inspect "$SERVICE" --format '{{json .Mounts}}'
echo "(non-empty mounts means snapshot the data before replacing the container)"

echo "=== 3. digest of the immutable SHA tag (also proves the Actions build passed) ==="
SHADIG=$(docker manifest inspect -v "$IMG:$SHA" 2>/dev/null | grep -m1 '"digest"' | sed 's/.*: *"//; s/".*//')
if [ -z "$SHADIG" ]; then
  echo "SHA TAG NOT FOUND. The build failed, has not finished, or auth is gone. Stopping."
  exit 1
fi
echo "sha-tag digest: $SHADIG"

echo "=== 4. pull latest ==="
$COMPOSE pull "$SERVICE" 2>&1 | tail -5

echo "=== 5. confirm :latest is the audited commit ==="
LATDIG=$(docker manifest inspect -v "$IMG:latest" 2>/dev/null | grep -m1 '"digest"' | sed 's/.*: *"//; s/".*//')
echo "latest  digest: $LATDIG"
if [ "$SHADIG" = "$LATDIG" ]; then
  echo "MATCH: :latest resolves to the commit being deployed"
else
  echo "MISMATCH: :latest is NOT the audited commit. Investigate before continuing."
fi

echo "=== 6. recreate this service only ==="
$COMPOSE up -d --no-deps "$SERVICE" 2>&1 | tail -10

echo "=== 7. wait for health ==="
H=none
i=0
while [ $i -lt 30 ]; do
  H=$(docker inspect "$SERVICE" --format '{{.State.Health.Status}}' 2>/dev/null || echo none)
  if [ "$H" = "healthy" ]; then break; fi
  i=$((i+1)); sleep 2
done
echo "health after $i polls: $H  (a service with no healthcheck reports none)"
echo "post-deploy image: $(docker inspect "$SERVICE" --format '{{.Image}}')"

echo "=== 8. content inside the container ==="
# Static site: hash must equal sha256sum public/index.html locally.
# Note: wc -c < path would read the HOST path. Pass the path as an argument.
if [ "$SERVICE" = "portfolio-hub" ]; then
  docker exec "$SERVICE" sha256sum \
    /usr/share/nginx/html/index.html \
    /usr/share/nginx/html/favicon.svg \
    /usr/share/nginx/html/og-image.png
else
  echo "(source-built service: grep for a string the change introduced under /app)"
fi

echo "=== 9. loopback, service isolated from the proxy ==="
docker exec caddy wget -qO- --server-response "http://$SERVICE:80/" 2>&1 | grep -m1 'HTTP/'

echo "=== 10. loopback through caddy: 308 is a PASS ==="
curl -s -o /dev/null -w 'http via caddy: %{http_code}\n' -H 'Host: msschermer.us' http://localhost/
echo "(skipping https://localhost on purpose: caddy is per-SNI, it always returns 000)"

echo "=== 11. nothing else disturbed ==="
docker ps --format '{{.Names}} | {{.Status}}'

echo "=== REMAINING: verify public HTTPS from Windows, apex and www. ==="
echo "Compare markers and status only. Never hash the public body: Cloudflare injects into it."
