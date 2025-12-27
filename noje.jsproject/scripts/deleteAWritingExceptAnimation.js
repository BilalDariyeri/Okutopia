// scripts/deleteAWritingExceptAnimation.js
// "a harf yazımı" içeren tüm soruları bulur ve "küçük a yazım animasyonu" hariç hepsini siler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const MiniQuestion = require('../models/miniQuestion');

async function deleteAWritingExceptAnimation() {
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
        
        // "a harf yazımı" içeren soruları filtrele
        const aWritingQuestions = questions.filter(q => {
            const questionText = (q.data?.questionText || '').toLowerCase();
            const instruction = (q.data?.instruction || '').toLowerCase();
            const searchText = questionText + ' ' + instruction;
            
            return searchText.includes('a') && 
                   (searchText.includes('yazım') || searchText.includes('yazim') || 
                    searchText.includes('çizim') || searchText.includes('cizim') ||
                    searchText.includes('tahta') || searchText.includes('noktalı') ||
                    searchText.includes('serbest'));
        });

        console.log(`✍️ "a harf yazımı" içeren sorular (${aWritingQuestions.length} adet):\n`);
        aWritingQuestions.forEach((question, index) => {
            const questionText = question.data?.questionText || question.data?.instruction || 'Başlıksız';
            console.log(`${index + 1}. ${questionText} (ID: ${question._id})`);
        });

        if (aWritingQuestions.length === 0) {
            console.log('❌ "a harf yazımı" içeren soru bulunamadı');
            process.exit(0);
        }

        // "küçük a yazım animasyonu" hariç diğerlerini sil
        const keepKeywords = ['küçük', 'a', 'yazım', 'animasyon'];
        const toKeep = aWritingQuestions.filter(q => {
            const questionText = (q.data?.questionText || '').toLowerCase();
            const instruction = (q.data?.instruction || '').toLowerCase();
            const searchText = questionText + ' ' + instruction;
            
            // Tüm anahtar kelimeleri içeriyor mu kontrol et
            return keepKeywords.every(keyword => searchText.includes(keyword));
        });

        const toDelete = aWritingQuestions.filter(q => {
            const questionText = (q.data?.questionText || '').toLowerCase();
            const instruction = (q.data?.instruction || '').toLowerCase();
            const searchText = questionText + ' ' + instruction;
            
            // Tüm anahtar kelimeleri içermiyorsa sil
            return !keepKeywords.every(keyword => searchText.includes(keyword));
        });

        console.log(`\n✅ Korunacak sorular (${toKeep.length} adet):`);
        toKeep.forEach((question, index) => {
            const questionText = question.data?.questionText || question.data?.instruction || 'Başlıksız';
            console.log(`  ${index + 1}. ${questionText} (ID: ${question._id})`);
        });

        console.log(`\n🗑️ Silinecek sorular (${toDelete.length} adet):`);
        toDelete.forEach((question, index) => {
            const questionText = question.data?.questionText || question.data?.instruction || 'Başlıksız';
            console.log(`  ${index + 1}. ${questionText} (ID: ${question._id})`);
        });

        if (toDelete.length === 0) {
            console.log('\n✅ Silinecek soru yok');
            process.exit(0);
        }

        // Onay iste
        console.log(`\n⚠️ ${toDelete.length} soru silinecek. Devam edilsin mi? (y/n)`);
        
        // Script otomatik çalıştırılacaksa direkt sil
        const shouldDelete = process.argv.includes('--yes') || process.argv.includes('-y');
        
        if (!shouldDelete) {
            console.log('❌ İşlem iptal edildi. Otomatik silmek için --yes veya -y parametresi kullanın.');
            process.exit(0);
        }

        // Soruları sil
        let deletedCount = 0;
        for (const question of toDelete) {
            await MiniQuestion.deleteOne({ _id: question._id });
            const questionText = question.data?.questionText || question.data?.instruction || 'Başlıksız';
            deletedCount++;
            console.log(`  ✅ ${questionText} silindi`);
        }

        console.log(`\n✅ Toplam ${deletedCount} soru silindi`);
        process.exit(0);
        
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

deleteAWritingExceptAnimation();


