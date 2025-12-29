// scripts/findImageForSerbestCizim.js
// "A Harfi Serbest Çizim" için GridFS'de resim dosyası arar

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const { GridFSBucket } = require('mongodb');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

async function findImageForSerbestCizim() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        const db = mongoose.connection.db;
        const bucket = new GridFSBucket(db, { bucketName: 'uploads' });

        // GridFS'de "serbest" veya "çizim" veya "a harfi" içeren dosyaları ara
        const searchTerms = ['serbest', 'çizim', 'cizim', 'a harfi', 'a harf', 'serbest çizim'];
        
        console.log('\n🔍 GridFS\'de dosya aranıyor...\n');
        
        const files = await bucket.find({}).toArray();
        
        console.log(`📊 Toplam ${files.length} dosya bulundu\n`);
        
        // İlgili dosyaları filtrele
        const relevantFiles = files.filter(file => {
            const filename = (file.filename || '').toLowerCase();
            const metadata = file.metadata || {};
            const metadataStr = JSON.stringify(metadata).toLowerCase();
            const searchStr = (filename + ' ' + metadataStr).toLowerCase();
            
            return searchTerms.some(term => searchStr.includes(term));
        });

        if (relevantFiles.length > 0) {
            console.log(`✅ ${relevantFiles.length} ilgili dosya bulundu:\n`);
            relevantFiles.forEach((file, index) => {
                console.log(`${index + 1}. ${file.filename || 'İsimsiz'}`);
                console.log(`   ID: ${file._id}`);
                console.log(`   Upload Date: ${file.uploadDate}`);
                console.log(`   Size: ${(file.length / 1024).toFixed(2)} KB`);
                console.log(`   Content Type: ${file.contentType || 'N/A'}`);
                if (file.metadata) {
                    console.log(`   Metadata: ${JSON.stringify(file.metadata)}`);
                }
                console.log('');
            });
        } else {
            console.log('❌ İlgili dosya bulunamadı');
            console.log('\n📋 Son 20 yüklenen dosya:\n');
            const recentFiles = files
                .sort((a, b) => new Date(b.uploadDate) - new Date(a.uploadDate))
                .slice(0, 20);
            
            recentFiles.forEach((file, index) => {
                console.log(`${index + 1}. ${file.filename || 'İsimsiz'} (ID: ${file._id})`);
            });
        }

        // Ayrıca tüm sorulardaki imageFileId'leri kontrol et
        const MiniQuestion = require('../models/miniQuestion');
        const allQuestions = await MiniQuestion.find({
            'data.imageFileId': { $exists: true, $ne: null }
        }).lean();

        console.log(`\n📸 Sorularda kullanılan imageFileId'ler (${allQuestions.length} adet):\n`);
        allQuestions.forEach((q, index) => {
            const imageId = q.data?.imageFileId || q.mediaFileId;
            if (imageId) {
                console.log(`${index + 1}. ${q.data?.questionText || q.title || 'Başlıksız'}`);
                console.log(`   Image ID: ${imageId}`);
                console.log('');
            }
        });

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

findImageForSerbestCizim();


