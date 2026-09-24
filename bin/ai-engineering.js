#!/usr/bin/env node
/**
 * ai-engineering CLI — host-agnostic, tracker-pluggable
 * Install globally: npm install -g ai-engineering  (or npx ai-engineering)
 * Then in ANY app repo:  ai-eng init  |  ai-eng sync  |  ai-eng check  |  ai-eng global
 *
 * Thin wrapper around setup/* and scripts/* — keeps logic in bash/ps1, CLI just routes.
 */
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const HARNESS_ROOT = path.resolve(__dirname, '..');
const VERSION = (() => { try { return JSON.parse(fs.readFileSync(path.join(HARNESS_ROOT,'package.json'),'utf8')).version; } catch { return '2.0.0'; }})();

function printHelp() {
  console.log(`
ai-engineering v${VERSION} — AI harness CLI (OpenCode/Claude/Codex + Redmine/Jira + Dify)

Usage:
  ai-eng init [path] [--host=opencode|claude|codex|all] [--tracker=redmine|jira|both|none] [--force]
  ai-eng sync [--host=opencode|claude|codex|all] [--force]   Sync .opencode → .claude/.agents/.mcp.json/.codex
  ai-eng check [--tracker=redmine|jira|both]                Health check (host+tracker pluggable)
  ai-eng install [--host=...] [--tracker=...] [--yes]       Full harness install (hosts+trackers+Dify build)
  ai-eng global                                             Install harness globally (~/.config/opencode etc.)
  ai-eng doctor                                             Alias for check

Options:
  --host     Host to target (default: opencode for install/init, all for sync)
  --tracker  Tracker to target (default: redmine)
  --force    Overwrite existing host configs
  --yes      Non-interactive (skip TUI)
  --help, -h Show help

Examples:
  # In any app repo, one command to make it AI-ready (OpenCode+Redmine default):
  npx ai-engineering init
  ai-eng init --host=claude --tracker=jira
  ai-eng init ./my-app --host=all --tracker=both --force

  # Already have harness cloned? Make it global:
  ai-eng global

  # Sync skills/agents to Claude/Codex locations in current project:
  ai-eng sync --host=all

  # Validate:
  ai-eng check --tracker=jira

Docs: ${HARNESS_ROOT}/docs/setup.md  ${HARNESS_ROOT}/config/hosts/README.md
Repo: https://github.com/hungpt99-dev/ai-engineering
`);
}

function isWindows() { return process.platform === 'win32'; }

function runScript(scriptRel, args, opts={}) {
  const full = path.join(HARNESS_ROOT, scriptRel);
  // Prefer bash on Windows if script is .sh and bash exists, else use .ps1 via powershell
  const usePs = isWindows() && full.endsWith('.ps1');
  let cmd, cmdArgs;
  if (usePs) {
    cmd = 'powershell';
    cmdArgs = ['-ExecutionPolicy','Bypass','-File', full, ...args];
  } else {
    // .sh — invoke via bash (Git Bash / WSL bash on Windows, bash on *nix)
    const bash = isWindows() ? 'bash' : 'bash';
    cmd = bash;
    cmdArgs = [full, ...args];
  }
  const res = spawnSync(cmd, cmdArgs, { stdio: 'inherit', cwd: opts.cwd || process.cwd(), shell: false });
  return res.status === 0;
}

function parseArgs(argv) {
  const out = { _: [], host: null, tracker: null, force: false, yes: false, help: false };
  for (const a of argv) {
    if (a === '--help' || a === '-h') out.help = true;
    else if (a.startsWith('--host=')) out.host = a.split('=')[1];
    else if (a.startsWith('--tracker=')) out.tracker = a.split('=')[1];
    else if (a === '--force') out.force = true;
    else if (a === '--yes') out.yes = true;
    else if (!a.startsWith('--')) out._.push(a);
  }
  return out;
}

function ensureDir(p) { fs.mkdirSync(p, { recursive: true }); }

function copyDirRecursive(src, dst, force) {
  if (!fs.existsSync(src)) return;
  ensureDir(dst);
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      // skip node_modules and dist if force false and dst exists with content? Always copy except node_modules
      if (entry.name === 'node_modules') continue;
      copyDirRecursive(s, d, force);
    } else {
      if (fs.existsSync(d) && !force) continue;
      ensureDir(path.dirname(d));
      fs.copyFileSync(s, d);
    }
  }
}

function copyFile(src, dst, force) {
  if (fs.existsSync(dst) && !force) { console.log(`[info] skip ${dst} (exists, use --force)`); return; }
  ensureDir(path.dirname(dst));
  fs.copyFileSync(src, dst);
  console.log(`[ok] ${path.relative(process.cwd(), dst)}`);
}

function cmdInit(targetPath, opts) {
  const cwd = targetPath ? path.resolve(targetPath) : process.cwd();
  const host = opts.host || 'opencode';
  const tracker = opts.tracker || 'redmine';
  const force = opts.force;
  console.log(`[info] ai-eng init → ${cwd}  host=${host} tracker=${tracker}${force?' --force':''}`);

  ensureDir(cwd);

  // 1. opencode.json (if host includes opencode)
  if (host === 'opencode' || host === 'all') {
    copyFile(path.join(HARNESS_ROOT,'opencode.json'), path.join(cwd,'opencode.json'), force);
  }
  // Ensure Dify MCP adapter is present in target for any host (all hosts use same mcp/dify-knowledge)
  {
    const srcMcp = path.join(HARNESS_ROOT,'mcp');
    const dstMcp = path.join(cwd,'mcp');
    if (!fs.existsSync(path.join(dstMcp,'dify-knowledge','dist','index.js'))) {
      if (fs.existsSync(srcMcp)) {
        console.log(`[info] Copying Dify MCP adapter to ${dstMcp} ...`);
        copyDirRecursive(srcMcp, dstMcp, force);
        const targetDist = path.join(dstMcp,'dify-knowledge','dist','index.js');
        if (!fs.existsSync(targetDist)) {
          console.log('[info] Building Dify MCP in target (npm install + build)...');
          const r = spawnSync('npm', ['--prefix', path.join(dstMcp,'dify-knowledge'), 'install'], { stdio: 'inherit', cwd });
          if (r.status === 0) spawnSync('npm', ['--prefix', path.join(dstMcp,'dify-knowledge'), 'run', 'build'], { stdio: 'inherit', cwd });
          if (!fs.existsSync(targetDist)) console.log('[warn] Dify MCP build in target failed — run manually: npm --prefix mcp/dify-knowledge install && npm --prefix mcp/dify-knowledge run build');
          else console.log('[ok] Dify MCP built in target');
        }
      } else {
        console.log('[warn] Dify MCP source not found at '+srcMcp);
      }
    }
  }
  // 2. .mcp.json (if host includes claude)
  if (host === 'claude' || host === 'all') {
    copyFile(path.join(HARNESS_ROOT,'config','hosts','claude-code','mcp.json.example'), path.join(cwd,'.mcp.json'), force);
  }
  // 3. .codex/config.toml (if host includes codex)
  if (host === 'codex' || host === 'all') {
    copyFile(path.join(HARNESS_ROOT,'config','hosts','codex','config.toml.example'), path.join(cwd,'.codex','config.toml'), force);
  }
  // 4. .opencode (always — source of truth, universal skills)
  const srcAgents = path.join(HARNESS_ROOT,'.opencode','agents');
  const srcSkills = path.join(HARNESS_ROOT,'.opencode','skills');
  const srcCommands = path.join(HARNESS_ROOT,'.opencode','commands');
  function syncDir(src, dst) {
    if (!fs.existsSync(src)) return;
    for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        const s = path.join(src, entry.name);
        const d = path.join(dst, entry.name);
        ensureDir(d);
        const skillFile = path.join(s,'SKILL.md');
        if (fs.existsSync(skillFile)) copyFile(skillFile, path.join(d,'SKILL.md'), force);
      } else if (entry.isFile() && entry.name.endsWith('.md')) {
        copyFile(path.join(src, entry.name), path.join(dst, entry.name), force);
      }
    }
  }
  syncDir(srcAgents, path.join(cwd,'.opencode','agents'));
  syncDir(srcSkills, path.join(cwd,'.opencode','skills'));
  syncDir(srcCommands, path.join(cwd,'.opencode','commands'));
  // 5. Also sync to host-specific dirs in target for immediate use (so target repo is host-ready without extra sync)
  if (host === 'claude' || host === 'all') {
    syncDir(srcAgents, path.join(cwd,'.claude','agents'));
    syncDir(srcSkills, path.join(cwd,'.claude','skills'));
  }
  if (host === 'codex' || host === 'all') {
    syncDir(srcSkills, path.join(cwd,'.agents','skills'));
  }
  // 6. AGENTS.md + .env.example
  copyFile(path.join(HARNESS_ROOT,'AGENTS.md'), path.join(cwd,'AGENTS.md'), force);
  if (!fs.existsSync(path.join(cwd,'.env')) && fs.existsSync(path.join(HARNESS_ROOT,'.env.example'))) {
    copyFile(path.join(HARNESS_ROOT,'.env.example'), path.join(cwd,'.env.example'), true);
    console.log(`[info] Created ${path.join(cwd,'.env.example')} — copy to .env and fill ${tracker} creds`);
  }
  // 7. Filter tracker in generated opencode.json/.mcp.json if tracker != both (keep file but user can enable/disable via enabled flag)
  console.log(`\n[ok] ai-eng init done for host=${host} tracker=${tracker} → ${cwd}`);
  console.log(`Next: cd ${path.relative(process.cwd(), cwd) || '.'} && cp .env.example .env  # fill DIFY_* + ${tracker.toUpperCase()}_*`);
  console.log(`      ai-eng check --tracker=${tracker}   (or: npx ai-engineering check)`);
  console.log(`      ${host === 'opencode' ? 'opencode' : host === 'claude' ? 'claude' : host === 'codex' ? 'codex' : 'opencode|claude|codex'}  # start host`);
}

function cmdSync(opts) {
  const host = opts.host || 'all';
  const args = [`--host=${host}`];
  if (opts.force) args.push('--force');
  const script = isWindows() ? 'scripts/sync-hosts.ps1' : 'scripts/sync-hosts.sh';
  // PowerShell version takes -HostName, bash takes --host
  if (isWindows()) {
    const psArgs = ['-HostName', host];
    if (opts.force) psArgs.push('-Force');
    return runScript('scripts/sync-hosts.ps1', psArgs);
  } else {
    return runScript('scripts/sync-hosts.sh', args);
  }
}

function cmdCheck(opts) {
  const tracker = opts.tracker;
  const extra = tracker ? [`--tracker=${tracker}`] : [];
  if (isWindows()) {
    const psArgs = [];
    if (tracker) psArgs.push('-Tracker', tracker);
    return runScript('setup/check.ps1', psArgs);
  } else {
    return runScript('setup/check.sh', extra);
  }
}

function cmdInstall(opts) {
  const args = [];
  if (opts.host) args.push(`--host=${opts.host}`);
  if (opts.tracker) args.push(`--tracker=${opts.tracker}`);
  if (opts.yes) args.push('--yes');
  if (isWindows()) {
    const psArgs = [];
    if (opts.host) psArgs.push('-Host', opts.host);
    if (opts.tracker) psArgs.push('-Tracker', opts.tracker);
    if (opts.yes) psArgs.push('-Yes');
    return runScript('setup/install.ps1', psArgs);
  } else {
    return runScript('setup/install.sh', args);
  }
}

function cmdGlobal() {
  if (isWindows()) return runScript('scripts/install-global.ps1', []);
  else return runScript('scripts/install-global.sh', []);
}

function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv.includes('--help') || argv.includes('-h')) { printHelp(); process.exit(0); }
  const cmd = argv[0];
  const rest = argv.slice(1);
  const opts = parseArgs(rest);
  if (opts.help) { printHelp(); process.exit(0); }

  let ok = false;
  switch (cmd) {
    case 'init': {
      const target = opts._[0] || null;
      cmdInit(target, { host: opts.host, tracker: opts.tracker, force: opts.force });
      ok = true;
      break;
    }
    case 'sync': ok = cmdSync(opts); break;
    case 'check':
    case 'doctor': ok = cmdCheck(opts); break;
    case 'install': ok = cmdInstall(opts); break;
    case 'global': ok = cmdGlobal(); break;
    case 'help': printHelp(); ok = true; break;
    default:
      console.error(`Unknown command: ${cmd}`);
      printHelp();
      process.exit(1);
  }
  process.exit(ok ? 0 : 1);
}

main();
