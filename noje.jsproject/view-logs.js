// view-logs.js - Kullanıcı Dostu Log Görüntüleyici
// Kullanım: node view-logs.js [seçenekler]

const fs = require('fs');
const path = require('path');
const readline = require('readline');

// Renk kodları
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    dim: '\x1b[2m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
    white: '\x1b[37m',
    gray: '\x1b[90m'
};

const logsDir = path.join(__dirname, 'logs');
const today = new Date().toISOString().split('T')[0];

// Komut satırı argümanlarını parse et
const args = process.argv.slice(2);
const options = {
    file: 'application', // application, error, exceptions, rejections
    lines: 50, // Son kaç satır gösterilecek
    follow: false, // Real-time izleme
    filter: null, // Filtre (error, warn, info, http)
    search: null, // Arama terimi
    date: today // Tarih (YYYY-MM-DD)
};

// Argümanları parse et
for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--file' || arg === '-f') {
        options.file = args[++i] || 'application';
    } else if (arg === '--lines' || arg === '-n') {
        options.lines = parseInt(args[++i]) || 50;
    } else if (arg === '--follow' || arg === '-F') {
        options.follow = true;
    } else if (arg === '--filter' || arg === '-t') {
        options.filter = args[++i];
    } else if (arg === '--search' || arg === '-s') {
        options.search = args[++i];
    } else if (arg === '--date' || arg === '-d') {
        options.date = args[++i] || today;
    } else if (arg === '--help' || arg === '-h') {
        showHelp();
        process.exit(0);
    }
}

// Yardım mesajı
function showHelp() {
    console.log(`
${colors.bright}${colors.cyan}📝 LOG GÖRÜNTÜLEYİCİ${colors.reset}

${colors.bright}Kullanım:${colors.reset}
  node view-logs.js [seçenekler]

${colors.bright}Seçenekler:${colors.reset}
  -f, --file <tip>      Log dosyası tipi (application, error, exceptions, rejections)
                        Varsayılan: application
  
  -n, --lines <sayı>     Son kaç satır gösterilecek
                        Varsayılan: 50
  
  -F, --follow          Real-time izleme (tail -f benzeri)
                        Ctrl+C ile çıkış
  
  -t, --filter <tip>    Filtreleme (error, warn, info, http, 200, 404, 500, vb.)
  
  -s, --search <terim>  Arama terimi (mesaj içinde ara)
  
  -d, --date <tarih>    Tarih (YYYY-MM-DD formatında)
                        Varsayılan: Bugün

${colors.bright}Örnekler:${colors.reset}
  ${colors.green}node view-logs.js${colors.reset}                    # Son 50 satırı göster
  ${colors.green}node view-logs.js -n 100${colors.reset}             # Son 100 satırı göster
  ${colors.green}node view-logs.js -F${colors.reset}                 # Real-time izleme
  ${colors.green}node view-logs.js -f error${colors.reset}            # Sadece hata logları
  ${colors.green}node view-logs.js -t error${colors.reset}           # Error seviyesindeki loglar
  ${colors.green}node view-logs.js -t 404${colors.reset}             # 404 hataları
  ${colors.green}node view-logs.js -s "login"${colors.reset}         # "login" içeren loglar
  ${colors.green}node view-logs.js -d 2025-11-14${colors.reset}     # Belirli bir tarih
  ${colors.green}node view-logs.js -F -t error${colors.reset}        # Real-time hata izleme
`);
}

// Log dosyası yolunu oluştur
function getLogFilePath() {
    const fileName = `${options.file}-${options.date}.log`;
    return path.join(logsDir, fileName);
}

// Log seviyesine göre renk
function getLevelColor(level) {
    switch (level?.toLowerCase()) {
        case 'error': return colors.red;
        case 'warn': return colors.yellow;
        case 'info': return colors.green;
        case 'debug': return colors.blue;
        default: return colors.white;
    }
}

// Status code'a göre renk
function getStatusColor(status) {
    if (!status) return colors.reset;
    if (status >= 500) return colors.red;
    if (status >= 400) return colors.yellow;
    if (status >= 300) return colors.cyan;
    if (status >= 200) return colors.green;
    return colors.reset;
}

// Log satırını formatla ve göster
function formatAndDisplayLog(log, index) {
    try {
        const logObj = typeof log === 'string' ? JSON.parse(log) : log;
        
        // Filtreleme
        if (options.filter) {
            const filter = options.filter.toLowerCase();
            const level = logObj.level?.toLowerCase() || '';
            const status = logObj.status?.toString() || '';
            const message = logObj.message?.toLowerCase() || '';
            const type = logObj.type?.toLowerCase() || '';
            
            if (!level.includes(filter) && 
                !status.includes(filter) && 
                !message.includes(filter) &&
                !type.includes(filter)) {
                return false; // Bu log gösterilmeyecek
            }
        }
        
        // Arama
        if (options.search) {
            const searchTerm = options.search.toLowerCase();
            const logString = JSON.stringify(logObj).toLowerCase();
            if (!logString.includes(searchTerm)) {
                return false; // Bu log gösterilmeyecek
            }
        }
        
        // Format ve göster
        const timestamp = logObj.timestamp || logObj.time || '';
        const level = logObj.level || 'info';
        const message = logObj.message || '';
        
        // Renkli başlık
        const levelColor = getLevelColor(level);
        const levelDisplay = levelColor + level.toUpperCase().padEnd(6) + colors.reset;
        
        // Timestamp
        const timeDisplay = colors.gray + timestamp + colors.reset;
        
        // Mesaj
        let messageDisplay = message;
        
        // HTTP request logları için özel format
        if (logObj.type === 'http' || logObj.method) {
            const method = logObj.method || 'GET';
            const url = logObj.url || '';
            const status = logObj.status || logObj.statusCode || '';
            const duration = logObj.duration || logObj.responseTime || '';
            const ip = logObj.ip || logObj.remoteAddress || '';
            
            const statusColor = getStatusColor(status);
            const methodColor = method === 'GET' ? colors.blue : 
                               method === 'POST' ? colors.green :
                               method === 'PUT' ? colors.yellow :
                               method === 'DELETE' ? colors.red : colors.white;
            
            messageDisplay = `${methodColor}${method.padEnd(6)}${colors.reset} ` +
                           `${colors.cyan}${url}${colors.reset} ` +
                           `${statusColor}${status}${colors.reset} ` +
                           `${colors.gray}${duration}${colors.reset} ` +
                           `${colors.dim}${ip}${colors.reset}`;
        }
        
        // Çıktı
        console.log(`${timeDisplay} ${levelDisplay} ${messageDisplay}`);
        
        // Ekstra bilgiler (varsa)
        if (logObj.stack) {
            console.log(colors.red + '  Stack: ' + colors.reset + logObj.stack);
        }
        if (logObj.error) {
            console.log(colors.red + '  Error: ' + colors.reset + JSON.stringify(logObj.error, null, 2));
        }
        
        return true; // Log gösterildi
    } catch (e) {
        // JSON parse edilemeyen satırları atla veya ham göster
        if (log.trim()) {
            console.log(colors.gray + log.trim() + colors.reset);
        }
        return false;
    }
}

// Log dosyasını oku ve göster
function readAndDisplayLogs() {
    const filePath = getLogFilePath();
    
    if (!fs.existsSync(filePath)) {
        console.error(`${colors.red}❌ Log dosyası bulunamadı: ${filePath}${colors.reset}`);
        console.log(`${colors.yellow}💡 Farklı bir tarih deneyin: -d YYYY-MM-DD${colors.reset}`);
        process.exit(1);
    }
    
    console.log(`${colors.bright}${colors.cyan}📝 LOG GÖRÜNTÜLEYİCİ${colors.reset}`);
    console.log(`${colors.dim}Dosya: ${path.basename(filePath)}${colors.reset}`);
    console.log(`${colors.dim}Seçenekler: ${JSON.stringify(options, null, 2)}${colors.reset}\n`);
    
    if (options.follow) {
        // Real-time izleme
        console.log(`${colors.green}🔄 Real-time izleme başlatıldı... (Ctrl+C ile çıkış)${colors.reset}\n`);
        
        let lastPosition = fs.statSync(filePath).size;
        let displayedCount = 0;
        
        // Önce son N satırı göster
        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.split('\n').filter(l => l.trim());
        const lastLines = lines.slice(-options.lines);
        
        lastLines.forEach(line => {
            if (formatAndDisplayLog(line)) {
                displayedCount++;
            }
        });
        
        if (displayedCount === 0 && options.filter) {
            console.log(`${colors.yellow}⚠️  Filtreye uyan log bulunamadı.${colors.reset}`);
        }
        
        console.log(`\n${colors.green}⏳ Yeni loglar bekleniyor...${colors.reset}\n`);
        
        // Dosya değişikliklerini izle
        const watchInterval = setInterval(() => {
            try {
                const stats = fs.statSync(filePath);
                if (stats.size > lastPosition) {
                    const stream = fs.createReadStream(filePath, {
                        start: lastPosition,
                        end: stats.size
                    });
                    
                    const rl = readline.createInterface({
                        input: stream,
                        crlfDelay: Infinity
                    });
                    
                    rl.on('line', (line) => {
                        if (line.trim()) {
                            formatAndDisplayLog(line);
                        }
                    });
                    
                    lastPosition = stats.size;
                }
            } catch (error) {
                // Dosya silinmiş veya değişmiş olabilir
            }
        }, 1000); // Her saniye kontrol et
        
        // Ctrl+C ile çıkış
        process.on('SIGINT', () => {
            clearInterval(watchInterval);
            console.log(`\n${colors.yellow}👋 İzleme durduruldu.${colors.reset}`);
            process.exit(0);
        });
    } else {
        // Tek seferlik okuma
        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.split('\n').filter(l => l.trim());
        const lastLines = lines.slice(-options.lines);
        
        let displayedCount = 0;
        lastLines.forEach(line => {
            if (formatAndDisplayLog(line)) {
                displayedCount++;
            }
        });
        
        if (displayedCount === 0) {
            if (options.filter || options.search) {
                console.log(`${colors.yellow}⚠️  Filtreye uyan log bulunamadı.${colors.reset}`);
            } else {
                console.log(`${colors.yellow}⚠️  Log dosyası boş veya yeterli log yok.${colors.reset}`);
            }
        } else {
            console.log(`\n${colors.green}✅ Toplam ${displayedCount} log gösterildi.${colors.reset}`);
        }
    }
}

// Ana fonksiyon
readAndDisplayLogs();

