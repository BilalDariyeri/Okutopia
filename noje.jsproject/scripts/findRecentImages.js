// scripts/findRecentImages.js
// Son yüklenen resim dosyalarını bulur

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const { GridFSBucket } = require('mongodb');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

async function findRecentImages() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        const db = mongoose.connection.db;
        const bucket = new GridFSBucket(db, { bucketName: 'uploads' });

        // Son 50 resim dosyasını bul (PNG, JPG, JPEG, WEBP)
        const files = await bucket.find({
            contentType: { $regex: /^image\// }
        })
        .sort({ uploadDate: -1 })
        .limit(50)
        .toArray();

        console.log(`\n📸 Son ${files.length} resim dosyası:\n`);
        
        files.forEach((file, index) => {
            const uploadDate = new Date(file.uploadDate).toLocaleString('tr-TR');
            console.log(`${index + 1}. ${file.filename || 'İsimsiz'}`);
            console.log(`   ID: ${file._id}`);
            console.log(`   Yükleme: ${uploadDate}`);
            console.log(`   Boyut: ${(file.length / 1024).toFixed(2)} KB`);
            console.log(`   Tip: ${file.contentType}`);
            if (file.metadata) {
                console.log(`   Metadata: ${JSON.stringify(file.metadata)}`);
            }
            console.log('');
        });

        // "A" veya "serbest" veya "çizim" içeren dosyaları özellikle göster
        const relevantFiles = files.filter(file => {
            const filename = (file.filename || '').toLowerCase();
            const metadata = file.metadata || {};
            const metadataStr = JSON.stringify(metadata).toLowerCase();
            const searchStr = (filename + ' ' + metadataStr).toLowerCase();
            
            return searchStr.includes('a') || 
                   searchStr.includes('serbest') || 
                   searchStr.includes('çizim') || 
                   searchStr.includes('cizim') ||
                   searchStr.includes('harf');
        });

        if (relevantFiles.length > 0) {
            console.log(`\n✅ İlgili dosyalar (${relevantFiles.length} adet):\n`);
            relevantFiles.forEach((file, index) => {
                console.log(`${index + 1}. ${file.filename || 'İsimsiz'} (ID: ${file._id})`);
            });
        }

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

findRecentImages();






