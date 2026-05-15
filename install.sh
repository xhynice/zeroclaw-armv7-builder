#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# ZeroClaw armv7 安装/更新脚本
# 支持本地 tar.gz 或从 GitHub Release 下载
# ──────────────────────────────────────────────

REPO="xhynice/zeroclaw-armv7-builder"
API="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_DIR="/usr/local/bin"
WEB_DIR="$HOME/.local/share/zeroclaw/web"
LOCAL_FILE="${1:-}"

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# ── 检查依赖 ──
for cmd in tar install; do
  command -v "$cmd" &>/dev/null || { error "缺少依赖: $cmd"; exit 1; }
done

# ── 检查已安装版本 ──
if command -v zeroclaw &>/dev/null; then
  OLD_VER=$(zeroclaw --version 2>/dev/null || echo "unknown")
  info "已安装版本: $OLD_VER"
else
  info "首次安装"
fi

# ── 停止运行中的服务 ──
SERVICE_STOPPED=false
if pgrep -x zeroclaw &>/dev/null; then
  warn "检测到 zeroclaw 正在运行，正在停止..."
  if command -v systemctl &>/dev/null && systemctl is-active zeroclaw &>/dev/null; then
    sudo systemctl stop zeroclaw
  else
    pkill -x zeroclaw || true
  fi
  SERVICE_STOPPED=true
  sleep 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# ── 获取文件 ──
if [ -n "$LOCAL_FILE" ] && [ -f "$LOCAL_FILE" ]; then
  info "使用本地文件: $LOCAL_FILE"
  tar xzf "$LOCAL_FILE" -C "$TMPDIR"
  TAG="local"
else
  command -v curl &>/dev/null || { error "缺少依赖: curl"; exit 1; }

  info "查找最新 Release..."
  RELEASE_JSON=$(curl -fsSL "$API")

  TAG=$(echo "$RELEASE_JSON" | grep -oP '"tag_name":\s*"\K[^"]+')
  TARBALL_URL=$(echo "$RELEASE_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]*armv7-latest\.tar\.gz')
  info "最新版本: $TAG"

  if [ -z "$TARBALL_URL" ]; then
    error "找不到下载地址"
    exit 1
  fi

  info "下载中..."
  curl -fSL "$TARBALL_URL" | tar xz -C "$TMPDIR"
fi

# ── 安装二进制 ──
if [ ! -f "$TMPDIR/zeroclaw" ]; then
  error "未找到 zeroclaw 二进制"
  exit 1
fi

info "安装 zeroclaw 到 ${INSTALL_DIR}..."
if [ ! -w "$INSTALL_DIR" ]; then
  sudo install -m755 "$TMPDIR/zeroclaw" "$INSTALL_DIR/zeroclaw"
else
  install -m755 "$TMPDIR/zeroclaw" "$INSTALL_DIR/zeroclaw"
fi

# ── 安装 Web Dashboard ──
info "安装 Web Dashboard..."
mkdir -p "$WEB_DIR"
rm -rf "$WEB_DIR/dist"
[ -d "$TMPDIR/web-dist" ] && cp -r "$TMPDIR/web-dist" "$WEB_DIR/dist"

# ── 复制 CHANGELOG ──
rm -f "$WEB_DIR"/CHANGELOG-*.md
for f in "$TMPDIR"/CHANGELOG-*.md; do
  [ -f "$f" ] && cp "$f" "$WEB_DIR/"
done

hash -r

# ── 恢复服务 ──
if [ "$SERVICE_STOPPED" = true ]; then
  info "重新启动 zeroclaw..."
  if command -v systemctl &>/dev/null && systemctl is-enabled zeroclaw &>/dev/null; then
    sudo systemctl start zeroclaw
  fi
fi

# ── 完成 ──
NEW_VER=$(zeroclaw --version 2>/dev/null || echo "unknown")
info "安装完成！"
echo ""
echo "  版本:   $TAG"
echo "  二进制: $(which zeroclaw)"
echo "  Web:    $WEB_DIR/dist"
if [ "$SERVICE_STOPPED" = true ]; then
  echo "  服务:   已自动重启"
fi
if [ -n "${OLD_VER:-}" ] && [ "$OLD_VER" != "unknown" ]; then
  echo "  更新:   $OLD_VER -> $NEW_VER"
fi
echo ""
echo "  启动:   zeroclaw onboard"
echo "  后台:   zeroclaw service install && zeroclaw service start"
