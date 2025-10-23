# Kong API Gateway for BidderGod

This directory contains the Kong API Gateway configuration for AWS ECS deployment.

## Overview

Kong acts as the single entry point for all BidderGod microservices, providing:
- **API Routing**: Routes requests to appropriate microservices
- **CORS Handling**: Configured for frontend access
- **Rate Limiting**: Protects services from overload
- **Service Discovery**: Uses AWS Cloud Map DNS (`.biddergod-dev.local`)

## Files

- `Dockerfile` - Builds custom Kong image with embedded configuration
- `kong.yml` - Declarative configuration for routes and plugins
- `.github/workflows/kong-ecr.yml` - GitHub Actions CI/CD pipeline

## Configuration

### Service URLs (AWS Cloud Map)

All services use private DNS resolution via AWS Cloud Map:

```yaml
http://user-service.biddergod-dev.local:8080
http://auction-service.biddergod-dev.local:4000
http://bid-command.biddergod-dev.local:8080
http://bid-query.biddergod-dev.local:8080
http://payment-service.biddergod-dev.local:3000
http://sse-stream-service.biddergod-dev.local:8086
```

### API Routes

| External Path | Method | Internal Service | Description |
|--------------|--------|------------------|-------------|
| `/api/users` | ALL | user-service:8080 | User management |
| `/api/auctions` | ALL | auction-service:4000/auctions | Auction CRUD |
| `/api/auction-health` | GET | auction-service:4000/health | Health check |
| `/api/v1/bids` | POST | bid-command:8080 | Place bids (write) |
| `/api/v1/bids` | GET | bid-query:8080 | Query bids (read) |
| `/api/payments` | ALL | payment-service:3000 | Payment processing |
| `/events` | GET | sse-stream-service:8086 | Server-Sent Events |

### Plugins

**CORS** - All services:
- Origins: `*` (all origins allowed)
- Credentials: Enabled
- Max age: 3600s

**Rate Limiting**:
- User Service: 100 req/min
- Auction Service: 100 req/min
- Bid Command: 200 req/min
- Bid Query: 300 req/min
- Payment Service: 50 req/min
- SSE: No rate limiting (long-lived connections)

## Deployment

### 1. Build and Push Image

```bash
cd kong-gateway/

# Build locally (optional)
docker build -t kong-gateway .

# Deploy via GitHub Actions
git tag kong-1.0.0
git push origin kong-1.0.0
```

### 2. Verify Deployment

```bash
# Check Kong service status
make get-service-ip-kong

# Test Kong health
KONG_IP=$(make -s get-service-ip-kong)
curl http://$KONG_IP:8000/status

# Test API routing
curl http://$KONG_IP:8000/api/users
curl http://$KONG_IP:8000/api/auctions
```

### 3. Access Kong Admin API

```bash
# Get Kong IP
KONG_IP=$(make -s get-service-ip-kong)

# View all configured services
curl http://$KONG_IP:8001/services

# View all routes
curl http://$KONG_IP:8001/routes

# View plugins
curl http://$KONG_IP:8001/plugins
```

## Updating Configuration

### Modify Routes

1. Edit `kong.yml` to add/modify routes
2. Commit changes
3. Tag and push:
   ```bash
   git tag kong-1.1.0
   git push origin kong-1.1.0
   ```
4. GitHub Actions will automatically build and deploy

### Configuration Format

```yaml
services:
  - name: my-service
    url: http://my-service.biddergod-dev.local:8080
    routes:
      - name: my-route
        paths:
          - /api/my-path
        strip_path: false  # Keep /api/my-path in upstream request
    plugins:
      - name: cors
        config:
          origins: ["*"]
      - name: rate-limiting
        config:
          minute: 100
```

## Troubleshooting

### Kong Won't Start

```bash
# Check logs
make logs-kong

# Common issues:
# 1. Invalid kong.yml syntax - validate YAML
# 2. Service discovery failing - check Cloud Map
# 3. Port conflicts - ensure port 8000/8001 are available
```

### Routes Not Working

```bash
# Verify Kong loaded configuration
KONG_IP=$(make -s get-service-ip-kong)
curl http://$KONG_IP:8001/routes | jq

# Check if services are reachable from Kong
# Services must be running and registered in Cloud Map
make cloud-map-services
```

### CORS Errors

Kong CORS plugin is configured for all origins (`*`). If you still get CORS errors:

1. Check browser console for specific error
2. Verify the route matches (check paths in `kong.yml`)
3. Ensure OPTIONS requests are allowed

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP
       ↓
┌─────────────────────────────────┐
│  Kong API Gateway (Port 8000)   │
│  - Route matching                │
│  - CORS handling                 │
│  - Rate limiting                 │
│  - Request/response transform    │
└────────────┬────────────────────┘
             │ AWS Cloud Map DNS
             │ (.biddergod-dev.local)
             ↓
┌────────────────────────────────────┐
│      ECS Fargate Services          │
│  ┌──────────────────────────────┐  │
│  │ user-service        (8080)   │  │
│  │ auction-service     (4000)   │  │
│  │ bid-command         (8080)   │  │
│  │ bid-query           (8080)   │  │
│  │ payment-service     (3000)   │  │
│  │ sse-stream-service  (8086)   │  │
│  └──────────────────────────────┘  │
└────────────────────────────────────┘
```

## Kong Admin Endpoints

- **Proxy**: `http://<kong-ip>:8000` - Main API gateway
- **Admin API**: `http://<kong-ip>:8001` - Configuration and monitoring
- **Health**: `http://<kong-ip>:8000/status` - Health check endpoint

## Next Steps

1. **Monitor Kong**: Set up Prometheus metrics export
2. **Authentication**: Add JWT or OAuth2 plugin
3. **API Keys**: Add key-auth plugin for service-to-service auth
4. **Request Logging**: Enable file-log plugin for audit trails
5. **Custom Plugins**: Develop custom plugins for business logic

## References

- [Kong Documentation](https://docs.konghq.com/)
- [Kong DB-less Mode](https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/)
- [Kong Plugins](https://docs.konghq.com/hub/)
- [AWS Cloud Map](https://docs.aws.amazon.com/cloud-map/)