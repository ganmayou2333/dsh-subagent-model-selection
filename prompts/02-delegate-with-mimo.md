# 提示词：用 MiMo 干实际活（复制整段）

```text
这次委派统一走小米 MiMo（省 token）：调用 `subagent` 时传 provider = xiaomi、model = mimo-v2.6-flash。

- 互相独立的调研/检索/审阅类子任务，放在同一条消息里一起发（后台，默认 run_in_background 省略或 true），
  然后你继续做手上的事；子任务之间不要有依赖。
- 只有「下一步动作依赖它的结果」时才走前台（run_in_background = false）。
- 子代理看不到本对话，prompt 必须自包含：目标、边界、要产出的格式、验收标准都写清楚。
- 需要更高质量时改用 model = mimo-v2.6-pro。

完成后汇总它们的结论（不要贴中间步骤）；失败或超时的子任务要单独说明，不要静默略过。
```

## 变体：并行调研 + 后台续聊

```text
用 `subagent` 起 3 个后台子代理（provider = xiaomi、model = mimo-v2.6-flash），分别调研：
A) …；B) …；C) …。每个 prompt 自包含，要求输出「结论 + 证据来源 + 不确定项」三段。

拿到 `started subagent <childId>` 后不要空等，先做你自己的部分；等它们的结算通知到了再合并。
需要追加问题时用 `send_message` 指定对应 childId，不要新起子代理。
```
