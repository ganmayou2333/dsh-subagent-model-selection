# dsh-subagent-model-selection

让 **main 会话的模型可以指定另一个模型来跑 subagent**（DeepSeek Harness / DSH）。
本库提供：可直接粘贴的 profile patch、提示词模板，以及一条端到端验证记录（2026-10-05，用小米 MiMo 实测通过）。

English abstract: make DSH's model-facing `subagent` tool expose `provider` / `model` / `reasoning_effort`
so the main agent can delegate to a different LLM (here: Xiaomi MiMo), including the patch that
re-enables the tool when the Agent Teams profile layer disables it.

## 1. 问题：为什么「子代理模型选择」配了却不生效

DSH 里让 main 会话选模型跑 subagent，靠两件事：

1. `subagent` 工具（`@deepseek-ai/dsh-tool-subagent`，`provider: spawn`）打开 `modelSelectionSettings: true`；
2. `subagent-model-selection-settings` 插件放行具体路由（provider + model）。

但如果你装了 Agent Teams 的 profile 层：

```yaml
# @deepseek-ai/dsh-experimental-agent-team-profile/cordis.patch.yml
- id: tool-subagent
  disabled: true
```

它会**把直连委派工具整行禁用**（`tool-subagent-control`、`tool-subagent-list-agents`、`tool-subagent-fork` 同样被禁用），
改用 team 工具（`spawn_teammate` / `send_message` / `list_agents` / `team_task_*`）。
结果是：main 会话里根本没有 `subagent` 工具，配置写得再对也不会出现 `provider` / `model` 参数。

> 注：本部署里 `subagent_fork` 仍可用（profile 层后置覆盖所致），但 fork 设计上**继承父路由**，不能选模型。

## 2. 修复：在自己 profile 层覆盖（晚于所有 bundle 层）

见 [`cordis.patch.snippet.yml`](cordis.patch.snippet.yml)。要点：

- 用同 id 覆盖，显式 `disabled: false`；
- 保留 `provider: spawn` 与 `toolName: subagent`；
- 打开 `modelSelectionSettings: true`；
- 在 `subagent-model-selection-settings.config.allowedModels` 里加入你要放行的路由。

小米 MiMo 依赖 pi-ai 原生路由（`@earendil-works/pi-ai`，id `xiaomi`）：

- baseURL：`https://api.xiaomimimo.com/v1`（OpenAI 兼容）
- 凭据：`apiKeyEnv: XIAOMI_API_KEY`
- 目录内模型：`mimo-v2.6-flash`、`mimo-v2.6-pro`（另有 `mimo-v2.5*` 等）

## 3. 生效条件（最容易踩的坑）

- profile 的 `patchReload: live` 会让改动**热加载**，但 **agent 的工具集是在会话组合时安装的**：
  改动前就已经存在的会话（包括你正在用的那个）**不会**凭空多出 `subagent` 工具，刷新页面也没用。
- **必须新开一个聊天**（新的顶层 Session）。
- 放行路由列表在**会话创建时写入该会话**（事件 `subagent/model-selection-policy`），之后修改 `allowedModels`
  不会影响已存在的会话；子会话继承父会话记录的那份列表。

## 4. 用法

工具面（模型可见）：

- `subagent{ description, prompt, provider?, model?, reasoning_effort?, run_in_background? }`
- `list_subagent_models{ provider? }`：只列出被当前会话策略放行、且适配器真实注册的路由

行为差异：

| 模式 | 返回 | 说明 |
|---|---|---|
| `run_in_background: false`（前台） | 只返回子代理最终文本 | **不返回子会话 id** |
| `run_in_background: true`（默认） | `started subagent <childId>` | 可后续 `send_message` 续聊 |

提示词模板见 [`prompts/`](prompts/)。

## 5. 验证记录

[`evidence/2026-10-05-mimo-verification.md`](evidence/2026-10-05-mimo-verification.md)：
新顶层会话 → `list_subagent_models` → `subagent(provider=xiaomi, model=mimo-v2.6-flash)` →
子会话 `request/context` 显示 `provider: xiaomi, model: mimo-v2.6-flash`，回复 `MIMO-ROUTE-OK`，用量记账 1 次调用。

## 6. 限制与注意

- 本库**不**重新启用 `tool-subagent-control` / `tool-subagent-list-agents`：它们与 Agent Teams 的
  `send_message` / `list_agents` 同名，重新启用可能造成工具名冲突。选模型用 `subagent` 即可。
- `allowedModels` 只放行白名单；未列入的路由会被拒绝（`child LLM route "…" is not allowed for this Session`）。
- 委派深度受 Host `subagents.maxDepth`（默认 1）约束：main 的子代理**不能再往下委派**，
  除非在工具配置里放宽 `maxDepth`。
- 库内不含任何密钥；`apiKeyEnv` 指向 DSH 凭据库中的引用名。

## 发布到 GitHub

```powershell
$env:GITHUB_TOKEN = "<PAT>"
pwsh -File .\push-to-github.ps1            # 默认建公开仓库
pwsh -File .\push-to-github.ps1 -Private   # 建私有仓库
```

脚本先用 GitHub API 建仓库（已存在则跳过），再用 `GIT_ASKPASS` 推送 `main`。
token 只经环境变量传递，不进入命令行参数、不写入 `.git/config`、不回显。
本机 git 直连 github.com 会因 schannel 失败，脚本已带 `http.sslBackend=openssl http.sslVerify=false`。

## License

MIT，见 [LICENSE](LICENSE)。
