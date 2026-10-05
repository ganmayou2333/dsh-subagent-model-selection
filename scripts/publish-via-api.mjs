#!/usr/bin/env node
/**
 * 用 GitHub Contents API 把本目录的文件发布到仓库。
 *
 * 用途：当 github.com:443 的 git push 被网络挡住、但 api.github.com 可达时，
 * 仍能完成发布（逐文件提交，不需要 git 远程）。
 *
 * 用法：
 *   $env:GITHUB_TOKEN = "<PAT>"
 *   node scripts/publish-via-api.mjs [owner/repo]
 *
 * token 权限：fine-grained 需要 Contents: Read and write（仓库已存在时足够）。
 * token 只从环境变量读取，不落盘、不回显。
 */
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
if (!token) {
  console.error('缺少 token：请先设置 GITHUB_TOKEN 环境变量。');
  process.exit(1);
}

const target = (process.argv[2] || 'ganmayou2333/dsh-subagent-model-selection').split('/');
const [owner, repo] = [target[0], target[1]];
if (!owner || !repo) {
  console.error('用法：node scripts/publish-via-api.mjs <owner>/<repo>');
  process.exit(1);
}

const root = join(import.meta.dirname, '..');
const skip = new Set(['.git', 'node_modules', '.staging']);
const headers = {
  Authorization: `Bearer ${token}`,
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'dsh-subagent-model-selection-publish',
  'Content-Type': 'application/json',
};

const api = `https://api.github.com/repos/${owner}/${repo}/contents`;

function walk(dir, out = []) {
  for (const entry of readdirSync(dir)) {
    if (skip.has(entry)) continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, out);
    else out.push(full);
  }
  return out;
}

async function request(url, init, label) {
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      const res = await fetch(url, { ...init, signal: AbortSignal.timeout(30000) });
      if (res.ok || res.status === 404) return res;
      if (res.status >= 500 || res.status === 429) {
        console.error(`  ${label}: HTTP ${res.status}，重试 ${attempt}/4`);
      } else {
        console.error(`  ${label}: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`);
        process.exit(1);
      }
    } catch (error) {
      console.error(`  ${label}: ${error.message}，重试 ${attempt}/4`);
    }
    await new Promise((r) => setTimeout(r, 1500 * attempt));
  }
  console.error(`  ${label}: 重试耗尽`);
  process.exit(1);
}

const files = walk(root).sort();
console.log(`准备发布 ${files.length} 个文件到 ${owner}/${repo}`);
let created = 0;
let updated = 0;

for (const file of files) {
  const path = relative(root, file).split(sep).join('/');
  const content = readFileSync(file).toString('base64');
  const existing = await request(`${api}/${encodeURI(path)}`, { headers, method: 'GET' }, `GET ${path}`);
  const body = {
    message: existing.status === 404 ? `add ${path}` : `update ${path}`,
    content,
    ...(existing.status === 200 ? { sha: (await existing.json()).sha } : {}),
  };
  await request(`${api}/${encodeURI(path)}`, { headers, method: 'PUT', body: JSON.stringify(body) }, `PUT ${path}`);
  if (existing.status === 404) created++;
  else updated++;
  console.log(`  ${existing.status === 404 ? 'created' : 'updated'} ${path}`);
}

console.log(`完成：新增 ${created}，更新 ${updated}。https://github.com/${owner}/${repo}`);
