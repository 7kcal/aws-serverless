#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  開発環境 前提条件チェック"
echo "========================================="

errors=0

# -----------------------------------------------
# Docker
# -----------------------------------------------
if command -v docker &> /dev/null; then
  echo -e "${GREEN}✅ Docker$(NC) $(docker --version)"

  # Docker デーモンが動いているか
  if docker info &> /dev/null; then
    echo -e "${GREEN}✅ Docker daemon${NC} running"
  else
    echo -e "${RED}❌ Docker daemon が起動していません${NC}"
    echo "   sudo systemctl start docker"
    errors=$((errors + 1))
  fi

  # 現在のユーザーが docker グループに所属しているか
  if groups | grep -q docker; then
    echo -e "${GREEN}✅ Docker group${NC} OK"
  else
    echo -e "${YELLOW}⚠️  現在のユーザーが docker グループに所属していません${NC}"
    echo "   sudo usermod -aG docker \$USER && newgrp docker"
  fi
else
  echo -e "${RED}❌ Docker がインストールされていません${NC}"
  echo "   https://docs.docker.com/engine/install/ubuntu/"
  errors=$((errors + 1))
fi

# -----------------------------------------------
# Docker Compose (v2)
# -----------------------------------------------
if docker compose version &> /dev/null; then
  echo -e "${GREEN}✅ Docker Compose${NC} $(docker compose version --short)"
else
  echo -e "${RED}❌ Docker Compose v2 が見つかりません${NC}"
  echo "   sudo apt install docker-compose-plugin"
  errors=$((errors + 1))
fi

# -----------------------------------------------
# Git
# -----------------------------------------------
if command -v git &> /dev/null; then
  echo -e "${GREEN}✅ Git${NC} $(git --version)"
else
  echo -e "${RED}❌ Git がインストールされていません${NC}"
  echo "   sudo apt install git"
  errors=$((errors + 1))
fi

# -----------------------------------------------
# make
# -----------------------------------------------
if command -v make &> /dev/null; then
  echo -e "${GREEN}✅ make${NC} $(make --version | head -1)"
else
  echo -e "${YELLOW}⚠️  make がインストールされていません${NC}"
  echo "   sudo apt install make"
  echo "   （なくても docker compose コマンド直打ちで代用可）"
fi

# -----------------------------------------------
# curl（LocalStack ヘルスチェック用）
# -----------------------------------------------
if command -v curl &> /dev/null; then
  echo -e "${GREEN}✅ curl${NC} OK"
else
  echo -e "${YELLOW}⚠️  curl がインストールされていません${NC}"
  echo "   sudo apt install curl"
fi

# -----------------------------------------------
# ディスク空き容量
# -----------------------------------------------
available_gb=$(df -BG --output=avail . | tail -1 | tr -d ' G')
if [ "$available_gb" -ge 10 ]; then
  echo -e "${GREEN}✅ Disk${NC} ${available_gb}GB available"
else
  echo -e "${YELLOW}⚠️  ディスク空き容量が少ない (${available_gb}GB)${NC}"
  echo "   Docker イメージに ~5GB 必要"
fi

# -----------------------------------------------
# 結果
# -----------------------------------------------
echo ""
echo "========================================="
if [ $errors -eq 0 ]; then
  echo -e "${GREEN}  全チェック通過 🎉${NC}"
  echo "========================================="
  echo ""
  echo "  次のステップ:"
  echo "    make up       # コンテナ起動"
  echo "    make shell    # 開発コンテナに入る"
  echo "    make install  # (コンテナ内) npm install"
  echo "    make local    # (コンテナ内) API起動"
else
  echo -e "${RED}  ${errors} 件のエラーがあります${NC}"
  echo "========================================="
  echo "  上記を修正してから再実行してください"
  exit 1
fi
