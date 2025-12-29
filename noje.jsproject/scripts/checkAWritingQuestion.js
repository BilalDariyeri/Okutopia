// scripts/checkAWritingQuestion.js
// "A Harfi Serbest Çizim" sorusunun detaylarını kontrol eder

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const MiniQuestion = require('../models/miniQuestion');

async function checkAWritingQuestion() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        // "A Harfi Serbest Çizim" sorusunu bul
        const question = await MiniQuestion.findOne({ 
            _id: '694eca4bc476fea3f6481887'
        }).lean();

        if (!question) {
            console.log('❌ Soru bulunamadı');
            process.exit(1);
        }

        console.log(`\n✅ Soru bulundu: "${question.data?.questionText || question.title}"`);
        console.log(`\n📋 Soru detayları:`);
        console.log(`   ID: ${question._id}`);
        console.log(`   Type: ${question.questionType}`);
        console.log(`   Level: ${question.questionLevel}`);
        console.log(`   Data:`, JSON.stringify(question.data, null, 2));

        // Tüm "A harfi nasıl yazılır" etkinliğindeki soruları kontrol et
        const activity = await Activity.findOne({ 
            title: { $regex: /A harfi nasıl yazılır/i } 
        }).lean();

        if (activity) {
            console.log(`\n📚 Etkinlik: "${activity.title}"`);
            const allQuestions = await MiniQuestion.find({ 
                activity: activity._id 
            }).lean();

            console.log(`\n📊 Tüm sorular (${allQuestions.length} adet):\n`);
            allQuestions.forEach((q, index) => {
                const hasImage = q.data?.imageFileId || q.mediaFileId;
                const hasAudio = q.data?.audioFileId;
                console.log(`${index + 1}. ${q.data?.questionText || q.title || 'Başlıksız'}`);
                console.log(`   Image: ${hasImage ? '✅ ' + (q.data?.imageFileId || q.mediaFileId) : '❌ Yok'}`);
                console.log(`   Audio: ${hasAudio ? '✅ ' + q.data?.audioFileId : '❌ Yok'}`);
                console.log('');
            });
        }

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

checkAWritingQuestion();


