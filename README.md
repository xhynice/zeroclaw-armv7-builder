# ZeroClaw armv7 Builder

自动交叉编译 [ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) 为 armv7 (32-bit ARM) 二进制。

## 为什么需要这个

ZeroClaw 的官方预编译包虽然有 `armv7-unknown-linux-gnueabihf` 版本，但它是 minimal 构建，**不包含 gateway（WebUI）**。而从源码编译时，install.sh 对 32 位 ARM 有硬拦截（因为 `observability-prometheus` 需要 64 位原子操作），无法直接编译带 gateway 的版本。

本仓库通过 GitHub Actions 交叉编译，跳过 prometheus，保留完整的 agent 运行时 + WebUI。

## 编译的 features

```
agent-runtime    # 完整 agent 运行时（agent 循环、安全策略、SOP、cron、25+ 聊天渠道）
gateway          # HTTP/WebSocket 服务器 + Web Dashboard
schema-export    # 配置 API 的 JSON Schema 导出
```

**与官方的区别：**
- armv7 使用 `--no-default-features` 跳过 `tui-onboarding acp-bridge`
- 额外加入 `gateway`（官方 armv7 构建没有 gateway，我们加上了）

**不包含：**
- `acp-bridge` — IDE 集成，服务器上不需要
- `tui-onboarding` — 终端 TUI 向导

## 快速安装

### 一键安装（从 GitHub Release 下载）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xhynice/zeroclaw-armv7-builder/main/install.sh)
```

### 使用本地文件安装

如果已经下载了 `zeroclaw-armv7-latest.tar.gz`：

```bash
bash install.sh zeroclaw-armv7-latest.tar.gz
```

### 安装脚本会自动处理

- **首次安装** — 下载、解压、安装二进制 + Web Dashboard
- **更新安装** — 检测已安装版本、停止运行中的服务、覆盖安装、自动重启服务
- 显示版本变化（如 `v0.7.4 -> v0.7.5`）

## 手动部署

### 1. 下载编译产物

去 [Releases](../../releases) 页面下载最新的 `zeroclaw-armv7-latest.tar.gz`。

解压后包含：
- `zeroclaw` — armv7 二进制
- `web-dist/` — Web Dashboard 前端文件
- `CHANGELOG-EN-*.md` / `CHANGELOG-ZH-*.md` — 上游更新日志

### 2. 部署到 armv7 设备

```bash
# 解压
tar xzf zeroclaw-armv7-latest.tar.gz

# 上传二进制到设备
scp zeroclaw root@你的设备IP:/usr/local/bin/

# 上传 Web Dashboard
ssh root@你的设备IP "mkdir -p ~/.local/share/zeroclaw/web"
scp -r web-dist/ root@你的设备IP:~/.local/share/zeroclaw/web/dist

# 在设备上首次配置
ssh root@你的设备IP
chmod +x /usr/local/bin/zeroclaw
zeroclaw onboard

# 设为后台服务
zeroclaw service install
zeroclaw service start
```

### 3. 访问 WebUI

```bash
# 查看 gateway 监听地址和端口
zeroclaw service status
# 或查看日志
journalctl --user -u zeroclaw -f | grep -i "gateway\|dashboard\|listen"
```

浏览器打开 `http://设备IP:端口` 即可使用 Web Dashboard。

## 自动更新机制

本仓库每天自动检查上游是否有新 Release（`schedule: cron '0 12 * * *'`），有新版本才构建，没有则跳过。

- 保留最新 **10 个 Release**，旧的自动清理
- 每次构建生成中英文更新日志（CHANGELOG），打包进产物
- Release 标签带版本号（如 `v0.7.5`）

你也可以手动触发：
1. 去 [Actions](../../actions) 页面
2. 选择 "Build ZeroClaw armv7"
3. 点 "Run workflow"

## 更新设备上的 ZeroClaw

```bash
# 方法 1：一键更新
bash <(curl -fsSL https://raw.githubusercontent.com/xhynice/zeroclaw-armv7-builder/main/install.sh)

# 方法 2：手动更新
# 下载新版本 tar.gz 后
bash install.sh zeroclaw-armv7-latest.tar.gz
```

## 自定义

### 修改编译的 features

编辑 `.github/workflows/build-armv7.yml`，修改 `--features` 参数：

```yaml
- name: Build release
  run: |
    cargo build --release --target armv7-unknown-linux-gnueabihf \
      --no-default-features --features agent-runtime,gateway,schema-export,channel-telegram
```

可用的 features 参考上游 [Cargo.toml](https://github.com/zeroclaw-labs/zeroclaw/blob/master/Cargo.toml) 的 `[features]` 部分。

### 修改自动编译频率

修改 `schedule` 的 cron 表达式：

```yaml
on:
  schedule:
    - cron: '0 12 * * *'  # 每天中午检查（默认）
    # - cron: '0 12 * * 1'  # 每周一
    # - cron: '0 0 1 * *'   # 每月一号
```

## 编译流程

参考官方 [release-stable-manual.yml](https://github.com/zeroclaw-labs/zeroclaw/blob/master/.github/workflows/release-stable-manual.yml)，分三个阶段：

```
Job 1: web            Job 2: build                Job 3: release
┌─────────────────┐   ┌──────────────────────┐    ┌──────────────────┐
│ cargo web build │   │ --no-default-features│    │ 清理旧 Release   │
│ (OpenAPI spec   │   │ --features           │    │ (保留最新 10 个) │
│  + TypeScript   │──→│  agent-runtime,      │──→ │                  │
│  + npm + vite)  │   │  gateway,            │    │ 发布到 GitHub    │
│                 │   │  schema-export       │    │ Releases         │
└─────────────────┘   │ --target armv7       │    └──────────────────┘
 生成 web/dist/       └──────────────────────┘
                       生成 zeroclaw 二进制 + CHANGELOG
```

**为什么用 `cargo web build` 而不是 `npm run build`：**

`cargo web build` 是 ZeroClaw 的 xtask 包装器，它会：
1. 渲染 gateway 的 OpenAPI 3.1 spec
2. 运行 `openapi-typescript` 生成 `web/src/lib/api-generated.ts`
3. 然后执行 `npm ci` + `npm run build`

直接 `npm run build` 会因为缺少 `api-generated.ts` 导致 TypeScript 编译失败。

## 编译环境

- **Runner:** ubuntu-22.04 (GitHub Actions)
- **Rust:** 1.93.0 (pinned，与官方一致)
- **缓存:** Swatinem/rust-cache (与官方一致)
- **交叉编译器:** arm-linux-gnueabihf-gcc
- **目标架构:** armv7-unknown-linux-gnueabihf
- **Node.js:** 22 (构建 Web Dashboard)

## 相关链接

- [ZeroClaw 官方仓库](https://github.com/zeroclaw-labs/zeroclaw)
- [ZeroClaw 文档](https://github.com/zeroclaw-labs/zeroclaw/tree/master/docs/book/src)
- [ZeroClaw Discord](https://discord.com/invite/wDshRVqRjx)
- [#3677 - RPi 3B+ 编译问题](https://github.com/zeroclaw-labs/zeroclaw/issues/3677)
- [#4384 - 32 位 ARM 禁用 prometheus](https://github.com/zeroclaw-labs/zeroclaw/pull/4384)

## License

MIT OR Apache-2.0 — 与上游 ZeroClaw 一致。
