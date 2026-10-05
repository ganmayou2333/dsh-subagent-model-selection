# 把 dsh-subagent-model-selection 建成 GitHub 公开仓库并推送。
#
# 用法（token 不进命令行、不落盘、不回显）：
#   $env:GITHUB_TOKEN = "<你的 PAT>"
#   pwsh -File .\push-to-github.ps1
#
# PAT 权限：fine-grained token 需 Contents: Read and write + Administration: Read and write
# （仅推送到已存在的仓库时，只有 Contents 即可；classic token 用 repo 作用域）。
#
# 说明：本机 git 直连 github.com 时 schannel 会失败，所以脚本用
#   git -c http.sslBackend=openssl -c http.sslVerify=false
# 并通过 GIT_ASKPASS 传递 token（token 不进入进程参数、不写入仓库配置）。

param(
  [string]$Owner = "",
  [string]$Repo = "dsh-subagent-model-selection",
  [string]$Description = "让 DSH main 会话可指定别的模型（如小米 MiMo）来跑 subagent：profile patch 片段、提示词与端到端验证记录",
  [switch]$Private
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

$token = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } elseif ($env:GH_TOKEN) { $env:GH_TOKEN } else { "" }
if (-not $token) {
  Write-Host "缺少 token：请先 `$env:GITHUB_TOKEN = ""<你的 PAT>"" 再运行。" -ForegroundColor Yellow
  exit 1
}

# --- 1) 创建仓库（Node 走 fetch，避开 PowerShell 在本机的 TLS 问题；token 只用环境变量传递）
$env:DSH_GH_TOKEN = $token
$env:DSH_GH_OWNER = $Owner
$env:DSH_GH_REPO = $Repo
$env:DSH_GH_DESC = $Description
$env:DSH_GH_PRIVATE = if ($Private) { "true" } else { "false" }

$api = @'
const base = "https://api.github.com";
const token = process.env.DSH_GH_TOKEN;
const headers = {
  Authorization: `Bearer ${token}`,
  Accept: "application/vnd.github+json",
  "X-GitHub-Api-Version": "2022-11-28",
  "User-Agent": "dsh-subagent-model-selection-publish",
};
const res = await fetch(`${base}/user`, { headers });
if (!res.ok) {
  console.error(`认证失败 ${res.status}: ${(await res.text()).slice(0, 200)}`);
  process.exit(1);
}
const me = await res.json();
const owner = process.env.DSH_GH_OWNER || me.login;
const name = process.env.DSH_GH_REPO;
const create = await fetch(`${base}/user/repos`, {
  method: "POST",
  headers: { ...headers, "Content-Type": "application/json" },
  body: JSON.stringify({
    name,
    description: process.env.DSH_GH_DESC,
    private: process.env.DSH_GH_PRIVATE === "true",
    has_issues: true,
    has_wiki: false,
  }),
});
if (create.status === 201) {
  const j = await create.json();
  console.log(`created ${j.full_name} (private=${j.private}) ${j.html_url}`);
} else if (create.status === 422) {
  console.log(`already exists: ${owner}/${name}（继续推送）`);
} else {
  console.error(`建库失败 ${create.status}: ${(await create.text()).slice(0, 300)}`);
  process.exit(1);
}
console.log(owner);
'@

$login = (& node --input-type=module -e $api) 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host ($login | Out-String) -ForegroundColor Red; exit 1 }
$lines = @($login)
$login = $lines[-1].ToString().Trim()
Write-Host "账号：$login"
Remove-Item Env:\DSH_GH_TOKEN -ErrorAction SilentlyContinue

# --- 2) 推送（token 经 GIT_ASKPASS 提供）
$askpass = Join-Path $env:TEMP "dsh-askpass-$([guid]::NewGuid().ToString('N')).cmd"
Set-Content -LiteralPath $askpass -Encoding ascii -Value @(
  "@echo off",
  "echo %DSH_GIT_TOKEN%"
)
$env:DSH_GIT_TOKEN = $token
$env:GIT_ASKPASS = $askpass
$env:GIT_TERMINAL_PROMPT = "0"

try {
  $url = "https://github.com/$login/$Repo.git"
  git -C $root remote remove origin 2>$null | Out-Null
  git -C $root remote add origin $url
  git -C $root -c http.sslBackend=openssl -c http.sslVerify=false push -u origin main
  if ($LASTEXITCODE -ne 0) { throw "push 失败（退出码 $LASTEXITCODE）" }
  Write-Host "已推送：$url" -ForegroundColor Green
} finally {
  Remove-Item Env:\DSH_GIT_TOKEN -ErrorAction SilentlyContinue
  Remove-Item Env:\GIT_ASKPASS -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $askpass -Force -ErrorAction SilentlyContinue
}
