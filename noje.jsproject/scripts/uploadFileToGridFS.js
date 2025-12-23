// scripts/uploadFileToGridFS.js - MongoDB GridFS'e dosya yükleme scripti
// Kullanım: node scripts/uploadFileToGridFS.js "dosya-yolu" [metadata-json]

const { MongoClient, GridFSBucket } = require('mongodb');
const fs = require('fs');
const path = require('path');
require('dotenv').config(); // .env dosyasını yükle (proje root'undan)

/**
 * GridFS'e dosya yükleme fonksiyonu
 * @param {String} filePath - Yüklenecek dosyanın tam yolu
 * @param {Object} metadata - Opsiyonel metadata (questionId, activityId, etc.)
 * @returns {Promise<String>} - GridFS file ID
 */
async function uploadFileToGridFS(filePath, metadata = {}) {
    let client;
    
    try {
        // MongoDB bağlantı URI'sini al (.env'den veya varsayılan)
        const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017';
        
        // Veritabanı adını URI'den çıkar veya varsayılan kullan
        let dbName;
        if (mongoUri.includes('/')) {
            const uriParts = mongoUri.split('/');
            dbName = uriParts[uriParts.length - 1].split('?')[0]; // Query string'i temizle
        } else {
            dbName = 'education-tracker'; // Varsayılan veritabanı adı
        }
        
        console.log('🔄 MongoDB\'ye bağlanılıyor...');
        console.log('URI:', mongoUri);
        console.log('Veritabanı:', dbName);
        
        // MongoDB'ye bağlan
        client = new MongoClient(mongoUri);
        await client.connect();
        console.log('✅ MongoDB bağlantısı başarılı!');
        
        // Veritabanını seç
        const db = client.db(dbName);
        
        // GridFS bucket'ı oluştur (bucket adı: 'uploads' - sistemimizdeki gibi)
        const bucket = new GridFSBucket(db, { bucketName: 'uploads' });
        console.log('✅ GridFS bucket hazır: uploads');
        
        // Dosya yolunu kontrol et
        if (!fs.existsSync(filePath)) {
            throw new Error(`❌ Dosya bulunamadı: ${filePath}`);
        }
        
        // Dosya bilgilerini al
        const fileStats = fs.statSync(filePath);
        const fileName = path.basename(filePath);
        const fileExt = path.extname(filePath).toLowerCase();
        
        // MIME type belirle
        const mimeTypes = {
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.webp': 'image/webp',
            '.svg': 'image/svg+xml',
            '.mp4': 'video/mp4',
            '.webm': 'video/webm',
            '.ogg': 'video/ogg',
            '.mov': 'video/quicktime',
            '.avi': 'video/x-msvideo',
            '.mp3': 'audio/mpeg',
            '.wav': 'audio/wav',
            '.ogg': 'audio/ogg',
            '.m4a': 'audio/mp4'
        };
        
        const contentType = mimeTypes[fileExt] || 'application/octet-stream';
        
        console.log('📁 Dosya bilgileri:');
        console.log('   Adı:', fileName);
        console.log('   Boyut:', (fileStats.size / 1024 / 1024).toFixed(2), 'MB');
        console.log('   Tip:', contentType);
        
        // Metadata hazırla
        const fileMetadata = {
            originalName: fileName,
            uploadedAt: new Date(),
            ...metadata // Kullanıcıdan gelen metadata'yı ekle
        };
        
        // Dosyayı GridFS'e yükle
        console.log('⬆️  Dosya GridFS\'e yükleniyor...');
        
        const uploadStream = bucket.openUploadStream(fileName, {
            contentType: contentType,
            metadata: fileMetadata
        });
        
        // Dosya stream'ini oluştur ve yükle
        const readStream = fs.createReadStream(filePath);
        
        return new Promise((resolve, reject) => {
            readStream
                .pipe(uploadStream)
                .on('finish', () => {
                    const fileId = uploadStream.id.toString();
                    console.log('✅ Dosya başarıyla yüklendi!');
                    console.log('📋 File ID:', fileId);
                    console.log('🔗 URL:', `/api/files/${fileId}`);
                    console.log('💡 Bu File ID\'yi Mini Question\'ın mediaFileId alanına kaydedin!');
                    resolve(fileId);
                })
                .on('error', (error) => {
                    console.error('❌ Yükleme hatası:', error);
                    reject(error);
                });
        });
        
    } catch (error) {
        console.error('❌ Hata:', error.message);
        throw error;
    } finally {
        // Bağlantıyı kapat
        if (client) {
            await client.close();
            console.log('🔌 MongoDB bağlantısı kapatıldı.');
        }
    }
}

// ======================================================================
// SCRIPT ÇALIŞTIRMA
// ======================================================================

// Komut satırından argümanları al
const args = process.argv.slice(2);

if (args.length === 0) {
    console.log('📖 Kullanım:');
    console.log('   node scripts/uploadFileToGridFS.js "dosya-yolu"');
    console.log('');
    console.log('📖 Örnek:');
    console.log('   node scripts/uploadFileToGridFS.js "C:/resimler/ornek.jpg"');
    console.log('   node scripts/uploadFileToGridFS.js "./video.mp4"');
    console.log('');
    console.log('💡 Not: Dosya yolu tırnak içinde olmalı (boşluk varsa)');
    process.exit(1);
}

const filePath = args[0];

// Metadata varsa parse et (opsiyonel)
let metadata = {};
if (args[1]) {
    try {
        metadata = JSON.parse(args[1]);
    } catch (e) {
        console.warn('⚠️  Metadata JSON parse edilemedi, boş metadata kullanılıyor.');
    }
}

// Script'i çalıştır
uploadFileToGridFS(filePath, metadata)
    .then((fileId) => {
        console.log('');
        console.log('🎉 İşlem tamamlandı!');
        console.log('📋 File ID:', fileId);
        process.exit(0);
    })
    .catch((error) => {
        console.error('');
        console.error('💥 Script hatası:', error.message);
        process.exit(1);
    });

