// Test script - Önce test dersi oluştur, sonra HTML'i yükle
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const cheerio = require('cheerio');
require('dotenv').config();

const API_BASE = process.env.API_BASE || 'http://localhost:3000/api';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;
const HTML_PATH = 'C:/Users/dariy/OneDrive/Desktop/okutopia1 at/okutopia1/reading-text-7.html';

async function adminLogin() {
    const response = await axios.post(`${API_BASE}/admin/login`, {
        email: ADMIN_EMAIL,
        password: ADMIN_PASSWORD
    });
    if (response.data.success) return response.data.token;
    throw new Error('Login başarısız');
}

function parseReadingText(htmlContent) {
    const $ = cheerio.load(htmlContent);
    const title = $('h2.text-title, h2.diktemel-title').text().trim() || 'Okuma Metni';
    const textLines = [];
    $('.centered-line').each((index, element) => {
        const line = $(element).text().trim();
        if (line) textLines.push(line);
    });
    return { title, textLines };
}

async function main() {
    try {
        if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
            console.error('❌ Admin bilgileri bulunamadı!');
            console.log('\n💡 Çözüm:');
            console.log('1. .env dosyasına ekleyin:');
            console.log('   ADMIN_EMAIL=your-email@example.com');
            console.log('   ADMIN_PASSWORD=your-password');
            console.log('\n2. Veya script parametresi olarak verin:');
            console.log('   ADMIN_EMAIL=email ADMIN_PASSWORD=pass node scripts/createTestLessonAndImport.js');
            process.exit(1);
        }
        
        console.log(`🔐 Admin girişi yapılıyor (${ADMIN_EMAIL})...`);
        const token = await adminLogin();
        console.log('✅ Giriş başarılı!\n');

        // 1. Kategorileri kontrol et
        console.log('📂 Kategoriler kontrol ediliyor...');
        const categoriesRes = await axios.get(`${API_BASE}/admin/categories`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        
        let categoryId;
        if (categoriesRes.data.success && categoriesRes.data.data.length > 0) {
            categoryId = categoriesRes.data.data[0]._id;
            console.log(`✅ Kategori bulundu: ${categoriesRes.data.data[0].name} (${categoryId})\n`);
        } else {
            // Kategori oluştur
            console.log('📝 Test kategorisi oluşturuluyor...');
            const catRes = await axios.post(`${API_BASE}/admin/content/category`, {
                name: 'Test Kategori',
                flowType: 'Default'
            }, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            categoryId = catRes.data.data._id;
            console.log(`✅ Kategori oluşturuldu: ${categoryId}\n`);
        }

        // 2. Grup oluştur
        console.log('📝 Test grubu oluşturuluyor...');
        const groupRes = await axios.post(`${API_BASE}/admin/content/group`, {
            name: 'Test Grup',
            category: categoryId,
            orderIndex: 0
        }, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const groupId = groupRes.data.data._id;
        console.log(`✅ Grup oluşturuldu: ${groupId}\n`);

        // 3. Ders oluştur
        console.log('📝 Test dersi oluşturuluyor...');
        const lessonRes = await axios.post(`${API_BASE}/admin/content/lesson`, {
            title: 'Test Ders - Okuma Metinleri',
            group: groupId,
            targetContent: 'Okuma metinleri için test dersi',
            orderIndex: 0
        }, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const lessonId = lessonRes.data.data._id;
        console.log(`✅ Ders oluşturuldu: ${lessonId}\n`);

        // 4. HTML dosyasını parse et
        console.log('📄 HTML dosyası parse ediliyor...');
        const htmlContent = fs.readFileSync(HTML_PATH, 'utf-8');
        const readingData = parseReadingText(htmlContent);
        console.log(`✅ Başlık: ${readingData.title}`);
        console.log(`✅ Satır sayısı: ${readingData.textLines.length}\n`);

        // 5. Activity oluştur
        console.log('💾 Activity veritabanına kaydediliyor...');
        const activityData = {
            title: readingData.title,
            lesson: lessonId,
            type: 'Quiz',
            activityType: 'Text',
            durationMinutes: Math.ceil(readingData.textLines.length * 0.5),
            textLines: readingData.textLines,
            readingDuration: readingData.textLines.length * 10,
            mediaType: 'None',
            mediaStorage: 'None'
        };

        const activityRes = await axios.post(
            `${API_BASE}/admin/activities`,
            activityData,
            {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        if (activityRes.data.success) {
            console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            console.log('✅ BAŞARILI! Activity veritabanına kaydedildi!');
            console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            console.log(`📌 Activity ID: ${activityRes.data.data._id}`);
            console.log(`📌 Başlık: ${activityRes.data.data.title}`);
            console.log(`📌 Activity Type: ${activityRes.data.data.activityType}`);
            console.log(`📌 Text Lines: ${activityRes.data.data.textLines.length} satır`);
            console.log(`📌 Reading Duration: ${activityRes.data.data.readingDuration} saniye`);
            console.log('\n📊 Kaydedilen Veri:');
            console.log(JSON.stringify({
                title: activityRes.data.data.title,
                textLines: activityRes.data.data.textLines,
                readingDuration: activityRes.data.data.readingDuration
            }, null, 2));
        } else {
            console.error('❌ Hata:', activityRes.data.message);
        }

    } catch (error) {
        console.error('❌ Hata:', error.response?.data || error.message);
        if (error.response?.data) {
            console.error('Detay:', JSON.stringify(error.response.data, null, 2));
        }
        process.exit(1);
    }
}

main();


