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

```sh
cd package/custom_packages/luci-app-gogogo
./scripts/publish-release.sh --ipk /path/to/luci-app-gogogo_<版本>-1_all.ipk --push
```

仓库：`https://github.com/hk59775634/luci-app-gogogo`（以 `env` 中 `CPE_GITHUB_REPO` 为准）。

设备自动更新三路径（见 `gogogo-update`）：

| 路径 | manifest |
|------|----------|
| **base_url** | `{gogogo-url get}` + `CPE_UPDATE_MANIFEST` |
| **GitHub 原始** | `raw.githubusercontent.com/{CPE_GITHUB_REPO}/{CPE_GITHUB_MANIFEST_PATH}` |
| **gh-proxy 加速** | `{CPE_GITHUB_MIRROR}/{CPE_GITHUB_REPO}/blob/{CPE_GITHUB_MANIFEST_PATH}` |

ipk 走 `releases/download/v{版本}/`。加速域名由 `gogogo_curl` 强制 DoH。

## env 多品牌

复制本目录，只改根目录 **`env`**（包名、标题、API URL、接口名 `CPE_VPNAME`、GitHub 仓库等），重新 `make` 即可。
