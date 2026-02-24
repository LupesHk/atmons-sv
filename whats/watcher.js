const fs = require('fs');
const { exec } = require('child_process');
const path = require('path');

const LOG_FILE = path.join(__dirname, 'logs', 'latest.log');
const NOTIFY_FILE = path.join(__dirname, 'notify.txt');

let lastLogSize = 0;
let serverOnline = false;

// evita spam
const cooldown = {};
const COOLDOWN_MS = 60_000;

function canSend(key) {
    const now = Date.now();
    if (!cooldown[key] || now - cooldown[key] > COOLDOWN_MS) {
        cooldown[key] = now;
        return true;
    }
    return false;
}

function send(event, extra = '') {
    console.log(`➡ Enviando evento: ${event} ${extra}`);
    exec(`node whats/bot.js ${event} ${extra}`, err => {
        if (err) console.error('Erro ao chamar bot:', err.message);
    });
}

/* ===========================
   WATCH notify.txt
=========================== */
setInterval(() => {
    if (!fs.existsSync(NOTIFY_FILE)) return;

    const content = fs.readFileSync(NOTIFY_FILE, 'utf8').trim();
    if (!content) return;

    if (content === 'STARTING' && canSend('starting')) {
        send('starting');
    }

    fs.writeFileSync(NOTIFY_FILE, '');
}, 3000);

/* ===========================
   WATCH Minecraft log
=========================== */
setInterval(() => {
    if (!fs.existsSync(LOG_FILE)) return;

    const stats = fs.statSync(LOG_FILE);
    if (stats.size < lastLogSize) {
        lastLogSize = 0; // log reset
    }

    if (stats.size === lastLogSize) return;

    const stream = fs.createReadStream(LOG_FILE, {
        start: lastLogSize,
        end: stats.size
    });

    let buffer = '';
    stream.on('data', chunk => buffer += chunk.toString());

    stream.on('end', () => {
        lastLogSize = stats.size;

        const lines = buffer.split('\n');
        for (const line of lines) {

            // 🟢 SERVIDOR ONLINE
            if (!serverOnline && line.includes('Done (')) {
                serverOnline = true;
                if (canSend('online')) send('online');
            }

            // 👤 PLAYER ENTROU
            if (line.includes(' joined the game')) {
                const match = line.match(/]: (.+) joined the game/);
                if (match && canSend(`join-${match[1]}`)) {
                    send('join', match[1]);
                }
            }

            // 🔴 SERVIDOR OFFLINE
            if (line.includes('Stopping server')) {
                serverOnline = false;
                if (canSend('offline')) send('offline');
            }
        }
    });
}, 2000);

console.log('👀 Watcher iniciado e monitorando servidor...');
