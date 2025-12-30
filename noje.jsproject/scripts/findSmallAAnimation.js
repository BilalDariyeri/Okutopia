// scripts/findSmallAAnimation.js
// "küçük a yazım animasyonu" içeren soruyu bulur

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const MiniQuestion = require('../models/miniQuestion');

async function findSmallAAnimation() {
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
        
        // Her sorunun içeriğini kontrol et
        for (let i = 0; i < questions.length; i++) {
            const question = questions[i];
            console.log(`\n${i + 1}. Soru (ID: ${question._id})`);
            console.log(`   Type: ${question.questionType || 'N/A'}`);
            console.log(`   Level: ${question.questionLevel || 'N/A'}`);
            
            if (question.data) {
                console.log(`   Data:`);
                if (question.data.questionText) {
                    console.log(`      questionText: ${question.data.questionText.substring(0, 100)}...`);
                }
                if (question.data.instruction) {
                    console.log(`      instruction: ${question.data.instruction.substring(0, 100)}...`);
                }
                if (question.data.contentObject) {
                    const contentStr = JSON.stringify(question.data.contentObject);
                    if (contentStr.toLowerCase().includes('küçük') || contentStr.toLowerCase().includes('animasyon')) {
                        console.log(`      ⚠️ "küçük" veya "animasyon" içeriyor!`);
                        console.log(`      contentObject: ${contentStr.substring(0, 200)}...`);
                    }
                }
            }
            
            // "küçük a yazım animasyonu" içeren soruyu bul
            const searchText = JSON.stringify(question).toLowerCase();
            if (searchText.includes('küçük') && searchText.includes('a') && 
                (searchText.includes('yazım') || searchText.includes('yazim')) && 
                searchText.includes('animasyon')) {
                console.log(`\n   ✅ BULUNDU! Bu soru "küçük a yazım animasyonu" içeriyor!`);
            }
        }

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

findSmallAAnimation();






