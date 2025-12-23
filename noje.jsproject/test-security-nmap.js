// test-security-nmap.js - Nmap Güvenlik Taraması ve Port Analizi

const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

const API_URL = process.env.API_URL || 'http://localhost:3000';
const API_PORT = new URL(API_URL).port || 3000;

console.log('🔍 GÜVENLİK TARAMASI BAŞLIYOR...\n');
console.log(`📡 Hedef: ${API_URL}`);
console.log(`🔌 Port: ${API_PORT}\n`);

// Nmap komutları
const nmapCommands = {
    // Temel port taraması
    basicScan: `nmap -p ${API_PORT} localhost`,
    
    // Detaylı port taraması
    detailedScan: `nmap -p ${API_PORT} -sV -sC localhost`,
    
    // Güvenlik açığı taraması
    vulnScan: `nmap -p ${API_PORT} --script vuln localhost`,
    
    // HTTP güvenlik taraması
    httpScan: `nmap -p ${API_PORT} --script http-enum,http-headers,http-methods,http-security-headers localhost`,
    
    // Tüm portları tarama (1-1000)
    fullScan: `nmap -p 1-1000 localhost`
};

// Nmap yüklü mü kontrol et
async function checkNmap() {
    // Önce PATH'te kontrol et
    try {
        const { stdout } = await execPromise('nmap --version');
        console.log('✅ Nmap yüklü (PATH\'te):\n' + stdout.split('\n')[0] + '\n');
        return true;
    } catch (error) {
        // PATH'te yoksa standart konumları kontrol et
        const possiblePaths = [
            'C:\\Program Files (x86)\\Nmap\\nmap.exe',
            'C:\\Program Files\\Nmap\\nmap.exe',
            process.env.PROGRAMFILES + '\\Nmap\\nmap.exe',
            process.env['PROGRAMFILES(X86)'] + '\\Nmap\\nmap.exe'
        ];
        
        for (const nmapPath of possiblePaths) {
            try {
                const fs = require('fs');
                if (fs.existsSync(nmapPath)) {
                    const { stdout } = await execPromise(`"${nmapPath}" --version`);
                    console.log('✅ Nmap yüklü (standart konumda):\n' + stdout.split('\n')[0] + '\n');
                    console.log('⚠️  Nmap PATH\'te değil, tam yol kullanılacak.');
                    console.log(`   Konum: ${nmapPath}\n`);
                    // Nmap path'ini global olarak sakla
                    global.nmapPath = nmapPath;
                    return true;
                }
            } catch (e) {
                // Bu path'te yok, devam et
            }
        }
        
        console.error('❌ Nmap yüklü değil veya bulunamadı!');
        console.error('\n💡 Nmap Kurulumu:');
        console.error('   Windows: https://nmap.org/download.html');
        console.error('   veya: choco install nmap');
        console.error('   veya: winget install nmap');
        console.error('\n💡 PATH Sorunu:');
        console.error('   Nmap kurulu ama PATH\'te değilse:');
        console.error('   1. PowerShell\'i yeniden başlatın');
        console.error('   2. Veya Nmap\'i PATH\'e ekleyin\n');
        return false;
    }
}

// Nmap taraması yap
async function runNmapScan(name, command) {
    console.log(`\n${'='.repeat(60)}`);
    console.log(`🔍 ${name}`);
    console.log('='.repeat(60));
    
    // Eğer Nmap PATH'te değilse, tam yol kullan
    let finalCommand = command;
    if (global.nmapPath) {
        finalCommand = command.replace(/^nmap /, `"${global.nmapPath}" `);
        console.log(`Komut: ${finalCommand}\n`);
    } else {
        console.log(`Komut: ${command}\n`);
    }
    
    try {
        const { stdout, stderr } = await execPromise(finalCommand, {
            timeout: 60000, // 60 saniye timeout
            maxBuffer: 1024 * 1024 * 10 // 10MB buffer
        });
        
        if (stdout) {
            console.log(stdout);
        }
        
        if (stderr) {
            console.warn('⚠️  Uyarı:', stderr);
        }
        
        return { success: true, output: stdout };
    } catch (error) {
        console.error(`❌ Hata: ${error.message}`);
        if (error.stdout) {
            console.log('Çıktı:', error.stdout);
        }
        return { success: false, error: error.message };
    }
}

// API güvenlik testleri (Nmap olmadan)
async function runAPISecurityTests() {
    console.log(`\n${'='.repeat(60)}`);
    console.log('🔒 API GÜVENLİK TESTLERİ (Nmap Olmadan)');
    console.log('='.repeat(60));
    
    const tests = [
        {
            name: 'CORS Kontrolü',
            test: async () => {
                try {
                    const response = await fetch(API_URL + '/api/health', {
                        method: 'OPTIONS',
                        headers: {
                            'Origin': 'https://evil.com',
                            'Access-Control-Request-Method': 'GET'
                        }
                    });
                    const corsHeader = response.headers.get('Access-Control-Allow-Origin');
                    return {
                        passed: corsHeader !== '*',
                        message: corsHeader === '*' 
                            ? '⚠️  CORS tüm origin\'lere açık (*)' 
                            : `✅ CORS kontrolü var: ${corsHeader || 'Yok'}`
                    };
                } catch (error) {
                    return { passed: false, message: `❌ Hata: ${error.message}` };
                }
            }
        },
        {
            name: 'Security Headers Kontrolü',
            test: async () => {
                try {
                    const response = await fetch(API_URL + '/api/health');
                    const headers = {
                        'X-Content-Type-Options': response.headers.get('X-Content-Type-Options'),
                        'X-Frame-Options': response.headers.get('X-Frame-Options'),
                        'X-XSS-Protection': response.headers.get('X-XSS-Protection'),
                        'Strict-Transport-Security': response.headers.get('Strict-Transport-Security'),
                        'Content-Security-Policy': response.headers.get('Content-Security-Policy')
                    };
                    
                    const missing = Object.entries(headers)
                        .filter(([key, value]) => !value)
                        .map(([key]) => key);
                    
                    return {
                        passed: missing.length === 0,
                        message: missing.length === 0
                            ? '✅ Tüm güvenlik header\'ları mevcut'
                            : `⚠️  Eksik header'lar: ${missing.join(', ')}`
                    };
                } catch (error) {
                    return { passed: false, message: `❌ Hata: ${error.message}` };
                }
            }
        },
        {
            name: 'Rate Limiting Kontrolü',
            test: async () => {
                try {
                    // 101 istek gönder (rate limit: 100/15dk)
                    const requests = Array(101).fill(null).map(() => 
                        fetch(API_URL + '/api/health')
                    );
                    const responses = await Promise.all(requests);
                    const rateLimited = responses.filter(r => r.status === 429).length;
                    
                    return {
                        passed: rateLimited > 0,
                        message: rateLimited > 0
                            ? `✅ Rate limiting çalışıyor (${rateLimited} istek engellendi)`
                            : '❌ Rate limiting çalışmıyor!'
                    };
                } catch (error) {
                    return { passed: false, message: `❌ Hata: ${error.message}` };
                }
            }
        },
        {
            name: 'SQL Injection Testi',
            test: async () => {
                try {
                    const maliciousInputs = [
                        "' OR '1'='1",
                        "'; DROP TABLE users--",
                        "1' UNION SELECT * FROM users--"
                    ];
                    
                    let vulnerable = false;
                    for (const input of maliciousInputs) {
                        try {
                            const response = await fetch(API_URL + `/api/users/login`, {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ email: input, password: input })
                            });
                            // Eğer 500 hatası alırsak, SQL injection açığı olabilir
                            if (response.status === 500) {
                                vulnerable = true;
                                break;
                            }
                        } catch (e) {
                            // Hata beklenen
                        }
                    }
                    
                    return {
                        passed: !vulnerable,
                        message: vulnerable
                            ? '⚠️  SQL Injection açığı tespit edildi!'
                            : '✅ SQL Injection koruması var'
                    };
                } catch (error) {
                    return { passed: false, message: `❌ Hata: ${error.message}` };
                }
            }
        },
        {
            name: 'XSS (Cross-Site Scripting) Testi',
            test: async () => {
                try {
                    const xssPayloads = [
                        '<script>alert("XSS")</script>',
                        '"><script>alert("XSS")</script>',
                        'javascript:alert("XSS")'
                    ];
                    
                    let vulnerable = false;
                    for (const payload of xssPayloads) {
                        try {
                            const response = await fetch(API_URL + `/api/users/register/teacher`, {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ 
                                    firstName: payload, 
                                    lastName: payload,
                                    email: 'test@test.com',
                                    password: 'Test123!'
                                })
                            });
                            const data = await response.text();
                            // Eğer payload response'ta dönüyorsa, XSS açığı var
                            if (data.includes(payload) && !data.includes('&lt;script&gt;')) {
                                vulnerable = true;
                                break;
                            }
                        } catch (e) {
                            // Hata beklenen
                        }
                    }
                    
                    return {
                        passed: !vulnerable,
                        message: vulnerable
                            ? '⚠️  XSS açığı tespit edildi!'
                            : '✅ XSS koruması var'
                    };
                } catch (error) {
                    return { passed: false, message: `❌ Hata: ${error.message}` };
                }
            }
        }
    ];
    
    const results = [];
    for (const test of tests) {
        console.log(`\n🧪 ${test.name}...`);
        const result = await test.test();
        results.push({ name: test.name, ...result });
        console.log(`   ${result.message}`);
    }
    
    // Özet
    console.log(`\n${'='.repeat(60)}`);
    console.log('📊 GÜVENLİK TEST SONUÇLARI');
    console.log('='.repeat(60));
    const passed = results.filter(r => r.passed).length;
    const total = results.length;
    console.log(`✅ Başarılı: ${passed}/${total}`);
    console.log(`❌ Başarısız: ${total - passed}/${total}`);
    
    results.forEach(result => {
        const icon = result.passed ? '✅' : '❌';
        console.log(`${icon} ${result.name}: ${result.message}`);
    });
    
    return results;
}

// Ana fonksiyon
async function main() {
    // Nmap kontrolü
    const nmapInstalled = await checkNmap();
    
    if (nmapInstalled) {
        // Nmap taramaları
        console.log('🚀 Nmap taramaları başlatılıyor...\n');
        
        await runNmapScan('Temel Port Taraması', nmapCommands.basicScan);
        await runNmapScan('Detaylı Port Taraması', nmapCommands.detailedScan);
        await runNmapScan('HTTP Güvenlik Taraması', nmapCommands.httpScan);
        
        // Güvenlik açığı taraması (uzun sürebilir)
        console.log('\n⚠️  Güvenlik açığı taraması uzun sürebilir...');
        await runNmapScan('Güvenlik Açığı Taraması', nmapCommands.vulnScan);
    } else {
        console.log('⚠️  Nmap olmadan devam ediliyor...\n');
    }
    
    // API güvenlik testleri (Nmap olmadan da çalışır)
    await runAPISecurityTests();
    
    console.log('\n✅ Güvenlik taraması tamamlandı!\n');
}

// Çalıştır
main().catch(error => {
    console.error('❌ Kritik hata:', error);
    process.exit(1);
});

