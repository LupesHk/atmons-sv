const { Client, LocalAuth } = require('whatsapp-web.js');

console.log('BOT INICIANDO');

const client = new Client({
    authStrategy: new LocalAuth({
        dataPath: './auth'
    }),
    puppeteer: {
        headless: false, // deixe false na primeira vez
        args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--start-minimized',
        '--window-position=-32000,-32000'
        ]
    }
});

client.on('qr', qr => {
    console.log('================ QR CODE ================');
    console.log(qr);
    console.log('Escaneie com o WhatsApp');
});

client.on('ready', async () => {
    console.log('BOT PRONTO');

    const status = process.argv[2] || 'on';
    const GROUP_ID = '120363422551337361@g.us';

    const msg =
        status === 'on'
            ? '🟢 Servidor Minecraft ONLINE'
            : '🔴 Servidor Minecraft OFFLINE';

    try {
        await client.sendMessage(GROUP_ID, msg);
        console.log('Mensagem enviada com sucesso');
    } catch (err) {
        console.error('Erro ao enviar mensagem:', err);
    }

    // ⏳ TEMPO CRÍTICO PARA O WHATS PROCESSAR
    setTimeout(() => {
        console.log('Encerrando bot com segurança');
        process.exit(0);
    }, 6000);
});

client.initialize();
