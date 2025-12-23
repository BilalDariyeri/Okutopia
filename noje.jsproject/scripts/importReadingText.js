// scripts/importReadingText.js - HTML Okuma Metinlerini Sisteme Yükleme

const fs = require('fs');
const path = require('path');
const axios = require('axios');
const cheerio = require('cheerio');
require('dotenv').config();

const API_BASE = process.env.API_BASE || 'http://localhost:3000/api';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@okutopia.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';

// HTML dosyasından okuma metnini parse et
function parseReadingText(htmlContent) {
    const $ = cheerio.load(htmlContent);
    
    // Başlığı al (h2.text-title veya .diktemel-title)
    const title = $('h2.text-title, h2.diktemel-title').text().trim() || 
                  $('.text-title').text().trim() ||
                  'Okuma Metni';
    
    // Metin satırlarını al (.centered-line içindeki metinler)
    const textLines = [];
    $('.centered-line').each((index, element) => {
        const line = $(element).text().trim();
        if (line) {
            textLines.push(line);
        }
    });
    
    // Eğer .centered-line yoksa, .diktemel-text içindeki tüm metinleri al
    if (textLines.length === 0) {
        $('.diktemel-text, .text-content').find('div').each((index, element) => {
            const line = $(element).text().trim();
            if (line && !line.includes('Önceki') && !line.includes('Sonraki')) {
                textLines.push(line);
            }
        });
    }
    
    return {
        title: title,
        textLines: textLines
    };
}

// Admin login yap ve token al
async function adminLogin() {
    try {
        const response = await axios.post(`${API_BASE}/admin/login`, {
            email: ADMIN_EMAIL,
            password: ADMIN_PASSWORD
        });
        
        if (response.data.success && response.data.token) {
            return response.data.token;
        } else {
            throw new Error('Login başarısız: ' + (response.data.message || 'Bilinmeyen hata'));
        }
    } catch (error) {
        console.error('Login hatası:', error.response?.data || error.message);
        throw error;
    }
}

// Activity oluştur
async function createReadingActivity(token, readingData, lessonId) {
    try {
        const activityData = {
            title: readingData.title,
            lesson: lessonId,
            type: 'Quiz', // Varsayılan tip
            activityType: 'Text', // Okuma metni
            durationMinutes: Math.ceil(readingData.textLines.length * 0.5), // Her satır için ~0.5 dakika
            textLines: readingData.textLines,
            readingDuration: readingData.textLines.length * 10, // Her satır için ~10 saniye
            mediaType: 'None',
            mediaStorage: 'None'
        };
        
        const response = await axios.post(
            `${API_BASE}/admin/activities`,
            activityData,
            {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            }
        );
        
        return response.data;
    } catch (error) {
        console.error('Activity oluşturma hatası:', error.response?.data || error.message);
        throw error;
    }
}

// Tek bir HTML dosyasını yükle
async function importSingleHTML(htmlFilePath, lessonId, token) {
    try {
        console.log(`\n📄 Dosya işleniyor: ${htmlFilePath}`);
        
        // HTML dosyasını oku
        const htmlContent = fs.readFileSync(htmlFilePath, 'utf-8');
        
        // Parse et
        const readingData = parseReadingText(htmlContent);
        
        if (readingData.textLines.length === 0) {
            console.warn('⚠️  Metin satırları bulunamadı!');
            return null;
        }
        
        console.log(`✅ Başlık: ${readingData.title}`);
        console.log(`✅ Satır sayısı: ${readingData.textLines.length}`);
        console.log(`📝 İlk satır: ${readingData.textLines[0]}`);
        
        // Activity oluştur
        const result = await createReadingActivity(token, readingData, lessonId);
        
        if (result.success) {
            console.log(`✅ Başarıyla yüklendi! Activity ID: ${result.data._id}`);
            return result.data;
        } else {
            console.error('❌ Yükleme başarısız:', result.message);
            return null;
        }
    } catch (error) {
        console.error(`❌ Hata: ${error.message}`);
        return null;
    }
}

// Ana fonksiyon
async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 2) {
        console.log(`
📚 Okuma Metni Yükleme Aracı

Kullanım:
  node scripts/importReadingText.js <HTML_DOSYA_YOLU> <DERS_ID>

Örnek:
  node scripts/importReadingText.js "C:/Users/dariy/OneDrive/Desktop/okutopia1 at/okutopia1/reading-text-7.html" "507f1f77bcf86cd799439011"

Çoklu dosya yükleme:
  node scripts/importReadingText.js <KLASÖR_YOLU> <DERS_ID> --batch

Not: DERS_ID'yi admin panelinden veya API'den alabilirsiniz.
        `);
        process.exit(1);
    }
    
    const inputPath = args[0];
    const lessonId = args[1];
    const isBatch = args.includes('--batch');
    
    // Login
    console.log('🔐 Admin girişi yapılıyor...');
    const token = await adminLogin();
    console.log('✅ Giriş başarılı!');
    
    // Dosya/klasör kontrolü
    const stats = fs.statSync(inputPath);
    
    if (stats.isFile()) {
        // Tek dosya
        await importSingleHTML(inputPath, lessonId, token);
    } else if (stats.isDirectory() && isBatch) {
        // Klasör içindeki tüm HTML dosyalarını yükle
        console.log(`\n📁 Klasör işleniyor: ${inputPath}`);
        const files = fs.readdirSync(inputPath)
            .filter(file => file.endsWith('.html') && file.includes('reading-text'));
        
        console.log(`📄 ${files.length} dosya bulundu.`);
        
        let successCount = 0;
        let failCount = 0;
        
        for (const file of files) {
            const filePath = path.join(inputPath, file);
            const result = await importSingleHTML(filePath, lessonId, token);
            
            if (result) {
                successCount++;
            } else {
                failCount++;
            }
            
            // Rate limiting için kısa bekleme
            await new Promise(resolve => setTimeout(resolve, 500));
        }
        
        console.log(`\n📊 Özet:`);
        console.log(`✅ Başarılı: ${successCount}`);
        console.log(`❌ Başarısız: ${failCount}`);
    } else {
        console.error('❌ Geçersiz dosya/klasör yolu veya --batch parametresi eksik!');
        process.exit(1);
    }
    
    console.log('\n✨ İşlem tamamlandı!');
}

// Script çalıştır
if (require.main === module) {
    main().catch(error => {
        console.error('💥 Kritik hata:', error);
        process.exit(1);
    });
}

module.exports = { parseReadingText, importSingleHTML };

