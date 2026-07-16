# proxy-config

这是供 [sub.v1.mk](https://sub.v1.mk/) / Subconverter 使用的远程配置，基于 ACL4SSR 的 `ACL4SSR_Online_Full_NoAuto.ini`。

## 远程配置地址

```text
https://raw.githubusercontent.com/icyyrain/proxy-config/main/subconverter.ini
```

在 sub.v1.mk 主页面的“远程配置”输入框中直接粘贴上面的 Raw URL。这里指的是主页面的 URL 输入框，不是“远程配置上传”弹窗。

## 自定义内容

- `🏠 自建节点`：匹配名称含 `MochaKK` 的全部节点，用于日常主线路。
- `🛟 备用自建节点`：同样匹配全部 `MochaKK` 节点，但在 Clash 中独立保存选择，可选备用协议。
- `🚀 节点选择`：同时显示上述两个自建组。
- `🎨 Pixiv`：可在两个自建组、节点选择、地区组、手动切换与直连之间选择。
- Pixiv 相关域名在通用代理与媒体规则之前匹配，避免被后续规则抢先处理。

## 维护

本地规范副本位于 `C:\Projects\配置\proxy-config`。修改并验证后，再更新此仓库的同名文件。固定 Raw URL 不会因为文件内容更新而改变。

## 安全

本仓库只保存公开规则、策略组和节点名称匹配表达式，不保存订阅 URL、订阅 ID、UUID、密码、密钥或服务器管理凭据。
