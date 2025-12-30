// scripts/addImageToSerbestCizim.js
// "A Harfi Serbest Çizim" sorusuna resim ekler

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

        // "A Harfi Nasıl Yazılır?" sorusunun imageFileId'sini al
        const nasilYazilirQuestion = await MiniQuestion.findById('694ebfddc476fea3f64817c3');
        
        if (!nasilYazilirQuestion) {
            console.log('❌ "A Harfi Nasıl Yazılır?" sorusu bulunamadı');
            process.exit(1);
        }

        const imageFileId = nasilYazilirQuestion.data?.imageFileId || nasilYazilirQuestion.mediaFileId;

        if (!imageFileId) {
            console.log('❌ "A Harfi Nasıl Yazılır?" sorusunda resim bulunamadı');
            process.exit(1);
        }

        console.log(`\n✅ "A Harfi Nasıl Yazılır?" sorusundaki resim ID: ${imageFileId}`);
        console.log(`📝 "A Harfi Serbest Çizim" sorusuna ekleniyor...\n`);

        // Resmi "A Harfi Serbest Çizim" sorusuna ekle
        if (!question.data) {
            question.data = {};
        }

        question.data.imageFileId = imageFileId;

        await question.save();

        console.log(`✅ Resim başarıyla eklendi!`);
        console.log(`\n📋 Güncellenmiş soru:`);
        console.log(`   Question Text: ${question.data.questionText}`);
        console.log(`   Image ID: ${question.data.imageFileId}`);

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

addImageToSerbestCizim();






