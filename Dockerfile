# ==============================================================
# サーバーレスAPI 開発環境
# ==============================================================
FROM node:20-bookworm

LABEL maintainer="serverless-api-dev"

# -----------------------------------------------
# 基本パッケージ
# -----------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    jq \
    make \
    git \
    python3 \
    python3-pip \
    ca-certificates \
    gnupg \
    less \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------
# Docker CLI（DooD: ホストの Docker を利用）
# -----------------------------------------------
ARG DOCKER_VERSION=27.3.1
RUN curl -fsSL \
    "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
    | tar xz --strip-components=1 -C /usr/local/bin docker/docker \
    && docker --version

# -----------------------------------------------
# AWS CLI v2
# -----------------------------------------------
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp/aws-install \
    && /tmp/aws-install/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws-install \
    && aws --version

# -----------------------------------------------
# SAM CLI
# -----------------------------------------------
RUN curl -fsSL \
    "https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip" \
    -o /tmp/sam-cli.zip \
    && unzip -q /tmp/sam-cli.zip -d /tmp/sam-install \
    && /tmp/sam-install/install \
    && rm -rf /tmp/sam-cli.zip /tmp/sam-install \
    && sam --version

# -----------------------------------------------
# AWS CDK CLI
# -----------------------------------------------
RUN npm install -g aws-cdk \
    && cdk --version

# -----------------------------------------------
# Git の安全なディレクトリ設定
# -----------------------------------------------
RUN git config --global --add safe.directory '*'

# -----------------------------------------------
# AWS ダミー認証情報（ローカル開発用）
# -----------------------------------------------
ENV AWS_ACCESS_KEY_ID=test
ENV AWS_SECRET_ACCESS_KEY=test
ENV AWS_DEFAULT_REGION=ap-northeast-1

WORKDIR /workspace

CMD ["/bin/bash"]
