// scripts/listAllAQuestions.js
// "A harfi nasıl yazılır" etkinliğindeki tüm soruları detaylı listeler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const MiniQuestion = require('../models/miniQuestion');

async function listAllAQuestions() {
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

        // Bu etkinliğe ait tüm soruları bul (hem Activity hem Lesson level)
        const allQuestions = await MiniQuestion.find({ 
            $or: [
                { activity: activity._id },
                { lesson: activity.lesson }
            ]
        }).sort({ createdAt: 1 }).lean();

        console.log(`\n📊 Toplam ${allQuestions.length} soru bulundu (Activity + Lesson level):\n`);
        
        // "a" içeren soruları filtrele
        const aQuestions = allQuestions.filter(q => {
            const searchText = JSON.stringify(q).toLowerCase();
            return searchText.includes('a') && 
                   (searchText.includes('yazım') || searchText.includes('yazim') || 
                    searchText.includes('çizim') || searchText.includes('cizim') ||
                    searchText.includes('tahta') || searchText.includes('noktalı') ||
                    searchText.includes('serbest') || searchText.includes('animasyon'));
        });

        console.log(`\n✍️ "a" içeren yazım soruları (${aQuestions.length} adet):\n`);
        
        for (let i = 0; i < aQuestions.length; i++) {
            const question = aQuestions[i];
            const questionText = question.data?.questionText || '';
            const instruction = question.data?.instruction || '';
            
            console.log(`${i + 1}. ${questionText || instruction || 'Başlıksız'}`);
            console.log(`   Type: ${question.questionType || 'N/A'}`);
            console.log(`   Level: ${question.questionLevel || 'N/A'}`);
            console.log(`   ID: ${question._id}`);
            
            // "küçük a yazım animasyonu" kontrolü
            const searchText = (questionText + ' ' + instruction).toLowerCase();
            if (searchText.includes('küçük') && searchText.includes('a') && 
                (searchText.includes('yazım') || searchText.includes('yazim')) && 
                searchText.includes('animasyon')) {
                console.log(`   ✅ "küçük a yazım animasyonu" içeriyor!`);
            }
            console.log('');
        }

        // Tüm soruları da listele
        console.log(`\n📋 Tüm sorular (${allQuestions.length} adet):\n`);
        for (let i = 0; i < allQuestions.length; i++) {
            const question = allQuestions[i];
            const questionText = question.data?.questionText || '';
            const instruction = question.data?.instruction || '';
            console.log(`${i + 1}. ${questionText || instruction || 'Başlıksız'} (ID: ${question._id})`);
        }

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

listAllAQuestions();


