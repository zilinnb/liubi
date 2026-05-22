/**
 * Liubi App - Auto Hot Reload Script
 * Watches lib/ directory for .dart file changes and triggers hot reload via Dart VM Service
 * Usage: node hot_reload.js [vm_service_url]
 * Example: node hot_reload.js http://127.0.0.1:8011/PkWsACz8lYE=/
 */

const fs = require('fs');
const path = require('path');
const http = require('http');

const APP_DIR = __dirname;
const LIB_DIR = path.join(APP_DIR, 'lib');
const DEBOUNCE_MS = 1500;

console.log('========================================');
console.log('  Liubi App - Auto Hot Reload');
console.log('========================================\n');

// Get VM Service URL from args or env
let vmUrl = process.argv[2] || process.env.VM_SERVICE_URL || '';

if (!vmUrl) {
  console.log('ERROR: VM Service URL is required!');
  console.log('');
  console.log('Usage:');
  console.log('  node hot_reload.js <vm_service_url>');
  console.log('');
  console.log('Steps:');
  console.log('  1. Run: flutter run -d <device_id>');
  console.log('  2. Find the VM Service URL in the output (e.g. http://127.0.0.1:8011/xxxxx/)');
  console.log('  3. Run: node hot_reload.js <that_url>');
  console.log('');
  console.log('Or set env var:');
  console.log('  $env:VM_SERVICE_URL="http://127.0.0.1:8011/xxxxx/"');
  console.log('  node hot_reload.js');
  process.exit(1);
}

// Normalize URL
if (!vmUrl.endsWith('/')) vmUrl += '/';

console.log('VM Service URL: ' + vmUrl);
console.log('Watching: ' + LIB_DIR);
console.log('');

// Get isolate ID via HTTP
function getMainIsolateId() {
  return new Promise((resolve, reject) => {
    const url = new URL(vmUrl + 'getVM');
    http.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          const isolates = json.result?.isolates || [];
          const main = isolates.find(i => i.name === 'main' && !i.isSystemIsolate);
          resolve(main ? main.id : null);
        } catch (e) {
          resolve(null);
        }
      });
    }).on('error', () => resolve(null));
  });
}

// Trigger hot reload via WebSocket using built-in http module
function triggerHotReload() {
  return new Promise(async (resolve) => {
    const isolateId = await getMainIsolateId();
    if (!isolateId) {
      console.log('  -> Could not find main isolate');
      resolve(false);
      return;
    }

    // Use WebSocket to call reloadSources
    const url = new URL(vmUrl);
    const wsUrl = `ws://${url.host}${url.pathname}ws`;
    
    try {
      // Try using the 'ws' package if available
      const WebSocket = require('ws');
      const ws = new WebSocket(wsUrl);
      
      ws.on('open', () => {
        ws.send(JSON.stringify({
          jsonrpc: '2.0',
          method: 'reloadSources',
          params: { isolateId, force: true },
          id: '1'
        }));
      });
      
      ws.on('message', (data) => {
        const resp = JSON.parse(data.toString());
        if (resp.id === '1') {
          const success = resp.result?.success === true;
          ws.close();
          resolve(success);
        }
      });
      
      ws.on('error', () => resolve(false));
      setTimeout(() => { ws.close(); resolve(false); }, 10000);
    } catch (e) {
      // Fallback: use raw HTTP approach (limited but works for basic reload)
      // Try the _hotReload HTTP endpoint
      try {
        const reloadUrl = new URL(vmUrl + '_hotReload?isolateId=' + encodeURIComponent(isolateId));
        http.get(reloadUrl, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            resolve(data.includes('OK') || data.includes('success'));
          });
        }).on('error', () => resolve(false));
      } catch (e2) {
        resolve(false);
      }
    }
  });
}

// Watch for file changes
let lastReload = 0;

fs.watch(LIB_DIR, { recursive: true }, (eventType, filename) => {
  if (!filename || !filename.endsWith('.dart')) return;

  const now = Date.now();
  if (now - lastReload < DEBOUNCE_MS) return;
  lastReload = now;

  const time = new Date().toLocaleTimeString('en-US', { hour12: false });
  console.log(`[${time}] File changed: ${filename}`);

  triggerHotReload().then(success => {
    if (success) {
      console.log('  -> Hot reload SUCCESS');
    } else {
      console.log('  -> Hot reload FAILED (try pressing r in flutter run terminal)');
    }
  });
});

console.log('========================================');
console.log('  Hot reload watcher started! Press Ctrl+C to exit');
console.log('========================================\n');

process.on('SIGINT', () => {
  console.log('\nHot reload mode exited');
  process.exit(0);
});
