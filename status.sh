#!/bin/bash

# Quick status check script for InfinieEdge Demo Platform

echo "🚀 InfinieEdge Demo Platform - Status Check"
echo "=========================================="

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running"
    exit 1
fi

echo "✅ Docker is running"

# Check Docker Compose
if ! docker compose version >/dev/null 2>&1; then
    echo "❌ Docker Compose not available"
    exit 1
fi

echo "✅ Docker Compose is available"

# Check if any services are running
if [ "$(docker compose ps -q)" ]; then
    echo ""
    echo "📋 Running Services:"
    echo "-------------------"
    docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}"
    
    echo ""
    echo "🌐 Access Points:"
    echo "----------------"
    echo "Main Dashboard: http://localhost"
    echo "AegisEdgeAI:    http://localhost/aegis/"
    echo "SPEAR:          http://localhost/spear/"
    echo "YoMo:           http://localhost/yomo/"
    echo "Shifu:          http://localhost/shifu/"
    echo "Edge Whisper:   http://localhost/whisper/"
    echo "EDA:            http://localhost/eda/"
    echo "AIOps:          http://localhost/aiops/"
    echo "Transformers:   http://localhost/transformers/"
    echo "Megatron-LM:    http://localhost/megatron/"
    echo "Whisper-FT:     http://localhost/whisper-ft/"
    
    echo ""
    echo "📊 Resource Usage:"
    echo "------------------"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    
else
    echo ""
    echo "⏹️  No services are currently running"
    echo ""
    echo "To start all services run:"
    echo "  ./manage-demo.sh start"
    echo ""
    echo "To build and start:"
    echo "  ./manage-demo.sh build"
    echo "  ./manage-demo.sh start"
fi

echo ""
echo "💡 Use './manage-demo.sh help' for more commands"