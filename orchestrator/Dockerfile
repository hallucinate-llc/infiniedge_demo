# InfinieEdge Demo Platform - External Orchestration Container
# This container runs ALL submodules simultaneously from outside the project structure

FROM ubuntu:22.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build tools
    build-essential \
    cmake \
    pkg-config \
    git \
    curl \
    wget \
    unzip \
    # Languages and runtimes
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    nodejs \
    npm \
    golang-go \
    # System tools
    supervisor \
    nginx \
    redis-server \
    postgresql-client \
    # Network tools
    netcat \
    iproute2 \
    # Monitoring
    htop \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Set up Python environment
RUN python3 -m pip install --upgrade pip setuptools wheel

# Set up Node.js environment
RUN npm install -g pm2 yarn

# Set up Go environment
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin"

# Create application directory
WORKDIR /app

# Create directory structure for all services
RUN mkdir -p /app/{services,configs,scripts,logs,data}

# Copy all service source code
COPY AegisEdgeAI/ /app/services/aegis-edge-ai/
COPY SPEAR/ /app/services/spear/
COPY yomo/ /app/services/yomo/
COPY shifu/ /app/services/shifu/
COPY AIOps/ /app/services/aiops/
COPY eda/ /app/services/eda/
COPY edge-whisper/ /app/services/edge-whisper/
COPY Whisper-Finetune/ /app/services/whisper-finetune/
COPY Megatron-LM/ /app/services/megatron-lm/
COPY transformers/ /app/services/transformers/

# Install dependencies for each service
WORKDIR /app/services

# Python services
RUN cd aegis-edge-ai && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt; fi && \
    if [ -f setup.py ]; then pip3 install -e .; fi

RUN cd aiops && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt; fi && \
    if [ -f setup.py ]; then pip3 install -e .; fi

RUN cd eda && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt; fi && \
    if [ -f setup.py ]; then pip3 install -e .; fi

RUN cd whisper-finetune && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt; fi && \
    if [ -f setup.py ]; then pip3 install -e .; fi

RUN cd transformers && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt; fi && \
    if [ -f setup.py ]; then pip3 install -e .; fi

RUN cd megatron-lm && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt; fi && \
    if [ -f setup.py ]; then pip3 install -e .; fi

# Node.js services
RUN cd edge-whisper && \
    if [ -f package.json ]; then npm install; fi

# Go services
RUN cd spear && \
    if [ -f go.mod ]; then go mod download && go mod tidy; fi

RUN cd yomo && \
    if [ -f go.mod ]; then go mod download && go mod tidy; fi

RUN cd shifu && \
    if [ -f go.mod ]; then go mod download && go mod tidy; fi

# Create supervisor configuration for running all services
COPY orchestrator/supervisord.conf /etc/supervisor/conf.d/infiniedge.conf

# Create startup scripts for each service
COPY orchestrator/scripts/ /app/scripts/

# Create nginx configuration for routing
COPY orchestrator/nginx.conf /etc/nginx/nginx.conf

# Expose all service ports
EXPOSE 80 443 \
       8080 8081 8082 8083 8084 8085 8086 8087 8088 8089 \
       9000 9001 9002 9003 9004 9005 \
       3000 5000 6000 7000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start supervisor to manage all services
CMD ["/usr/bin/supervisord", "-n"]