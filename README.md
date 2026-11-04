# proxy-config

这是供 [sub.v1.mk](https://sub.v1.mk/) / Subconverter 使用的远程配置，基于 ACL4SSR 的 `ACL4SSR_Online_Full_NoAuto.ini`。

## 远程配置地址

```text
https://raw.githubusercontent.com/icyyrain/proxy-config/main/subconverter.ini
```

在 sub.v1.mk 主页面的“远程配置”输入框中直接粘贴上面的 Raw URL。这里指的是主页面的 URL 输入框，不是“远程配置上传”弹窗。

## 自定义内容

- `🏠 自建节点`：匹配名称含 `MochaKK` 的全部节点，用于日常主线路。
- `🏠 自建备用`：同样匹配全部 `MochaKK` 节点，但在 Clash 中独立保存选择，可选备用协议。
- `🏡 自建住宅IP`：手动选择名称匹配 `MochaKK.*[Rr]esidential` 的节点，分组位于 PS5 节点之前。
- `🚀 节点选择`：可选择三个自建组，住宅组选项紧跟“手动切换”。
- `🎨 Pixiv`：可在自建组、节点选择、地区组、手动切换与直连之间选择。
- `🇯🇵 日本服务`：按具体服务匹配日本票务、DMM、DLsite、Niconico、ACGN 与影音网站，默认使用日本节点；不匹配整个 `.jp`，Pixiv 仍使用独立分组。
- `🏰 Disney+`：使用 ACL4SSR 的 DisneyPlus 规则，可独立选择线路。
- `🎥 奈飞视频`：保留 Netflix 域名分流，默认跟随节点选择，也可独立选择地区组或自建组。
- `🎬 小宝影院`：网站及常见 `dytt-` 视频源域名默认使用香港节点，避免自建美国线路到片源速度过低。
- `🎮 PS5节点`：供自定义 PS5 规则使用，默认跟随节点选择，也可在自建、香港、日本、美国节点与直连之间独立选择。
- 19 个业务与媒体分组可直接选择 `🏠 自建节点`、`🏠 自建备用` 或 `🏡 自建住宅IP`，无需改变全局节点选择。住宅组选项紧跟“手动切换”；原本没有该选项的哔哩哔哩、网易音乐组放在末尾。
- Pixiv 相关域名在通用代理与媒体规则之前匹配，避免被后续规则抢先处理。
- `💬 Ai平台`：Copilot 专用域名优先于微软通用规则匹配；Grok 网页 `grok.com` 与现有 `x.ai` 规则统一使用 AI 分组；额外覆盖 Meta Muse 的 `muse.ai` 及其子域名。

## 订阅内置 DNS

`subconverter.ini` 通过 `clash_rule_base` 引用本仓库的 `clash-base.yaml`，将公共基础设置和 DNS 一起写入转换后的订阅。DNS 配置面向 FlClash / Mihomo（Clash Meta），需要客户端的 GeoSite 数据库包含 `cn`。

- 普通域名默认使用 Google / Cloudflare DoH，通过现有 `🚀 节点选择` 代理组访问。
- 国内域名通过 `geosite:cn`、`.cn` 和微信等专门策略使用国内直连 DoH；清空旧的 fallback。
- 代理节点域名解析和 DNS 服务商域名的引导解析单独处理，避免解析循环。
- 沿用已验证的 `redir-host` 模式，保留 fake-IP 兼容过滤列表供后续模式调整使用。

使用已有订阅链接更新配置即可，通常不需要重新生成长／短链接。转换服务可能缓存远程模板，更新后应以实际下载到的 `dns` 内容为准。

客户端需要让订阅 DNS 生效：旧版 FlClash 关闭本地“覆写 DNS”，新版将相关 DNS 字段设为跟随订阅；其他客户端也应检查自己的覆写层。TUN、系统代理和本机 DNS 接管仍由各设备设置，订阅不会替代这些设置。

`🚀 节点选择` 应选择可用代理节点；若用于采用其他组名的配置，需要同步修改 DNS 地址中 `#` 后的组名。Merlin Clash 会使用自己的路由器 DNS 模板，当前版本不能靠更新此订阅替代路由器内的 DNS 设置。

本仓库的 YAML 只有公共基础配置，不含真实节点。转换服务仍从用户订阅生成节点、策略组和路由规则，不能单独把 `clash-base.yaml` 当完整订阅导入。

修改后可运行现有两项 PowerShell 验证，以及 DNS 模板检查（Python 需安装 PyYAML）：

```powershell
.\tests\validate-business-groups.ps1
.\tests\validate-link-generator.ps1
python .\tests\validate-dns-template.py
```

DNS 检查也可通过 `--converted <私密配置文件路径>` 核对实际转换输出。带真实节点的转换结果只保存在仓库外，不要提交。

## 生成订阅链接

本地默认配置保存在 Git 忽略的 `config/subscription.local.psd1`。日常直接运行：

```powershell
.\scripts\New-SubconverterLink.ps1
```

脚本默认只生成长链接，不访问短链服务。需要短链接时显式追加：

```powershell
.\scripts\New-SubconverterLink.ps1 -CreateShort
```

给朋友生成时，可以只覆盖朋友的 3x-ui 订阅、客户端名称和订阅名称；未覆盖的机场订阅、远程 INI 和其他设置继续使用本地默认值：

```powershell
.\scripts\New-SubconverterLink.ps1 `
  -ThreeXuiSubscriptionUrl '朋友的聚合订阅地址' `
  -ClientName 'friend' `
  -SubscriptionName '朋友的订阅名称'
```

所有参数和示例配置见 `config/subscription.example.psd1`。脚本返回的长链接包含可还原的原始订阅地址，短链服务也能看到长链接；两者都应视作凭据，不要提交到公开仓库。

## 维护

本地规范副本位于 `C:\Projects\配置\proxy-config`。修改并验证后，再更新此仓库的同名文件。固定 Raw URL 不会因为文件内容更新而改变。

## 安全

本仓库只保存公开规则、策略组、节点名称匹配表达式及公共 DNS 基础设置，不保存订阅 URL、订阅 ID、UUID、密码、密钥或服务器管理凭据。
