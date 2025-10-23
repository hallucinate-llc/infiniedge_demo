#!/bin/bash
# Health monitoring script for all services

SERVICES=(
    "localhost:8080:AegisEdgeAI"
    "localhost:8081:SPEAR"
    "localhost:8082:YoMo"
    "localhost:8083:Shifu"
    "localhost:8084:AIOps"
    "localhost:8085:EDA"
    "localhost:8086:EdgeWhisper"
    "localhost:8087:WhisperFinetune"
    "localhost:8088:MegatronLM"
    "localhost:8089:Transformers"
)

while true; do
    echo "$(date): Health check started"
    
    for service in "${SERVICES[@]}"; do
        IFS=':' read -r host port name <<< "$service"
        
        if curl -s -f "http://$host:$port/health" >/dev/null 2>&1; then
            echo "$(date): ✅ $name ($host:$port) - healthy"
        else
            echo "$(date): ❌ $name ($host:$port) - unhealthy"
        fi
    done
    
    echo "$(date): Health check completed"
    sleep 30
done
