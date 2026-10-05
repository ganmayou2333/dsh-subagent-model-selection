# 验证记录：main 会话指定小米 MiMo 跑 subagent

日期：2026-10-05（Asia/Singapore）
环境：DSH profile `web`（bundle 含 `@deepseek-ai/dsh-experimental-agent-team-profile`），pi-ai 0.87.1

## 改动

`~/.dsh/profiles/web/cordis.patch.yml`（本库 [`cordis.patch.snippet.yml`](../cordis.patch.snippet.yml) 的同款内容）：

- `tool-subagent`：`disabled: false` + `modelSelectionSettings: true`（provider `spawn`，toolName `subagent`）
- `subagent-model-selection-settings.allowedModels` 增加 `xiaomi/mimo-v2.6-flash`、`xiaomi/mimo-v2.6-pro`

配置层校验：`dsh --profile web --dump-config` 输出中该行已是

```yaml
- id: tool-subagent
  name: '@deepseek-ai/dsh-tool-subagent'
  config:
    provider: spawn
    toolName: subagent
    modelSelectionSettings: true
    backgroundMode: continuable
  disabled: false
```

## LLM 层冒烟（独立于 DSH）

`POST https://api.xiaomimimo.com/v1/chat/completions`，`model: mimo-v2.6-flash`
→ HTTP 200，`"model":"mimo-v2.6-flash"`，回复 `MIMO-SMOKE-OK`。

## 端到端（新顶层会话）

| 步骤 | 证据 |
|---|---|
| 父会话 | `session-cb002137-8c08-421b-8555-cffa7324874b`（改动后新开） |
| `list_subagent_models`（无参） | `deepseek-official — DeepSeek` / `xiaomi — xiaomi` / `moonshotai-cn — moonshotai-cn` |
| `list_subagent_models(provider=xiaomi)` | `xiaomi/mimo-v2.6-flash — MiMo-V2.6-Flash`、`xiaomi/mimo-v2.6-pro — MiMo-V2.6-Pro` |
| `subagent` 调用 | `{provider: xiaomi, model: mimo-v2.6-flash, run_in_background: false, description: "MiMo route check", prompt: "只回复这一行：MIMO-ROUTE-OK"}` |
| 工具返回 | `MIMO-ROUTE-OK`（无错误） |
| 子会话 | `301b9203-82df-4161-863b-d97dd928337b` |

子会话日志中的硬证据（逐字）：

```text
subagent/model-selection-policy
  [{"provider":"moonshotai-cn","model":"kimi-k3"},
   {"provider":"deepseek-official","model":"deepseek-flash"},
   {"provider":"xiaomi","model":"mimo-v2.6-flash"},
   {"provider":"xiaomi","model":"mimo-v2.6-pro"}]

request/header   config  {"provider":"xiaomi","model":"mimo-v2.6-flash","maxTokens":131072}
request/context         {"provider":"xiaomi","model":"mimo-v2.6-flash","contextWindow":1048576}
assistant/message        text="MIMO-ROUTE-OK"
                         source={"kind":"model","provider":"xiaomi","model":"mimo-v2.6-flash"}
                         usage={"inputTokens":31399,"outputTokens":7,"totalTokens":31406}
```

用量账本 `~/.dsh/dsh-usage/usage-ledger.json` 当日新增：`xiaomi / mimo-v2.6-flash` = 1 次调用。

## 复现步骤

1. 把 `cordis.patch.snippet.yml` 的内容并入 `~/.dsh/profiles/<profile>/cordis.patch.yml`（先备份）。
2. 确认 `XIAOMI_API_KEY` 已在凭据库（`~/.dsh/.credentials.yaml` 的 `refs`）或环境变量中。
3. `dsh --profile <profile> --dump-config`，确认 `tool-subagent` 行已启用且带 `modelSelectionSettings: true`。
4. **新开一个聊天**，执行 [`prompts/01-verify-mimo.md`](../prompts/01-verify-mimo.md)。
5. 若要核验模型真伪，读子会话日志的 `request/context` 与 `assistant/message.source`，或看用量账本。
