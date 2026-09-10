# luci-app-gogogo 推送说明

## 两种场景

| 场景 | 触发方式 | 允许的操作 |
|------|----------|------------|
| **本地测试** | 仅说「打包」「推到 CPE 测试」等，**未明确说正式推送** | 编译 ipk、SCP/SSH 装到指定设备；**禁止** git push、打 tag、上传 GitHub Release |
| **正式推送** | 明确说「正式推送」「发布」「推送到 GitHub」等 | 本地测试通过后执行下方流程 |

## 本地测试（默认）

1. 按 [VERSION.md](./VERSION.md) 在 `env` 中设置 `CPE_PKG_VERSION`。
2. 在 OpenWrt SDK 根目录编译：

```sh
make package/luci-app-gogogo/compile V=s
```

3. 将 ipk 拷到目标设备后 `opkg install --force-reinstall`。
4. **不要** git push / 打 tag / 创建 GitHub Release。

## 正式推送流程

完整更新必须同时带客户端 ipk 和 sysupgrade 固件（与 luci-app-nsclient 相同）。GitHub tag 用主题/固件版本（如 `v1.0.1`）。

```sh
cd package/custom_packages/luci-app-gogogo
./scripts/publish-release.sh \
  --ipk /path/to/luci-app-gogogo_<appver>_all.ipk \
  --sysupgrade /path/to/openwrt-mediatek-mt7981-mt7981-spim-nand-rfb-squashfs-sysupgrade.bin \
  --factory /path/to/openwrt-mediatek-mt7981-mt7981-spim-nand-rfb-squashfs-factory.bin \
  --push
```

仓库：`https://github.com/hk59775634/luci-app-gogogo`（**公开仓库**，以 `env` 中 `CPE_GITHUB_REPO` 为准）。

Release 资产：

| 文件 | 谁读 |
|------|------|
| `manifest.json` | LuCI **更新**页（固件 + 客户端） |
| `version.json` | `gogogo-update` 守护进程（仅客户端） |
| `luci-app-gogogo_*_all.ipk` | 客户端 |
| `*-sysupgrade.bin` | 固件升级 |
| `*-factory.bin` | 出厂刷写 |

更新说明来自仓库根目录 `RELEASE_NOTES`。

设备自动更新客户端（见 `gogogo-update`）并行探测下列源，取版本号最新者；同版本优先走国内加速下 ipk：

| 源 | manifest |
|------|----------|
| **base_url** | `{gogogo-url get}` + `CPE_UPDATE_MANIFEST` |
| **GitHub Release** | `github.com/{repo}/releases/latest/download/version.json` |
| **GitHub raw** | `raw.githubusercontent.com/{repo}/{CPE_GITHUB_MANIFEST_PATH}` |
| **jsDelivr** | `cdn.jsdelivr.net/gh/{repo}@{CPE_GITHUB_MANIFEST_PATH}` |
| **加速前缀** | `CPE_GITHUB_MIRROR_PREFIXES` 逐条加上面 GitHub URL（ghproxy.net / gh-proxy.com / ghfast.top / kkgithub 等，对齐 nsclient / nros-update） |

ipk 优先用命中 manifest 的同目录 URL，再回退 `releases/download/v{版本}/` 全线路。加速域名由 `gogogo_curl` 强制 DoH。

## env 多品牌

复制本目录，只改根目录 **`env`**（包名、标题、API URL、接口名 `CPE_VPNAME`、GitHub 仓库等），重新 `make` 即可。
