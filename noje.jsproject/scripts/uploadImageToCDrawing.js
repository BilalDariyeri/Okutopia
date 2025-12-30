// scripts/uploadImageToCDrawing.js
// Resmi GridFS'e yükleyip "C harfi serbest çizim" sorusuna ekler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');
const { GridFSBucket } = require('mongodb');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const MiniQuestion = require('../models/miniQuestion');

async function uploadImageToCDrawing(imagePath) {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        // Dosya var mı kontrol et
        if (!fs.existsSync(imagePath)) {
            console.log(`❌ Dosya bulunamadı: ${imagePath}`);
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
        const contentType = mimeTypes[ext] || 'image/jpeg';

        console.log(`\n📁 Dosya bilgileri:`);
        console.log(`   Adı: ${fileName}`);
        console.log(`   Boyut: ${(fileStats.size / 1024).toFixed(2)} KB`);
        console.log(`   Tip: ${contentType}`);

        // Metadata hazırla
        const metadata = {
            originalName: fileName,
            uploadedAt: new Date(),
            purpose: 'C harfi serbest çizim'
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

                    // "C harfi serbest çizim" sorusunu bul
                    const question = await MiniQuestion.findOne({
                        $or: [
                            { 'data.questionText': { $regex: /C harfi serbest çizim/i } },
                            { 'data.questionText': { $regex: /C harfı serbest çizim/i } },
                            { title: { $regex: /C harfi serbest çizim/i } }
                        ]
                    });

                    if (!question) {
                        console.log('\n❌ "C harfi serbest çizim" sorusu bulunamadı');
                        console.log('💡 Tüm soruları kontrol ediliyor...\n');
                        
                        // Tüm soruları listele
                        const allQuestions = await MiniQuestion.find({
                            'data.questionText': { $regex: /C.*serbest/i }
                        }).limit(10).lean();
                        
                        if (allQuestions.length > 0) {
                            console.log(`📋 C serbest içeren sorular (${allQuestions.length} adet):\n`);
                            allQuestions.forEach((q, index) => {
                                console.log(`${index + 1}. ${q.data?.questionText || q.title || 'Başlıksız'} (ID: ${q._id})`);
                            });
                        } else {
                            console.log('❌ C serbest içeren soru bulunamadı');
                        }
                        
                        reject(new Error('Soru bulunamadı'));
                        return;
                    }

                    console.log(`\n✅ Soru bulundu: "${question.data?.questionText || question.title}"`);
                    console.log(`   ID: ${question._id}`);

                    // Data objesi yoksa oluştur
                    if (!question.data) {
                        question.data = {};
                    }

                    // Resmi ekle
                    question.data.imageFileId = fileId;
                    
                    // Mark as modified
                    question.markModified('data');

                    // Kaydet
                    await question.save();

                    // Tekrar kontrol et
                    const updatedQuestion = await MiniQuestion.findById(question._id).lean();

                    console.log(`\n✅ Resim "C harfi serbest çizim" sorusuna eklendi!`);
                    console.log(`\n📋 Güncellenmiş soru detayları:`);
                    console.log(`   Question Text: ${updatedQuestion.data?.questionText || 'N/A'}`);
                    console.log(`   Image ID: ${updatedQuestion.data?.imageFileId || 'Yok'}`);

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
const imagePath = process.argv[2] || 'C:\\Users\\sengu\\OneDrive\\Desktop\\C-harfi.jpeg';

uploadImageToCDrawing(imagePath)
    .then(() => {
        console.log('\n✅ İşlem tamamlandı!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('❌ Hata:', error);
        process.exit(1);
    });






