const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

const HOST = '36.140.128.103';
const USER = 'root';
const PASSWORD = 'XiaoYu@20041128';
const REMOTE_BASE = '/www/wwwroot/liubi/server';
const LOCAL_BASE = path.join(__dirname, 'server');

const FILES = [
    'routes/notifications.js',
    'utils/mailer.js',
    'server.js',
];

const conn = new Client();

conn.on('ready', () => {
    console.log('SSH connected!');
    
    conn.sftp((err, sftp) => {
        if (err) {
            console.error('SFTP error:', err);
            conn.end();
            return;
        }
        
        let uploaded = 0;
        const total = FILES.length;
        
        FILES.forEach(relPath => {
            const localPath = path.join(LOCAL_BASE, relPath.replace(/\//g, path.sep));
            const remotePath = `${REMOTE_BASE}/${relPath}`;
            
            console.log(`Uploading ${relPath} -> ${remotePath}`);
            
            const readStream = fs.createReadStream(localPath);
            const writeStream = sftp.createWriteStream(remotePath);
            
            writeStream.on('close', () => {
                console.log(`  Done: ${relPath}`);
                uploaded++;
                if (uploaded === total) {
                    console.log('\nAll files uploaded!');
                    restartPM2();
                }
            });
            
            writeStream.on('error', (err) => {
                console.error(`  Error uploading ${relPath}:`, err);
            });
            
            readStream.pipe(writeStream);
        });
    });
});

function restartPM2() {
    console.log('\nRestarting PM2...');
    conn.exec(`cd ${REMOTE_BASE} && pm2 restart liubi && pm2 list`, (err, stream) => {
        if (err) {
            console.error('PM2 restart error:', err);
            conn.end();
            return;
        }
        
        stream.on('data', (data) => {
            console.log(data.toString());
        });
        
        stream.on('close', () => {
            console.log('\nDeployment complete!');
            conn.end();
        });
        
        stream.stderr.on('data', (data) => {
            console.error('STDERR:', data.toString());
        });
    });
}

conn.on('error', (err) => {
    console.error('SSH connection error:', err.message);
});

console.log(`Connecting to ${HOST}...`);
conn.connect({
    host: HOST,
    port: 22,
    username: USER,
    password: PASSWORD,
    readyTimeout: 30000,
    algorithms: {
        kex: [
            'curve25519-sha256',
            'curve25519-sha256@libssh.org',
            'ecdh-sha2-nistp256',
            'ecdh-sha2-nistp384',
            'ecdh-sha2-nistp521',
            'diffie-hellman-group-exchange-sha256',
            'diffie-hellman-group14-sha256',
            'diffie-hellman-group16-sha512',
            'diffie-hellman-group18-sha512',
        ],
    },
});
