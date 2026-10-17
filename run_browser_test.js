const http = require('http');
const net = require('net');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const userDataDir = path.join(process.env.TEMP, 'chrome_test_profile_' + Date.now());
fs.mkdirSync(userDataDir, { recursive: true });

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const chrome = spawn(chromePath, [
  '--headless=new',
  '--remote-debugging-port=9222',
  '--window-size=1280,720',
  '--user-data-dir=' + userDataDir,
  '--no-first-run',
  '--no-default-browser-check',
  'http://127.0.0.1:8085/'
]);

function getJson(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(JSON.parse(data)));
    }).on('error', reject);
  });
}

function connectWs(wsUrl) {
  return new Promise((resolve, reject) => {
    const url = new URL(wsUrl);
    const host = url.hostname;
    const port = url.port || 80;
    const path = url.pathname;
    const key = crypto.randomBytes(16).toString('base64');

    const socket = net.connect(port, host, () => {
      const headers = [
        `GET ${path} HTTP/1.1`,
        `Host: ${host}:${port}`,
        'Upgrade: websocket',
        'Connection: Upgrade',
        `Sec-WebSocket-Key: ${key}`,
        'Sec-WebSocket-Version: 13',
        '\r\n'
      ].join('\r\n');
      socket.write(headers);
    });

    let isUpgraded = false;
    let buffer = Buffer.alloc(0);

    const client = {
      send: (method, params = {}) => {
        return new Promise((res, rej) => {
          const id = ++msgId;
          pending[id] = { res, rej };
          const payload = Buffer.from(JSON.stringify({ id, method, params }), 'utf8');
          let frameHeader;
          if (payload.length < 126) {
            frameHeader = Buffer.alloc(6);
            frameHeader[0] = 0x81;
            frameHeader[1] = 0x80 | payload.length;
          } else if (payload.length < 65536) {
            frameHeader = Buffer.alloc(8);
            frameHeader[0] = 0x81;
            frameHeader[1] = 0x80 | 126;
            frameHeader.writeUInt16BE(payload.length, 2);
          } else {
            frameHeader = Buffer.alloc(14);
            frameHeader[0] = 0x81;
            frameHeader[1] = 0x80 | 127;
            frameHeader.writeBigUInt64BE(BigInt(payload.length), 2);
          }
          const maskKey = crypto.randomBytes(4);
          maskKey.copy(frameHeader, frameHeader.length - 4);
          const masked = Buffer.alloc(payload.length);
          for (let i = 0; i < payload.length; i++) {
            masked[i] = payload[i] ^ maskKey[i % 4];
          }
          socket.write(Buffer.concat([frameHeader, masked]));
        });
      },
      close: () => socket.destroy()
    };

    let msgId = 0;
    const pending = {};

    socket.on('data', (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      if (!isUpgraded) {
        const str = buffer.toString('utf8');
        const idx = str.indexOf('\r\n\r\n');
        if (idx !== -1) {
          isUpgraded = true;
          buffer = buffer.slice(idx + 4);
          resolve(client);
        }
        return;
      }

      while (buffer.length >= 2) {
        const b0 = buffer[0];
        const b1 = buffer[1];
        const opcode = b0 & 0x0f;
        if (opcode === 0x8) {
          socket.destroy();
          return;
        }
        let payloadLen = b1 & 0x7f;
        let offset = 2;
        if (payloadLen === 126) {
          if (buffer.length < 4) break;
          payloadLen = buffer.readUInt16BE(2);
          offset = 4;
        } else if (payloadLen === 127) {
          if (buffer.length < 10) break;
          payloadLen = Number(buffer.readBigUInt64BE(2));
          offset = 10;
        }
        if (buffer.length < offset + payloadLen) break;
        const payload = buffer.slice(offset, offset + payloadLen);
        buffer = buffer.slice(offset + payloadLen);

        try {
          const msg = JSON.parse(payload.toString('utf8'));
          if (msg.id && pending[msg.id]) {
            if (msg.error) pending[msg.id].rej(msg.error);
            else pending[msg.id].res(msg.result);
            delete pending[msg.id];
          } else if (msg.method === 'Runtime.consoleAPICalled') {
            console.log('[BROWSER CONSOLE]', msg.params.type, msg.params.args.map(a => a.value || a.description || JSON.stringify(a)).join(' '));
          }
        } catch (e) {}
      }
    });

    socket.on('error', reject);
  });
}

async function run() {
  console.log('Waiting for Chrome CDP...');
  await new Promise(r => setTimeout(r, 2000));
  let targets = null;
  for (let i = 0; i < 10; i++) {
    try {
      targets = await getJson('http://127.0.0.1:9222/json');
      if (targets) break;
    } catch (e) {
      await new Promise(r => setTimeout(r, 500));
    }
  }
  if (!targets) throw new Error('Could not get targets');

  const gameTarget = targets.find(t => t.url.includes('8085') || t.title.includes('Banners of Glory')) || targets[0];
  console.log('Target found:', gameTarget.title, gameTarget.url);

  const client = await connectWs(gameTarget.webSocketDebuggerUrl);
  await client.send('Runtime.enable');
  await client.send('Page.enable');

  console.log('Waiting 5s for Godot to boot and hide splash...');
  await new Promise(r => setTimeout(r, 5000));

  // Capture initial screenshot
  let shot = await client.send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync('D:/GitHub/Banners of Glory/test_1_initial.png', Buffer.from(shot.data, 'base64'));
  console.log('Saved test_1_initial.png');

  // TEST 1: Click empty terrain at (400, 300)
  console.log('--- TEST: Click empty terrain at (400, 300) ---');
  await client.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 400, y: 300, button: 'left', clickCount: 1 });
  await new Promise(r => setTimeout(r, 50));
  await client.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 400, y: 300, button: 'left', clickCount: 1 });
  await new Promise(r => setTimeout(r, 800)); // wait for camera lerp

  shot = await client.send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync('D:/GitHub/Banners of Glory/test_2_after_terrain_click.png', Buffer.from(shot.data, 'base64'));
  console.log('Saved test_2_after_terrain_click.png');

  // TEST 2: Click overview button at (1240, 680)
  console.log('--- TEST: Click overview button at (1240, 680) ---');
  await client.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 1240, y: 680, button: 'left', clickCount: 1 });
  await new Promise(r => setTimeout(r, 50));
  await client.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 1240, y: 680, button: 'left', clickCount: 1 });
  await new Promise(r => setTimeout(r, 800));

  shot = await client.send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync('D:/GitHub/Banners of Glory/test_3_after_overview_button.png', Buffer.from(shot.data, 'base64'));
  console.log('Saved test_3_after_overview_button.png');

  // TEST 3: Click Great Palace
  console.log('--- TEST: Click Great Palace at center (640, 360) ---');
  await client.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 640, y: 360, button: 'left', clickCount: 1 });
  await new Promise(r => setTimeout(r, 50));
  await client.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 640, y: 360, button: 'left', clickCount: 1 });
  await new Promise(r => setTimeout(r, 800));

  shot = await client.send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync('D:/GitHub/Banners of Glory/test_4_after_palace_click.png', Buffer.from(shot.data, 'base64'));
  console.log('Saved test_4_after_palace_click.png');

  // TEST 4: Drag map from (640, 360) to (500, 250)
  console.log('--- TEST: Drag map ---');
  await client.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 640, y: 360, button: 'left' });
  await new Promise(r => setTimeout(r, 50));
  for (let step = 1; step <= 5; step++) {
    const curX = Math.round(640 + (500 - 640) * (step / 5));
    const curY = Math.round(360 + (250 - 360) * (step / 5));
    await client.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: curX, y: curY, button: 'left' });
    await new Promise(r => setTimeout(r, 30));
  }
  await client.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 500, y: 250, button: 'left' });
  await new Promise(r => setTimeout(r, 800));

  shot = await client.send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync('D:/GitHub/Banners of Glory/test_5_after_drag.png', Buffer.from(shot.data, 'base64'));
  console.log('Saved test_5_after_drag.png');

  client.close();
  chrome.kill();
  console.log('All tests completed.');
  process.exit(0);
}

run().catch(err => {
  console.error('Fatal error:', err);
  chrome.kill();
  process.exit(1);
});
