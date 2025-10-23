# API Reference Documentation

## Overview

The InfiniteEdge platform provides a comprehensive API ecosystem with 12 integrated AI services accessible through both a unified HTTP gateway and individual service endpoints.

## Gateway API (Port 8888)

### Base URL
```
http://localhost:8888
```

### Authentication
Currently using basic HTTP authentication. Production deployments should use OAuth 2.0 or JWT tokens.

### Health Check

**Get Gateway Health**
```http
GET /health
```

**Response:**
```
HTTP/1.1 200 OK
Content-Type: text/plain

HTTP Gateway Fallback - Healthy
```

### Service Routing

The gateway provides unified access to all backend services through path-based routing:

**AegisEdgeAI Access**
```http
GET /aegis/
GET /aegis/health
GET /aegis/api/v1/security/status
```

**YoMo Framework Access**  
```http
GET /yomo/
GET /yomo/health
GET /yomo/api/v1/zipper/status
```

**Shifu IoT Gateway Access**
```http
GET /shifu/
GET /shifu/health
GET /shifu/api/v1/devices
```

## Individual Service APIs

### 1. AegisEdgeAI API (Port 9080)

**Base URL:** `http://localhost:9080`

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy",
  "service": "aegis-edge-ai", 
  "timestamp": "2024-10-23T12:00:00Z",
  "version": "1.0.0"
}
```

#### Security Operations
```http
# Get security status
GET /api/v1/security/status

# Verify trust relationship
POST /api/v1/trust/verify
Content-Type: application/json

{
  "entity": "service-name",
  "credential": "trust-token"
}

# Scan for threats
POST /api/v1/security/scan
Content-Type: application/json

{
  "target": "network-endpoint",
  "scan_type": "vulnerability"
}
```

### 2. SPEAR API (Port 9081)

**Base URL:** `http://localhost:9081`  
**Status:** HTTP Fallback Mode

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy",
  "service": "spear",
  "mode": "fallback", 
  "timestamp": "2024-10-23T12:00:00Z"
}
```

#### Agent Operations (Fallback)
```http
# Get service info
GET /

Response:
<h1>SPEAR Service</h1><p>Service is running on port 8081</p>

# Agent communication (when available)
POST /api/v1/agents/deploy
POST /api/v1/agents/{id}/execute
GET /api/v1/agents/{id}/status
```

### 3. YoMo API (Port 9082)

**Base URL:** `http://localhost:9082`
**Status:** HTTP Fallback Mode

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy",
  "service": "yomo",
  "mode": "fallback",
  "timestamp": "2024-10-23T12:00:00Z"  
}
```

#### Serverless Operations (Fallback)
```http
# Get service info  
GET /

Response:
<h1>YoMo Service</h1><p>Service is running</p>

# Function invocation (when available)
POST /api/v1/functions/invoke
GET /api/v1/functions/{id}/status  
GET /api/v1/zipper/status
```

### 4. Shifu API (Port 9083)

**Base URL:** `http://localhost:9083`
**Status:** HTTP Fallback Mode

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy", 
  "service": "shifu",
  "mode": "fallback",
  "timestamp": "2024-10-23T12:00:00Z"
}
```

#### IoT Operations (Fallback)
```http
# Get service info
GET /

Response:  
<h1>Shifu Service</h1><p>Service is running</p>

# Device management (when available)
GET /api/v1/devices
POST /api/v1/devices/{id}/command
GET /api/v1/devices/{id}/status
```

### 5. AIOps API (Port 9084)

**Base URL:** `http://localhost:9084`

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy",
  "service": "aiops", 
  "timestamp": "2024-10-23T12:00:00Z"
}
```

#### Operations Monitoring
```http
# Get metrics
GET /api/v1/metrics

# Anomaly detection
POST /api/v1/anomaly/detect
Content-Type: application/json

{
  "metrics": [
    {"timestamp": "2024-10-23T12:00:00Z", "value": 85.2, "metric": "cpu_usage"},
    {"timestamp": "2024-10-23T12:01:00Z", "value": 92.1, "metric": "cpu_usage"}
  ]
}

# Get alerts
GET /api/v1/alerts
GET /api/v1/alerts/{id}
```

### 6. EDA API (Port 9085)

**Base URL:** `http://localhost:9085`

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy",
  "service": "eda",
  "timestamp": "2024-10-23T12:00:00Z"
}
```

#### Event Processing
```http
# Submit event
POST /api/v1/events
Content-Type: application/json

{
  "event_type": "sensor_reading",
  "payload": {
    "sensor_id": "temp_01", 
    "value": 23.5,
    "timestamp": "2024-10-23T12:00:00Z"
  }
}

# Query events
GET /api/v1/events?type=sensor_reading&from=2024-10-23T00:00:00Z

# Get event streams
GET /api/v1/streams
POST /api/v1/streams/{id}/subscribe
```

### 7. Edge Whisper API (Port 9086)

**Base URL:** `http://localhost:9086`

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy",
  "service": "edge-whisper",
  "timestamp": "2024-10-23T12:00:00Z"
}
```

#### Speech Recognition
```http
# Web interface
GET /

# Audio transcription  
POST /api/transcribe
Content-Type: multipart/form-data

{
  "audio": "@audio_file.wav",
  "language": "en",
  "model": "whisper-base"
}

Response:
{
  "transcription": "Hello, this is a test transcription",
  "confidence": 0.95,
  "duration": 2.3,
  "language": "en"
}

# WebSocket audio streaming
WS /ws/audio
```

### 8. Whisper Finetune API (Port 9087)

**Base URL:** `http://localhost:9087`

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy",
  "service": "whisper-finetune",
  "timestamp": "2024-10-23T12:00:00Z"
}
```

#### Model Training
```http
# Start training job
POST /api/v1/training/start
Content-Type: application/json

{
  "dataset": "speech_dataset_v1",
  "model": "whisper-small", 
  "epochs": 10,
  "learning_rate": 1e-5
}

Response:
{
  "job_id": "train_123456",
  "status": "started",
  "estimated_completion": "2024-10-23T18:00:00Z"
}

# Check training status
GET /api/v1/training/{job_id}/status

# Get training metrics  
GET /api/v1/training/{job_id}/metrics

# Download trained model
GET /api/v1/models/{model_id}/download
```

### 9. Megatron-LM API (Port 9088)

**Base URL:** `http://localhost:9088`

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy", 
  "service": "megatron-lm",
  "timestamp": "2024-10-23T12:00:00Z"
}
```

#### Large Model Operations
```http
# Model inference
POST /api/v1/generate
Content-Type: application/json

{
  "prompt": "The future of AI is",
  "max_tokens": 100,
  "temperature": 0.7,
  "model": "megatron-gpt-1.3b"
}

Response:
{
  "generated_text": "The future of AI is bright with advances in...",
  "tokens_generated": 95, 
  "inference_time": 2.1
}

# Model management
GET /api/v1/models
GET /api/v1/models/{id}/info
POST /api/v1/models/load
POST /api/v1/models/{id}/unload
```

### 10. Transformers API (Port 9089)

**Base URL:** `http://localhost:9089`

#### Health Check  
```http
GET /health

Response:
{
  "status": "healthy",
  "service": "transformers", 
  "timestamp": "2024-10-23T12:00:00Z"
}
```

#### Model Inference
```http
# Text classification
POST /api/v1/classify
Content-Type: application/json

{
  "text": "This movie is amazing!",
  "model": "bert-base-uncased"
}

Response:
{
  "predictions": [
    {"label": "POSITIVE", "confidence": 0.98},
    {"label": "NEGATIVE", "confidence": 0.02}
  ]
}

# Text generation
POST /api/v1/generate
Content-Type: application/json

{
  "prompt": "The weather today is",
  "model": "gpt2",
  "max_length": 50
}

# Question answering
POST /api/v1/qa
Content-Type: application/json

{
  "context": "The InfiniteEdge platform provides 12 AI services...",
  "question": "How many AI services does InfiniteEdge provide?",
  "model": "distilbert-base-cased-distilled-squad"
}

# Available models
GET /api/v1/models
```

### 11. Health Monitor API (Port 9090)

**Base URL:** `http://localhost:9090`

#### Health Check
```http
GET /health

Response:
{
  "status": "healthy",
  "service": "health-monitor",
  "timestamp": "2024-10-23T12:00:00Z"
}
```

#### System Monitoring
```http
# Overall system health
GET /api/v1/system/health

Response:
{
  "overall_status": "healthy",
  "services": {
    "aegis-edge-ai": "healthy",
    "spear": "healthy", 
    "yomo": "healthy",
    "shifu": "healthy"
    // ... all services
  },
  "performance": {
    "cpu_usage": 45.2,
    "memory_usage": 62.1, 
    "disk_usage": 33.8
  },
  "timestamp": "2024-10-23T12:00:00Z"
}

# Service-specific health
GET /api/v1/services/{service_name}/health

# Performance metrics
GET /api/v1/metrics?service={name}&from={timestamp}&to={timestamp}

# Alerts and notifications  
GET /api/v1/alerts
POST /api/v1/alerts/webhook
```

## Error Responses

### Standard Error Format

All APIs use a consistent error response format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message", 
    "details": "Additional error context",
    "timestamp": "2024-10-23T12:00:00Z",
    "service": "service-name",
    "request_id": "req_123456"
  }
}
```

### HTTP Status Codes

| Code | Description | Usage |
|------|-------------|--------|
| 200 | OK | Successful request |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Authentication required |
| 403 | Forbidden | Access denied |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Resource conflict |
| 422 | Unprocessable Entity | Validation errors |
| 500 | Internal Server Error | Server-side error |
| 502 | Bad Gateway | Backend service unavailable |
| 503 | Service Unavailable | Service temporarily down |
| 504 | Gateway Timeout | Backend timeout |

### Common Error Codes

#### Gateway Errors
```json
{
  "error": {
    "code": "BACKEND_UNAVAILABLE",
    "message": "Backend service temporarily unavailable",
    "details": "Service aegis-edge-ai is not responding"
  }
}
```

#### Authentication Errors  
```json
{
  "error": {
    "code": "INVALID_TOKEN", 
    "message": "Authentication token is invalid or expired"
  }
}
```

#### Validation Errors
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": {
      "field": "email",
      "message": "Invalid email format" 
    }
  }
}
```

## Rate Limiting

### Gateway Rate Limits
- **Default:** 100 requests per minute per IP
- **Burst:** Up to 20 requests per second  
- **Headers:** 
  - `X-RateLimit-Limit`: Request limit
  - `X-RateLimit-Remaining`: Remaining requests
  - `X-RateLimit-Reset`: Reset timestamp

### Service-Specific Limits

| Service | Rate Limit | Burst |
|---------|------------|-------|
| AegisEdgeAI | 1000/min | 50/sec |
| Edge Whisper | 100/min | 10/sec |
| Transformers | 500/min | 25/sec |
| Megatron-LM | 50/min | 5/sec |

## WebSocket APIs

### Edge Whisper Audio Streaming

```javascript
// Connect to audio streaming
const ws = new WebSocket('ws://localhost:9086/ws/audio');

ws.onopen = function() {
  console.log('Connected to audio stream');
};

ws.onmessage = function(event) {
  const data = JSON.parse(event.data);
  console.log('Transcription:', data.text);
};

// Send audio data
navigator.mediaDevices.getUserMedia({ audio: true })
  .then(stream => {
    const mediaRecorder = new MediaRecorder(stream);
    mediaRecorder.ondataavailable = event => {
      ws.send(event.data);
    };
    mediaRecorder.start(100); // Send data every 100ms
  });
```

### Real-time Monitoring

```javascript
// Connect to health monitoring stream
const ws = new WebSocket('ws://localhost:9090/ws/metrics');

ws.onmessage = function(event) {
  const metrics = JSON.parse(event.data);
  updateDashboard(metrics);
};
```

## SDK Examples

### Python SDK

```python
import requests
import json

class InfiniteEdgeClient:
    def __init__(self, gateway_url="http://localhost:8888"):
        self.gateway_url = gateway_url
        self.session = requests.Session()
    
    def health_check(self):
        """Check gateway health"""
        response = self.session.get(f"{self.gateway_url}/health")
        return response.text
    
    def aegis_security_scan(self, target):
        """Run security scan via AegisEdgeAI"""
        url = f"{self.gateway_url}/aegis/api/v1/security/scan"
        payload = {"target": target, "scan_type": "vulnerability"}
        response = self.session.post(url, json=payload)
        return response.json()
    
    def transcribe_audio(self, audio_file, language="en"):
        """Transcribe audio via Edge Whisper"""  
        url = f"http://localhost:9086/api/transcribe"
        files = {"audio": open(audio_file, "rb")}
        data = {"language": language}
        response = self.session.post(url, files=files, data=data)
        return response.json()

# Usage example
client = InfiniteEdgeClient()
health = client.health_check()
print(f"Gateway health: {health}")
```

### JavaScript SDK

```javascript
class InfiniteEdgeClient {
  constructor(gatewayUrl = 'http://localhost:8888') {
    this.gatewayUrl = gatewayUrl;
  }

  async healthCheck() {
    const response = await fetch(`${this.gatewayUrl}/health`);
    return await response.text();
  }

  async classifyText(text, model = 'bert-base-uncased') {
    const response = await fetch('http://localhost:9089/api/v1/classify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, model })
    });
    return await response.json();
  }

  async generateText(prompt, model = 'gpt2') {
    const response = await fetch('http://localhost:9089/api/v1/generate', {
      method: 'POST', 
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt, model, max_length: 50 })
    });
    return await response.json();
  }
}

// Usage example
const client = new InfiniteEdgeClient();
client.healthCheck().then(health => console.log('Health:', health));
```

### cURL Examples

```bash
# Health checks
curl -s http://localhost:8888/health
curl -s http://localhost:9080/health | jq .

# AegisEdgeAI security scan
curl -X POST http://localhost:9080/api/v1/security/scan \
  -H "Content-Type: application/json" \
  -d '{"target": "192.168.1.100", "scan_type": "vulnerability"}' | jq .

# Transformers text classification  
curl -X POST http://localhost:9089/api/v1/classify \
  -H "Content-Type: application/json" \
  -d '{"text": "This is amazing!", "model": "bert-base-uncased"}' | jq .

# Edge Whisper transcription
curl -X POST http://localhost:9086/api/transcribe \
  -F "audio=@audio.wav" \
  -F "language=en" | jq .

# Megatron-LM text generation
curl -X POST http://localhost:9088/api/v1/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "The future of AI", "max_tokens": 100}' | jq .
```

---

**For complete API documentation and interactive testing, visit the API documentation dashboard at http://localhost:8888/docs (when available)**