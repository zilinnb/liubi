const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

const HOST = '36.140.128.103';
const USER = 'root';
const PASSWORD = 'XiaoYu@20041128';

const conn = new Client();

conn.on('ready', () => {
    console.log('Connected with key!');
    conn.exec('echo hello', (err, stream) => {
        if (err) { console.error(err); conn.end(); return; }
        stream.on('data', (data) => console.log('Output:', data.toString()));
        stream.on('close', () => conn.end());
    });
});

conn.on('error', (err) => {
    console.error('Key auth failed:', err.message);
    
    console.log('\nTrying password auth...');
    const conn2 = new Client();
    conn2.on('ready', () => {
        console.log('Connected with password!');
        conn2.exec('echo hello', (err, stream) => {
            if (err) { console.error(err); conn2.end(); return; }
            stream.on('data', (data) => console.log('Output:', data.toString()));
            stream.on('close', () => conn2.end());
        });
    });
    conn2.on('error', (err2) => {
        console.error('Password auth also failed:', err2.message);
    });
    conn2.connect({
        host: HOST,
        port: 22,
        username: USER,
        password: PASSWORD,
        readyTimeout: 30000,
    });
});

const keyPath = path.join(require('os').homedir(), '.ssh', 'id_ed25519');
console.log(`Trying key auth with ${keyPath}...`);

try {
    const keyBuffer = fs.readFileSync(keyPath);
    conn.connect({
        host: HOST,
        port: 22,
        username: USER,
        privateKey: keyBuffer,
        readyTimeout: 30000,
    });
} catch (e) {
    console.error('Cannot read key:', e.message);
    conn.connect({
        host: HOST,
        port: 22,
        username: USER,
        password: PASSWORD,
        readyTimeout: 30000,
    });
}
