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

**不包含（armv7 不支持）：**
- `observability-prometheus` — 需要 64 位原子操作，32 位 ARM 无法编译
- `acp-bridge` — IDE 集成，服务器上不需要
- `tui-onboarding` — 终端 TUI 向导，可用 WebUI 或手写配置替代

## 使用方法

### 1. 下载编译产物

去 [Actions](../../actions) 页面，选择最新的成功构建，下载 `zeroclaw-armv7` artifact。

解压后包含：
- `zeroclaw` — armv7 二进制
- `web-dist/` — Web Dashboard 前端文件

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

## 自动更新

本仓库配置了每周一自动检查上游新版本（`schedule: cron '0 12 * * 1'`）。

你也可以手动触发：
1. 去 [Actions](../../actions) 页面
2. 选择 "Build ZeroClaw armv7"
3. 点 "Run workflow"

## 更新设备上的 ZeroClaw

```bash
# 下载新版本 artifact，然后：
scp zeroclaw root@设备IP:/usr/local/bin/
ssh root@设备IP "zeroclaw service restart"
```

## 自定义

### 修改编译的 features

编辑 `.github/workflows/build-armv7.yml`，修改 `--features` 参数：

```yaml
- name: Build binary
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
    - cron: '0 12 * * *'   # 每天中午检查
    # - cron: '0 12 * * 1' # 每周一
    # - cron: '0 0 1 * *'  # 每月一号
```

## 编译环境

- **Runner:** ubuntu-latest (GitHub Actions)
- **Rust:** stable (自动获取最新版)
- **交叉编译器:** arm-linux-gnueabihf-gcc
- **目标架构:** armv7-unknown-linux-gnueabihf

## 相关链接

- [ZeroClaw 官方仓库](https://github.com/zeroclaw-labs/zeroclaw)
- [ZeroClaw 文档](https://github.com/zeroclaw-labs/zeroclaw/tree/master/docs/book/src)
- [ZeroClaw Discord](https://discord.com/invite/wDshRVqRjx)
- [#3677 - RPi 3B+ 编译问题](https://github.com/zeroclaw-labs/zeroclaw/issues/3677)
- [#4384 - 32 位 ARM 禁用 prometheus](https://github.com/zeroclaw-labs/zeroclaw/pull/4384)

## License

MIT OR Apache-2.0 — 与上游 ZeroClaw 一致。
