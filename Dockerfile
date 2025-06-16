# Build stage
FROM caddy:2-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/greenpau/caddy-security \
    --with github.com/hslatman/caddy-crowdsec-bouncer/http \
    --with github.com/mholt/caddy-ratelimit \
    --with github.com/mholt/caddy-l4 \
    --with github.com/caddyserver/transform-encoder \
    --with github.com/caddyserver/cache-handler

# Runtime stage
FROM caddy:2-alpine

# Copy custom Caddy binary from builder
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# Install required runtime dependencies
RUN apk add --no-cache ca-certificates tzdata curl jq

# Create non-root user for Caddy
RUN adduser -D -H -s /bin/sh caddy

# Create necessary directories
RUN mkdir -p /config /data /etc/caddy /etc/caddy/rules /etc/caddy/configs /var/log/caddy /data/cache && \
    chown -R caddy:caddy /config /data /etc/caddy /var/log/caddy

# Copy Caddy configuration and rules
COPY Caddyfile /etc/caddy/Caddyfile
COPY --chown=caddy:caddy configs/ /etc/caddy/configs/
COPY --chown=caddy:caddy rules/ /etc/caddy/rules/

# Use non-root user
USER caddy

# Expose ports
EXPOSE 80 443 2019 9090

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:2019/health || exit 1

# Set default environment variables
ENV CADDY_AGREE=true
ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data

# Volume for certificates and config
VOLUME ["/config", "/data", "/etc/caddy/configs", "/etc/caddy/rules", "/var/log/caddy"]

# Start Caddy
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]