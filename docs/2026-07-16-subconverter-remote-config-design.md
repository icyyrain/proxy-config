# Subconverter 远程配置设计

## 目标

在公开 GitHub 仓库 `icyyrain/proxy-config` 中维护一份稳定的 Subconverter INI，通过固定的 `raw.githubusercontent.com` URL 供 `sub.v1.mk` 使用。更新订阅时重新获取节点并生成策略组，不手工修改最终 Clash YAML。

## 仓库结构

- `subconverter.ini`：完整远程配置，基于 ACL4SSR `ACL4SSR_Online_Full_NoAuto.ini`。
- `README.md`：记录 Raw URL、使用方法、维护方式和安全注意事项。
- `docs/2026-07-16-subconverter-remote-config-design.md`：本设计说明。

## 配置变更

1. 保留 ACL4SSR 默认规则、策略组、规则生成器设置及远程规则列表 URL。
2. 新增两个相互独立的选择组，均以 `MochaKK` 正则匹配所有自建节点：
   - `🏠 自建节点`：保存日常选择，例如 `main`。
   - `🛟 备用自建节点`：保存专项或备用选择，例如 `hysteria`。
3. 在 `🚀 节点选择` 的选项中同时加入 `🏠 自建节点` 和 `🛟 备用自建节点`。
4. 新增 `🎨 Pixiv` 选择组，可选择两个自建组、`🚀 节点选择`、六个地区组、`🚀 手动切换` 和 `DIRECT`。不引用媒体、应用或其他业务分组，避免策略组循环引用。
5. 在 ACL4SSR 通用代理和媒体规则之前加入以下域名后缀规则并指向 `🎨 Pixiv`：
   - `pixiv.net`
   - `pximg.net`
   - `pixiv.org`
   - `pixivsketch.net`

## 数据流

1. Merlin Clash 使用订阅转换后的固定订阅 URL。
2. `sub.v1.mk` 后端通过 `config=` 获取公开 Raw INI。
3. Subconverter 从原始订阅获取最新节点。
4. Subconverter 按 INI 重建策略组；两个自建组匹配相同节点，但在 Clash 中独立保存各自选择。
5. Merlin Clash 获得完整 Clash YAML；后续订阅更新不会覆盖自定义组和 Pixiv 分流。

## 安全边界

- 仓库只保存规则、组名、公开规则列表 URL 和节点名称正则。
- 不保存原始订阅 URL、订阅 ID、UUID、密码、Reality 密钥或服务器管理凭据。
- 仓库保持公开，Raw URL 无需私有仓库访问令牌。

## 验证

发布前检查：

1. 与上游 ACL4SSR INI 对比，确认只包含预期自定义修改。
2. 确认 INI 不存在已知订阅 ID、UUID、密码和管理凭据。
3. 用 Subconverter 后端生成测试 Clash 配置。
4. 检查生成结果包含 `🏠 自建节点`、`🛟 备用自建节点`、`🎨 Pixiv` 和全部预期域名规则。
5. 检查两个自建组均包含所有名称带 `MochaKK` 的节点，并可独立保存不同选择。
6. 检查 `🚀 节点选择` 同时包含两个自建组。
7. 检查 `🎨 Pixiv` 包含全部预期选项，且不存在策略组循环引用。
8. 通过 HTTPS 读取 Raw URL，确认返回最新 INI 正文。

## 发布结果

固定远程配置地址：

`https://raw.githubusercontent.com/icyyrain/proxy-config/main/subconverter.ini`
