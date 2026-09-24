#!/usr/bin/env node
// Postinstall hint — don't fail install if opencode not present
try {
  console.log('[ai-engineering] Installed. Try: npx ai-engineering --help  or  ai-eng init --host=all --tracker=both');
  console.log('[ai-engineering] Docs: https://github.com/hungpt99-dev/ai-engineering#readme');
} catch {}
