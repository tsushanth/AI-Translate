# Backend Deployment Guide - AI Translate

## Overview

This guide covers deploying the AI Translate backend to **Google Cloud Run** with:
- **Google Cloud Translation API** for translations
- **Supabase** for PostgreSQL logging/storage
- **Docker** for containerization

---

## Prerequisites

### Tools Required

```bash
# Install Google Cloud CLI
brew install google-cloud-sdk

# Install Docker
brew install docker

# Install Node.js 20+
brew install node@20

# Verify installations
gcloud --version
docker --version
node --version  # Should be 20.x
```

### Accounts Required

1. **Google Cloud Platform** account with billing enabled
2. **Supabase** account (free tier works for development)

---

## 1. Google Cloud Platform Setup

### 1.1 Create Project

```bash
# Set your project ID
export PROJECT_ID="ai-translate-prod"

# Create new project
gcloud projects create $PROJECT_ID --name="AI Translate"

# Set as active project
gcloud config set project $PROJECT_ID

# Link billing account (required for APIs)
# Do this in Cloud Console: https://console.cloud.google.com/billing
```

### 1.2 Enable Required APIs

```bash
# Enable all required APIs
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    translate.googleapis.com \
    secretmanager.googleapis.com \
    artifactregistry.googleapis.com
```

### 1.3 Create Service Account

```bash
# Create service account for Cloud Run
gcloud iam service-accounts create ai-translate-backend \
    --display-name="AI Translate Backend"

# Grant Translation API access
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:ai-translate-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudtranslate.user"

# Grant Secret Manager access (for environment variables)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:ai-translate-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

### 1.4 Create Artifact Registry Repository

```bash
# Create Docker repository
gcloud artifacts repositories create ai-translate \
    --repository-format=docker \
    --location=us-central1 \
    --description="AI Translate container images"

# Configure Docker to use Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev
```

---

## 2. Supabase Setup

### 2.1 Create Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Choose region closest to your Cloud Run region
4. Save the database password securely

### 2.2 Get Connection Details

From Supabase Dashboard → Settings → API:

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

⚠️ **Use the `service_role` key, not the `anon` key** (for server-side access)

### 2.3 Create Database Schema

Run this SQL in Supabase SQL Editor:

```sql
-- Translation logs table
CREATE TABLE translation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    source_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_language TEXT NOT NULL,
    target_language TEXT NOT NULL,
    detected_language TEXT,
    character_count INTEGER NOT NULL,
    processing_time_ms INTEGER NOT NULL,
    request_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for device queries
CREATE INDEX idx_translation_logs_device_id ON translation_logs(device_id);

-- Index for time-based queries
CREATE INDEX idx_translation_logs_created_at ON translation_logs(created_at DESC);

-- Row Level Security (RLS)
ALTER TABLE translation_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can do everything
CREATE POLICY "Service role full access" ON translation_logs
    FOR ALL
    USING (auth.role() = 'service_role');

-- Optional: Cleanup old logs (run periodically)
-- DELETE FROM translation_logs WHERE created_at < NOW() - INTERVAL '30 days';
```

### 2.4 Verify Connection

Test from your local machine:

```bash
curl "https://xxxxx.supabase.co/rest/v1/translation_logs?select=count" \
  -H "apikey: YOUR_SERVICE_KEY" \
  -H "Authorization: Bearer YOUR_SERVICE_KEY"
```

---

## 3. Create Dockerfile

Create `backend/Dockerfile`:

```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source
COPY . .

# Build TypeScript
RUN npm run build

# Production stage
FROM node:20-alpine AS production

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy built files from builder
COPY --from=builder /app/dist ./dist

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Start server
CMD ["node", "dist/index.js"]
```

Create `backend/.dockerignore`:

```
node_modules
dist
.env
.env.local
*.log
.git
.gitignore
README.md
*.md
.DS_Store
coverage
.nyc_output
```

---

## 4. Store Secrets in Secret Manager

```bash
# Store Supabase URL
echo -n "https://xxxxx.supabase.co" | \
    gcloud secrets create SUPABASE_URL --data-file=-

# Store Supabase service key
echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." | \
    gcloud secrets create SUPABASE_SERVICE_KEY --data-file=-

# Grant Cloud Run access to secrets
gcloud secrets add-iam-policy-binding SUPABASE_URL \
    --member="serviceAccount:ai-translate-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding SUPABASE_SERVICE_KEY \
    --member="serviceAccount:ai-translate-backend@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

---

## 5. Build and Deploy

### 5.1 Build Docker Image

```bash
cd backend

# Build image
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/ai-translate/backend:latest .

# Push to Artifact Registry
docker push us-central1-docker.pkg.dev/$PROJECT_ID/ai-translate/backend:latest
```

Or use Cloud Build (recommended for CI/CD):

```bash
# Submit build to Cloud Build
gcloud builds submit --tag us-central1-docker.pkg.dev/$PROJECT_ID/ai-translate/backend:latest
```

### 5.2 Deploy to Cloud Run

```bash
gcloud run deploy ai-translate-backend \
    --image us-central1-docker.pkg.dev/$PROJECT_ID/ai-translate/backend:latest \
    --region us-central1 \
    --platform managed \
    --allow-unauthenticated \
    --service-account ai-translate-backend@$PROJECT_ID.iam.gserviceaccount.com \
    --set-env-vars "NODE_ENV=production,GOOGLE_CLOUD_PROJECT=$PROJECT_ID" \
    --set-secrets "SUPABASE_URL=SUPABASE_URL:latest,SUPABASE_SERVICE_KEY=SUPABASE_SERVICE_KEY:latest" \
    --memory 512Mi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 10 \
    --concurrency 80 \
    --timeout 60s
```

### 5.3 Get Service URL

```bash
# Get the deployed URL
gcloud run services describe ai-translate-backend \
    --region us-central1 \
    --format 'value(status.url)'

# Output: https://ai-translate-backend-xxxxx-uc.a.run.app
```

---

## 6. Verify Deployment

### 6.1 Health Check

```bash
curl https://ai-translate-backend-xxxxx-uc.a.run.app/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### 6.2 Test Translation

```bash
curl -X POST https://ai-translate-backend-xxxxx-uc.a.run.app/v1/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, world!",
    "sourceLanguage": "en",
    "targetLanguage": "es",
    "deviceId": "test-device-123"
  }'
```

Expected response:
```json
{
  "success": true,
  "data": {
    "translatedText": "¡Hola, mundo!",
    "sourceLanguage": "en",
    "targetLanguage": "es",
    "characterCount": 13
  },
  "meta": {
    "requestId": "550e8400-e29b-41d4-a716-446655440000",
    "processingTimeMs": 245
  }
}
```

### 6.3 Check Logs

```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ai-translate-backend" \
    --limit 50 \
    --format "table(timestamp,jsonPayload.message)"
```

---

## 7. iOS App Configuration

Update your iOS app's `AppConfig.swift`:

```swift
enum AppConfig {
    static var cloudRunBaseURL: URL {
        #if DEBUG
        // Use staging URL for development
        return URL(string: "https://ai-translate-backend-staging-xxxxx-uc.a.run.app")!
        #else
        // Production URL
        return URL(string: "https://ai-translate-backend-xxxxx-uc.a.run.app")!
        #endif
    }
}
```

---

## 8. Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | No | 8080 | Server port |
| `NODE_ENV` | No | production | Environment mode |
| `GOOGLE_CLOUD_PROJECT` | Yes | - | GCP project ID |
| `SUPABASE_URL` | Yes | - | Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Yes | - | Supabase service role key |
| `RATE_LIMIT_WINDOW_MS` | No | 60000 | Rate limit window (ms) |
| `RATE_LIMIT_MAX_REQUESTS` | No | 100 | Max requests per window |
| `ENABLE_TRANSLATION_LOGGING` | No | true | Log translations to Supabase |

---

## 9. CI/CD Setup (GitHub Actions)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'

env:
  PROJECT_ID: ai-translate-prod
  REGION: us-central1
  SERVICE: ai-translate-backend

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Google Auth
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Build and Push
        run: |
          cd backend
          docker build -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/ai-translate/backend:${{ github.sha }} .
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/ai-translate/backend:${{ github.sha }}

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy ${{ env.SERVICE }} \
            --image ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/ai-translate/backend:${{ github.sha }} \
            --region ${{ env.REGION }}
```

Add these secrets to GitHub repository:
- `GCP_SA_KEY`: Service account key JSON

---

## 10. Monitoring & Alerts

### 10.1 Set Up Alerting

```bash
# Create notification channel (email)
gcloud alpha monitoring channels create \
    --display-name="AI Translate Alerts" \
    --type=email \
    --channel-labels=email_address=your-email@example.com

# Get channel ID
CHANNEL_ID=$(gcloud alpha monitoring channels list --format='value(name)' | head -1)

# Create alert for high error rate
gcloud alpha monitoring policies create \
    --notification-channels=$CHANNEL_ID \
    --display-name="High Error Rate" \
    --condition-display-name="Error rate > 5%" \
    --condition-filter='resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"'
```

### 10.2 View Metrics

Go to Cloud Console → Cloud Run → ai-translate-backend → Metrics

Key metrics to monitor:
- Request count
- Request latency (p50, p95, p99)
- Container instance count
- Memory utilization
- Error rate

---

## 11. Cost Estimation

### Cloud Run (Pay per use)
- CPU: $0.00002400/vCPU-second
- Memory: $0.00000250/GiB-second
- Requests: $0.40/million requests

**Example**: 100,000 translations/month @ 500ms each
- ~$5-10/month for Cloud Run

### Cloud Translation API
- $20 per 1 million characters

**Example**: 100,000 translations @ 50 chars average
- 5 million characters = ~$100/month

### Supabase
- Free tier: 500MB database, 2GB bandwidth
- Pro: $25/month for 8GB database

**Total Estimate**: $50-150/month for moderate usage

---

## 12. Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Permission denied" on Translation API | Verify service account has `cloudtranslate.user` role |
| "Invalid Supabase key" | Check you're using `service_role` key, not `anon` |
| Container crashes on start | Check logs: `gcloud logging read` |
| High latency | Consider min-instances=1 to avoid cold starts |
| Rate limiting | Increase `RATE_LIMIT_MAX_REQUESTS` |

### Debug Commands

```bash
# View recent logs
gcloud run services logs read ai-translate-backend --region us-central1 --limit 100

# Check service status
gcloud run services describe ai-translate-backend --region us-central1

# List revisions
gcloud run revisions list --service ai-translate-backend --region us-central1

# Rollback to previous revision
gcloud run services update-traffic ai-translate-backend \
    --to-revisions=PREVIOUS_REVISION=100 \
    --region us-central1
```

---

## Quick Start Summary

```bash
# 1. Set project
export PROJECT_ID="ai-translate-prod"
gcloud config set project $PROJECT_ID

# 2. Enable APIs
gcloud services enable run.googleapis.com translate.googleapis.com

# 3. Build and deploy
cd backend
gcloud builds submit --tag gcr.io/$PROJECT_ID/ai-translate-backend
gcloud run deploy ai-translate-backend \
    --image gcr.io/$PROJECT_ID/ai-translate-backend \
    --region us-central1 \
    --allow-unauthenticated \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=$PROJECT_ID" \
    --set-secrets "SUPABASE_URL=SUPABASE_URL:latest,SUPABASE_SERVICE_KEY=SUPABASE_SERVICE_KEY:latest"

# 4. Test
curl $(gcloud run services describe ai-translate-backend --region us-central1 --format 'value(status.url)')/health
```
