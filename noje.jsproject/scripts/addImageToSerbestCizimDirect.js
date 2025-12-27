// scripts/addImageToSerbestCizimDirect.js
// "A Harfi Serbest Çizim" sorusuna resmi doğrudan ekler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const MiniQuestion = require('../models/miniQuestion');

async function addImageToSerbestCizim() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        // "A Harfi Serbest Çizim" sorusunu bul
        const question = await MiniQuestion.findById('694eca4bc476fea3f6481887');

        if (!question) {
            console.log('❌ Soru bulunamadı');
            process.exit(1);
        }

        // Yüklenen resmin ID'si
        const imageFileId = '694ff5e5f1f92e5697962933';

        console.log(`\n📝 Soru bulundu: "${question.data?.questionText || question.title}"`);
        console.log(`📸 Eklenen resim ID: ${imageFileId}`);
        console.log(`\n🔄 Soru güncelleniyor...\n`);

        // Data objesi yoksa oluştur
        if (!question.data) {
            question.data = {};
        }

        // Resmi ekle
        question.data.imageFileId = new mongoose.Types.ObjectId(imageFileId);
        
        // Mark as modified
        question.markModified('data');

        // Kaydet
        await question.save();

        // Tekrar kontrol et
        const updatedQuestion = await MiniQuestion.findById('694eca4bc476fea3f6481887').lean();

        console.log(`✅ Soru güncellendi!`);
        console.log(`\n📋 Güncellenmiş soru detayları:`);
        console.log(`   Question Text: ${updatedQuestion.data?.questionText || 'N/A'}`);
        console.log(`   Image ID: ${updatedQuestion.data?.imageFileId || 'Yok'}`);
        console.log(`   Data:`, JSON.stringify(updatedQuestion.data, null, 2));

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

addImageToSerbestCizim();


