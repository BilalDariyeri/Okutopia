// test-ddos-attack.js - DDoS Saldırısı Simülasyonu ve Güvenlik Testi

require('dotenv').config();

const API_URL = process.env.API_URL || 'http://localhost:3000';
const ATTACK_DURATION = 30; // 30 saniye saldırı
const REQUESTS_PER_SECOND = 50; // Saniyede 50 istek (rate limit: 100/15dk = ~0.11 req/saniye normal, 50 req/saniye saldırı)

console.log('🔥 DDoS SALDIRISI SİMÜLASYONU BAŞLIYOR...\n');
console.log(`📡 Hedef: ${API_URL}`);
console.log(`⏱️  Süre: ${ATTACK_DURATION} saniye`);
console.log(`⚡ İstek Hızı: ${REQUESTS_PER_SECOND} istek/saniye`);
console.log(`📊 Toplam İstek: ~${ATTACK_DURATION * REQUESTS_PER_SECOND} istek\n`);

let totalRequests = 0;
let successfulRequests = 0;
let rateLimitedRequests = 0;
let errorRequests = 0;
let responseTimes = [];

// İstek gönderme fonksiyonu
async function sendRequest(endpoint = '/api/health') {
    const startTime = Date.now();
    totalRequests++;

    try {
        const response = await fetch(`${API_URL}${endpoint}`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'DDoS-Test-Bot/1.0'
            }
        });

        const responseTime = Date.now() - startTime;
        responseTimes.push(responseTime);

        if (response.status === 429) {
            rateLimitedRequests++;
            return { status: 429, time: responseTime, blocked: true };
        } else if (response.status >= 200 && response.status < 300) {
            successfulRequests++;
            return { status: response.status, time: responseTime, blocked: false };
        } else {
            errorRequests++;
            return { status: response.status, time: responseTime, blocked: false };
        }
    } catch (error) {
        errorRequests++;
        const responseTime = Date.now() - startTime;
        responseTimes.push(responseTime);
        return { status: 'ERROR', time: responseTime, error: error.message, blocked: false };
    }
}

// Paralel istek gönderme
async function sendBatch(batchSize = REQUESTS_PER_SECOND) {
    const promises = [];
    for (let i = 0; i < batchSize; i++) {
        promises.push(sendRequest('/api/health'));
    }
    return Promise.all(promises);
}

// İstatistikleri göster
function showStats() {
    const avgResponseTime = responseTimes.length > 0 
        ? (responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length).toFixed(2)
        : 0;
    const minResponseTime = responseTimes.length > 0 ? Math.min(...responseTimes) : 0;
    const maxResponseTime = responseTimes.length > 0 ? Math.max(...responseTimes) : 0;

    console.log('\n' + '='.repeat(60));
    console.log('📊 SALDIRI İSTATİSTİKLERİ');
    console.log('='.repeat(60));
    console.log(`📤 Toplam İstek: ${totalRequests}`);
    console.log(`✅ Başarılı: ${successfulRequests} (${((successfulRequests/totalRequests)*100).toFixed(2)}%)`);
    console.log(`🚫 Rate Limited (429): ${rateLimitedRequests} (${((rateLimitedRequests/totalRequests)*100).toFixed(2)}%)`);
    console.log(`❌ Hata: ${errorRequests} (${((errorRequests/totalRequests)*100).toFixed(2)}%)`);
    console.log(`\n⏱️  Response Time:`);
    console.log(`   Ortalama: ${avgResponseTime}ms`);
    console.log(`   Minimum: ${minResponseTime}ms`);
    console.log(`   Maksimum: ${maxResponseTime}ms`);
    console.log('='.repeat(60));

    // Güvenlik değerlendirmesi
    console.log('\n🔒 GÜVENLİK DEĞERLENDİRMESİ:');
    const blockRate = (rateLimitedRequests / totalRequests) * 100;
    
    if (blockRate >= 80) {
        console.log('✅ MÜKEMMEL: Rate limiting çok iyi çalışıyor!');
        console.log(`   %${blockRate.toFixed(2)} saldırı isteği engellendi.`);
    } else if (blockRate >= 50) {
        console.log('⚠️  İYİ: Rate limiting çalışıyor ama iyileştirilebilir.');
        console.log(`   %${blockRate.toFixed(2)} saldırı isteği engellendi.`);
    } else {
        console.log('❌ ZAYIF: Rate limiting yeterince etkili değil!');
        console.log(`   Sadece %${blockRate.toFixed(2)} saldırı isteği engellendi.`);
        console.log('   💡 Rate limit ayarlarını gözden geçirin.');
    }

    // Performans değerlendirmesi
    console.log('\n⚡ PERFORMANS DEĞERLENDİRMESİ:');
    if (avgResponseTime < 100) {
        console.log('✅ MÜKEMMEL: Çok hızlı response time!');
    } else if (avgResponseTime < 500) {
        console.log('✅ İYİ: İyi response time.');
    } else if (avgResponseTime < 1000) {
        console.log('⚠️  ORTA: Response time biraz yavaş.');
    } else {
        console.log('❌ YAVAŞ: Response time çok yavaş!');
        console.log('   💡 Performans optimizasyonu gerekebilir.');
    }
}

// Ana saldırı fonksiyonu
async function startAttack() {
    console.log('🚀 Saldırı başlatılıyor...\n');
    
    const startTime = Date.now();
    const endTime = startTime + (ATTACK_DURATION * 1000);
    
    let second = 0;
    const interval = setInterval(async () => {
        if (Date.now() >= endTime) {
            clearInterval(interval);
            console.log('\n✅ Saldırı tamamlandı!');
            showStats();
            console.log('\n💡 Şimdi log dosyalarını kontrol edin:');
            console.log('   - logs/application-*.log');
            console.log('   - logs/error-*.log');
            console.log('\n📝 Log analizi için: node analyze-logs.js');
            process.exit(0);
        }

        second++;
        console.log(`⏱️  ${second}. saniye - ${REQUESTS_PER_SECOND} istek gönderiliyor...`);
        
        try {
            await sendBatch(REQUESTS_PER_SECOND);
        } catch (error) {
            console.error(`❌ Hata: ${error.message}`);
        }
    }, 1000);
}

// Başlat
startAttack().catch(error => {
    console.error('❌ Saldırı sırasında hata:', error);
    process.exit(1);
});

