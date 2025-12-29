// scripts/listAWritingQuestions.js
// "A harfi nasıl yazılır" etkinliğine ait tüm soruları listeler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const MiniQuestion = require('../models/miniQuestion');

async function listAWritingQuestions() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        // "A harfi nasıl yazılır" etkinliğini bul
        const activity = await Activity.findOne({ 
            title: { $regex: /A harfi nasıl yazılır/i } 
        }).lean();

        if (!activity) {
            console.log('❌ "A harfi nasıl yazılır" etkinliği bulunamadı');
            process.exit(1);
        }

        console.log(`\n✅ Etkinlik bulundu: "${activity.title}" (ID: ${activity._id})`);

        // Bu etkinliğe ait tüm soruları bul
        const questions = await MiniQuestion.find({ 
            activity: activity._id 
        }).sort({ createdAt: 1 }).lean();

        console.log(`\n📊 Toplam ${questions.length} soru bulundu:\n`);
        
        questions.forEach((question, index) => {
            console.log(`${index + 1}. ${question.title || 'Başlıksız'} (ID: ${question._id})`);
            console.log(`   Type: ${question.questionType || 'N/A'}`);
            console.log(`   Level: ${question.questionLevel || 'N/A'}`);
            if (question.data) {
                console.log(`   Data keys: ${Object.keys(question.data).join(', ')}`);
            }
            console.log('');
        });

        // "a harf yazımı" içeren soruları filtrele
        const aWritingQuestions = questions.filter(q => {
            const title = (q.title || '').toLowerCase();
            return title.includes('a') && (title.includes('yazım') || title.includes('yazim'));
        });

        if (aWritingQuestions.length > 0) {
            console.log(`\n✍️ "a harf yazımı" içeren sorular (${aWritingQuestions.length} adet):\n`);
            aWritingQuestions.forEach((question, index) => {
                console.log(`${index + 1}. ${question.title || 'Başlıksız'} (ID: ${question._id})`);
            });
        }

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

listAWritingQuestions();


