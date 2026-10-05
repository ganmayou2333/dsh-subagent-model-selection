# 提示词：验证 MiMo 委派可用（复制整段）

```text
用 `subagent` 工具（不是 subagent_fork）做一次带模型选择的委派测试：

1. 先调 `list_subagent_models`，把返回原文贴出来；
2. 再调 `list_subagent_models` 并传 provider = xiaomi，贴出原文；
3. 用 `subagent` 跑一个子代理，参数：
   provider = xiaomi
   model = mimo-v2.6-flash
   run_in_background = false
   description = "MiMo route check"
   prompt = "只回复这一行：MIMO-ROUTE-OK"
   把这次调用的原始返回贴出来；如有报错，把错误原文一字不改地贴出（不要复述、不要省略）。

最后给我四行结论：工具是否存在 / 实际解析到的 provider+model / 子会话 id / 有无报错。
```

> 前台调用不回子会话 id。要 id 就用 `run_in_background: true`，返回 `started subagent <childId>`；
> 或事后从父会话投影的 `subagentCatalog`（含 childId 与 label）里取。
