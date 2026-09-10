# luci-app-gogogo 版本号规则

OpenWrt 软件包版本由 `env` 中的 **`CPE_PKG_VERSION`** 决定。

## 格式

版本号为 **10 位纯数字**：前 8 位 `YYYYMMDD` + 后 2 位当日序号 `00`–`99`。

- **同一天**：每发布一版，后 2 位加 1。
- **次日**：日期更新后序号从 `00` 重新开始。

## 修改位置

打包前在根目录 **`env`** 中设置：

```makefile
CPE_PKG_VERSION=2026091003
```

然后：

```sh
make package/luci-app-gogogo/compile V=s
```

正式推送到 GitHub 见 [PUSH.md](./PUSH.md)。
