# Subconverter 链接生成脚本设计

## 目标

在 `proxy-config` 仓库中提供一个 PowerShell 脚本，直接生成与 sub.v1.mk 网页等价的 Subconverter 长链接，并可按需创建短链接。日常运行使用本地默认值，不再重复填写网页；给其他客户端使用时可通过命令行参数覆盖部分默认值。

## 文件结构

公开提交：

- `scripts/New-SubconverterLink.ps1`：生成长链接并按需调用短链接口。
- `config/subscription.example.psd1`：不含真实订阅地址的配置示例。
- `tests/validate-link-generator.ps1`：使用假订阅地址验证参数、编码、覆盖逻辑与短链请求结构。
- `.gitignore`：忽略真实默认配置和本地输出。
- `README.md`：记录日常用法和朋友客户端覆盖示例。

仅保存在本地：

- `config/subscription.local.psd1`：保存真实 3x-ui 聚合订阅、机场订阅和个人默认值。

## 配置合并规则

最终值按以下优先级确定：

1. 命令行显式参数。
2. `config/subscription.local.psd1` 中的本地默认值。
3. 脚本内不含凭据的安全默认值。

本地配置包含以下键：

- `ThreeXuiSubscriptionUrl`
- `AirportSubscriptionUrl`
- `ClientName`
- `SubscriptionName`
- `RemoteConfigUrl`
- `BackendUrl`
- `ShortUrlEndpoint`
- `Udp`
- `Xudp`
- `Emoji`
- `ExpandRules`
- `ClashNewFieldName`
- `UserAgent`

两个订阅地址均为必填。脚本将其按“3x-ui 在前、机场在后”的顺序用 `|` 合并，再对整个值做 URL 编码。

## 参数接口

脚本支持：

- `-ThreeXuiSubscriptionUrl <string>`
- `-AirportSubscriptionUrl <string>`
- `-ClientName <string>`
- `-SubscriptionName <string>`
- `-RemoteConfigUrl <string>`
- `-BackendUrl <string>`
- `-ShortUrlEndpoint <string>`
- `-RenameRule <string>`
- `-Udp <bool>`
- `-Xudp <bool>`
- `-Emoji <bool>`
- `-ExpandRules <bool>`
- `-ClashNewFieldName <bool>`
- `-UserAgent <string>`
- `-CreateShort`
- `-ShortKey <string>`

未显式传入 `-RenameRule` 时，由 `ClientName` 自动生成：

```text
-<ClientName>$@
```

例如 `ClientName=icyy` 生成 `-icyy$@`。

## 长链接生成

脚本生成：

```text
<BackendUrl>/sub?target=clash&url=...&insert=false&config=...&filename=...&rename=...&emoji=true&list=false&xudp=true&udp=true&tfo=false&expand=true&scv=false&fdn=false&new_name=true&diyua=ShadowRocket
```

所有用户值均分别使用 `[Uri]::EscapeDataString()` 编码。参数顺序与当前 sub.v1.mk 网页保持一致，便于对照和解析。

默认行为：

- 仅生成长链接。
- 返回包含 `LongUrl` 和空 `ShortUrl` 的对象。
- 不访问原始订阅，不下载节点，不调用短链服务。

## 短链接生成

只有传入 `-CreateShort` 时，脚本才请求 `ShortUrlEndpoint`。

请求与当前网页一致：

1. 将完整长链接按 UTF-8 转为 Base64。
2. 以 multipart/form-data POST 字段 `longUrl` 提交。
3. 传入 `-ShortKey` 时额外提交 `shortKey`；该值必须是不含 `http` 的后缀。
4. 响应必须满足 `Code = 1` 且 `ShortUrl` 非空，否则抛出明确错误。

默认短链接口为：

```text
https://v1.mk/short
```

## 朋友客户端覆盖示例

保留本地机场订阅和其他默认值，只替换朋友的 3x-ui 订阅、客户端名和订阅名：

```powershell
.\scripts\New-SubconverterLink.ps1 `
  -ThreeXuiSubscriptionUrl '朋友的聚合订阅地址' `
  -ClientName 'friend' `
  -SubscriptionName '朋友的订阅名称'
```

需要短链接时追加：

```powershell
-CreateShort
```

## 安全边界

- 真实订阅地址不得出现在 Git 追踪文件、提交记录、测试输出或公开文档中。
- `config/subscription.local.psd1` 必须在创建前写入 `.gitignore`。
- 示例配置只使用 `https://example.invalid/` 占位地址。
- 长链接包含可还原的订阅地址，应视作凭据；脚本不会自动提交、上传或写入公开文件。
- 短链服务能够看到长链接，只在用户显式传入 `-CreateShort` 时调用。
- 测试和网页对照只使用假订阅地址。

## 错误处理

脚本在以下情况终止并给出可操作提示：

- 本地配置不存在且参数未提供两个订阅地址。
- URL 不是绝对 HTTP/HTTPS 地址。
- `ClientName` 为空且未提供 `RenameRule`。
- `ShortKey` 包含 `http`。
- 短链接口网络失败、返回格式不正确或拒绝请求。

任何错误信息都不得输出真实订阅地址。

## 验证

1. 使用示例假地址运行，确认生成结果与网页当前参数完全一致。
2. 验证 `|` 合并和所有特殊字符均正确编码。
3. 验证参数覆盖本地配置，而未覆盖字段继续使用本地默认值。
4. 验证 `ClientName` 自动生成节点命名规则。
5. 默认运行不发起短链 HTTP 请求。
6. 使用本地假短链服务器验证 `-CreateShort` 的 Base64、multipart 字段和响应处理，不向公共短链服务制造测试记录。
7. 扫描 Git 追踪文件和提交差异，确认不含真实订阅地址、订阅 ID、UUID、密码或代理分享链接。
8. 用真实本地配置生成长链接，再通过 Subconverter 请求确认 HTTP 200；验证过程只报告状态，不打印链接。
