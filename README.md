# luci-app-gogogo

供创未来跨境加速 LuCI 客户端：登录 `https://cpe.gogogofuture.com`，连接平台分配的 WireGuard 接口 `GOGOGO`，支持分流 / 全局 / 防 DNS 泄露。

数据面逻辑对齐 [luci-app-CPE](https://github.com/hk59775634/luci-app-CPE)：策略路由、handshake 健康检查、API 失败保活、dnsmasq drop-in、chnroutes、U-Boot 凭据、自动更新。不含 ZeroTier 维护网。

自动更新仓库为公开 GitHub：[hk59775634/luci-app-gogogo](https://github.com/hk59775634/luci-app-gogogo)。`gogogo-update` 并行探测 GitHub Release / raw / jsDelivr 以及 nsclient 同款国内加速前缀，失败忽略。

## 打包

编辑根目录 `env` 后，在 OpenWrt SDK 中：

```sh
make package/luci-app-gogogo/compile V=s
```

版本号规则见 [VERSION.md](./VERSION.md)。正式推送见 [PUSH.md](./PUSH.md)。

## 设备命令

| 命令 | 作用 |
|------|------|
| `gogogo status` | LuCI 状态 JSON |
| `gogogo refresh_account` | 刷新到期时间 |
| `gogogo-luci-diag start\|poll` | 连接诊断 |
| `gogogo-cred sync\|has\|repair` | UCI ↔ U-Boot |
| `gogogo-url get\|set` | 云端 URL（可写 U-Boot `url`） |
| `gogogo-update check` | 自动更新 |
