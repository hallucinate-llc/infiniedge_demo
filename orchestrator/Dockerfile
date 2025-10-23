# InfinieEdge Demo Platform - External Orchestration Container
# This container runs ALL submodules simultaneously from outside the project structure

FROM ubuntu:22.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies first (without Node.js)
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

# Install Node.js 18.x from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Go 1.23.x (newer version for compatibility)
RUN wget https://go.dev/dl/go1.23.2.linux-arm64.tar.gz && \
    tar -C /usr/local -xzf go1.23.2.linux-arm64.tar.gz && \
    rm go1.23.2.linux-arm64.tar.gz

# Set up Go environment
ENV GOPATH=/go
ENV GOROOT=/usr/local/go
ENV PATH=/usr/local/go/bin:$PATH

# Create nginx directories with proper permissions
RUN mkdir -p /var/log/nginx /var/lib/nginx/body /var/lib/nginx/proxy /var/lib/nginx/fastcgi /var/lib/nginx/uwsgi /var/lib/nginx/scgi && \
    chmod 755 /var/log/nginx /var/lib/nginx && \
    chmod 755 /var/lib/nginx/*

# Set up Python environment
RUN python3 -m pip install --upgrade pip setuptools wheel

# Set up Node.js environment
RUN npm install -g pm2 yarn
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
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt || echo "EDA requirements failed, continuing..."; fi && \
    if [ -f setup.py ]; then pip3 install -e . || echo "EDA setup.py failed, continuing..."; fi

RUN cd whisper-finetune && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt || echo "Whisper-finetune requirements failed, continuing..."; fi && \
    if [ -f setup.py ]; then pip3 install -e . || echo "Whisper-finetune setup.py failed, continuing..."; fi

RUN cd transformers && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt || echo "Transformers requirements failed, continuing..."; fi && \
    if [ -f setup.py ]; then pip3 install -e . || echo "Transformers setup.py failed, continuing..."; fi

RUN cd megatron-lm && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt || echo "Megatron requirements failed, continuing..."; fi && \
    if [ -f setup.py ]; then pip3 install -e . || echo "Megatron setup.py failed, continuing..."; fi

    # Node.js services
    RUN cd edge-whisper && \
        if [ -f package.json ]; then npm install --legacy-peer-deps || echo "Edge Whisper npm install failed, continuing..."; fi

    # Go services
    RUN cd spear && \
        if [ -f go.mod ]; then go mod download && go mod tidy && go build -o bin/spear ./cmd/spear || echo "SPEAR build failed, continuing..."; fi

    RUN cd yomo && \
        mkdir -p bin && \
        if [ -f go.mod ]; then go mod download && go mod tidy && go build -o bin/yomo . || echo "YoMo build failed, continuing..."; fi

    RUN cd shifu && \
        if [ -f go.mod ]; then go mod download && go mod tidy && make build || echo "Shifu build failed, continuing..."; fi

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