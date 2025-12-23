// analyze-logs.js - Log Dosyalarını Analiz Etme

const fs = require('fs');
const path = require('path');

const logsDir = path.join(__dirname, 'logs');
const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

console.log('📊 LOG ANALİZİ BAŞLIYOR...\n');
console.log(`📁 Log klasörü: ${logsDir}`);
console.log(`📅 Tarih: ${today}\n`);

// Log dosyalarını bul
const logFiles = {
    application: path.join(logsDir, `application-${today}.log`),
    error: path.join(logsDir, `error-${today}.log`),
    exceptions: path.join(logsDir, `exceptions-${today}.log`),
    rejections: path.join(logsDir, `rejections-${today}.log`)
};

// İstatistikler
const stats = {
    totalRequests: 0,
    rateLimited: 0,
    errors: 0,
    statusCodes: {},
    ipAddresses: {},
    endpoints: {},
    responseTimes: [],
    rateLimitLogs: []
};

// Log dosyasını oku ve analiz et
function analyzeLogFile(filePath, fileType) {
    if (!fs.existsSync(filePath)) {
        console.log(`⚠️  Dosya bulunamadı: ${filePath}`);
        return;
    }

    console.log(`📄 Analiz ediliyor: ${path.basename(filePath)}`);
    
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.split('\n').filter(line => line.trim());

        lines.forEach(line => {
            try {
                const log = JSON.parse(line);
                analyzeLogEntry(log, fileType);
            } catch (e) {
                // JSON parse edilemeyen satırları atla
            }
        });
    } catch (error) {
        console.error(`❌ Dosya okuma hatası: ${error.message}`);
    }
}

// Log entry'sini analiz et
function analyzeLogEntry(log, fileType) {
    // HTTP request logları
    if (log.type === 'http' || log.message?.includes('HTTP')) {
        stats.totalRequests++;
        
        // Status code analizi
        if (log.status) {
            stats.statusCodes[log.status] = (stats.statusCodes[log.status] || 0) + 1;
            
            if (log.status === 429) {
                stats.rateLimited++;
            }
            if (log.status >= 400) {
                stats.errors++;
            }
        }

        // IP adresi analizi
        if (log.ip || log.remoteAddress) {
            const ip = log.ip || log.remoteAddress;
            stats.ipAddresses[ip] = (stats.ipAddresses[ip] || 0) + 1;
        }

        // Endpoint analizi
        if (log.url) {
            const endpoint = log.url.split('?')[0]; // Query string'i kaldır
            stats.endpoints[endpoint] = (stats.endpoints[endpoint] || 0) + 1;
        }

        // Response time analizi
        if (log.duration) {
            const time = parseInt(log.duration.replace('ms', ''));
            if (!isNaN(time)) {
                stats.responseTimes.push(time);
            }
        }
    }

    // Rate limit logları
    if (log.message?.includes('Rate limit') || log.message?.includes('rate limit')) {
        stats.rateLimitLogs.push(log);
    }

    // Error logları
    if (fileType === 'error' && log.level === 'error') {
        stats.errors++;
    }
}

// Sonuçları göster
function showResults() {
    console.log('\n' + '='.repeat(60));
    console.log('📊 LOG ANALİZ SONUÇLARI');
    console.log('='.repeat(60));

    // Genel istatistikler
    console.log('\n📈 GENEL İSTATİSTİKLER:');
    console.log(`   Toplam İstek: ${stats.totalRequests}`);
    console.log(`   Rate Limited (429): ${stats.rateLimited}`);
    console.log(`   Hatalar: ${stats.errors}`);
    console.log(`   Başarılı: ${stats.totalRequests - stats.rateLimited - stats.errors}`);

    // Status code dağılımı
    if (Object.keys(stats.statusCodes).length > 0) {
        console.log('\n📊 STATUS CODE DAĞILIMI:');
        Object.entries(stats.statusCodes)
            .sort((a, b) => b[1] - a[1])
            .forEach(([code, count]) => {
                const percentage = ((count / stats.totalRequests) * 100).toFixed(2);
                console.log(`   ${code}: ${count} (${percentage}%)`);
            });
    }

    // IP adresi analizi
    if (Object.keys(stats.ipAddresses).length > 0) {
        console.log('\n🌐 EN ÇOK İSTEK GÖNDEREN IP ADRESLERİ:');
        Object.entries(stats.ipAddresses)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10)
            .forEach(([ip, count]) => {
                console.log(`   ${ip}: ${count} istek`);
            });
    }

    // Endpoint analizi
    if (Object.keys(stats.endpoints).length > 0) {
        console.log('\n🔗 EN ÇOK İSTENEN ENDPOINT\'LER:');
        Object.entries(stats.endpoints)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10)
            .forEach(([endpoint, count]) => {
                console.log(`   ${endpoint}: ${count} istek`);
            });
    }

    // Response time analizi
    if (stats.responseTimes.length > 0) {
        const avg = stats.responseTimes.reduce((a, b) => a + b, 0) / stats.responseTimes.length;
        const min = Math.min(...stats.responseTimes);
        const max = Math.max(...stats.responseTimes);
        
        console.log('\n⏱️  RESPONSE TIME İSTATİSTİKLERİ:');
        console.log(`   Ortalama: ${avg.toFixed(2)}ms`);
        console.log(`   Minimum: ${min}ms`);
        console.log(`   Maksimum: ${max}ms`);
    }

    // Rate limit analizi
    if (stats.rateLimitLogs.length > 0) {
        console.log('\n🚫 RATE LIMIT LOGLARI:');
        console.log(`   Toplam Rate Limit: ${stats.rateLimitLogs.length} kayıt`);
        
        // IP bazlı rate limit
        const ipRateLimits = {};
        stats.rateLimitLogs.forEach(log => {
            const ip = log.ip || log.remoteAddress || 'unknown';
            ipRateLimits[ip] = (ipRateLimits[ip] || 0) + 1;
        });

        if (Object.keys(ipRateLimits).length > 0) {
            console.log('\n   IP Bazlı Rate Limit:');
            Object.entries(ipRateLimits)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 10)
                .forEach(([ip, count]) => {
                    console.log(`   ${ip}: ${count} kez engellendi`);
                });
        }
    }

    // Güvenlik değerlendirmesi
    console.log('\n' + '='.repeat(60));
    console.log('🔒 GÜVENLİK DEĞERLENDİRMESİ:');
    console.log('='.repeat(60));

    const blockRate = stats.totalRequests > 0 
        ? (stats.rateLimited / stats.totalRequests) * 100 
        : 0;

    if (blockRate >= 80) {
        console.log('✅ MÜKEMMEL: Rate limiting çok etkili!');
        console.log(`   %${blockRate.toFixed(2)} saldırı isteği engellendi.`);
    } else if (blockRate >= 50) {
        console.log('⚠️  İYİ: Rate limiting çalışıyor.');
        console.log(`   %${blockRate.toFixed(2)} saldırı isteği engellendi.`);
    } else if (blockRate > 0) {
        console.log('⚠️  ORTA: Rate limiting kısmen çalışıyor.');
        console.log(`   %${blockRate.toFixed(2)} saldırı isteği engellendi.`);
        console.log('   💡 Rate limit ayarlarını gözden geçirin.');
    } else {
        console.log('❌ SORUN: Rate limiting çalışmıyor gibi görünüyor!');
        console.log('   💡 Rate limit middleware\'ini kontrol edin.');
    }

    // Performans değerlendirmesi
    if (stats.responseTimes.length > 0) {
        const avg = stats.responseTimes.reduce((a, b) => a + b, 0) / stats.responseTimes.length;
        console.log('\n⚡ PERFORMANS DEĞERLENDİRMESİ:');
        
        if (avg < 100) {
            console.log('✅ MÜKEMMEL: Çok hızlı response time!');
        } else if (avg < 500) {
            console.log('✅ İYİ: İyi response time.');
        } else {
            console.log('⚠️  ORTA: Response time biraz yavaş.');
            console.log('   💡 Performans optimizasyonu gerekebilir.');
        }
    }

    console.log('='.repeat(60));
}

// Ana fonksiyon
function main() {
    // Tüm log dosyalarını analiz et
    Object.entries(logFiles).forEach(([type, filePath]) => {
        analyzeLogFile(filePath, type);
    });

    // Sonuçları göster
    showResults();
}

// Çalıştır
main();

