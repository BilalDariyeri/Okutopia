// scripts/uploadImageToSerbestCizim.js
// Resmi GridFS'e yükleyip "A Harfi Serbest Çizim" sorusuna ekler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');
const { GridFSBucket } = require('mongodb');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const MiniQuestion = require('../models/miniQuestion');

async function uploadImageToSerbestCizim(imagePath) {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        // Dosya var mı kontrol et
        if (!fs.existsSync(imagePath)) {
            console.log(`❌ Dosya bulunamadı: ${imagePath}`);
            console.log('\n💡 Kullanım: node scripts/uploadImageToSerbestCizim.js <dosya_yolu>');
            process.exit(1);
        }

        const db = mongoose.connection.db;
        const bucket = new GridFSBucket(db, { bucketName: 'uploads' });

        // Dosya bilgilerini al
        const fileStats = fs.statSync(imagePath);
        const fileName = path.basename(imagePath);
        const timestamp = Date.now();
        const gridfsFileName = `${timestamp}-${fileName}`;

        // MIME type belirle
        const ext = path.extname(imagePath).toLowerCase();
        const mimeTypes = {
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.webp': 'image/webp'
        };
        const contentType = mimeTypes[ext] || 'image/png';

        console.log(`\n📁 Dosya bilgileri:`);
        console.log(`   Adı: ${fileName}`);
        console.log(`   Boyut: ${(fileStats.size / 1024).toFixed(2)} KB`);
        console.log(`   Tip: ${contentType}`);

        // Metadata hazırla
        const metadata = {
            originalName: fileName,
            uploadedAt: new Date(),
            questionId: '694eca4bc476fea3f6481887',
            purpose: 'A Harfi Serbest Çizim'
        };

        // Dosyayı GridFS'e yükle
        console.log(`\n⬆️  Dosya GridFS'e yükleniyor...`);
        
        const uploadStream = bucket.openUploadStream(gridfsFileName, {
            contentType: contentType,
            metadata: metadata
        });

        const readStream = fs.createReadStream(imagePath);

        return new Promise((resolve, reject) => {
            readStream
                .pipe(uploadStream)
                .on('finish', async () => {
                    const fileId = uploadStream.id;
                    console.log(`✅ Dosya yüklendi! ID: ${fileId}`);

                    // "A Harfi Serbest Çizim" sorusunu bul ve resmi ekle
                    const question = await MiniQuestion.findById('694eca4bc476fea3f6481887');

                    if (!question) {
                        console.log('❌ Soru bulunamadı');
                        reject(new Error('Soru bulunamadı'));
                        return;
                    }

                    if (!question.data) {
                        question.data = {};
                    }

                    question.data.imageFileId = fileId;
                    await question.save();

                    console.log(`\n✅ Resim "A Harfi Serbest Çizim" sorusuna eklendi!`);
                    console.log(`\n📋 Güncellenmiş soru:`);
                    console.log(`   Question Text: ${question.data.questionText}`);
                    console.log(`   Image ID: ${fileId}`);

                    resolve(fileId);
                })
                .on('error', (error) => {
                    console.error('❌ Yükleme hatası:', error);
                    reject(error);
                });
        });
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

// Komut satırından dosya yolunu al
const imagePath = process.argv[2];

if (!imagePath) {
    console.log('❌ Dosya yolu belirtilmedi');
    console.log('\n💡 Kullanım: node scripts/uploadImageToSerbestCizim.js <dosya_yolu>');
    console.log('   Örnek: node scripts/uploadImageToSerbestCizim.js C:\\Users\\sengu\\Desktop\\a_harfi.png');
    process.exit(1);
}

uploadImageToSerbestCizim(imagePath)
    .then(() => {
        console.log('\n✅ İşlem tamamlandı!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('❌ Hata:', error);
        process.exit(1);
    });


