// scripts/deleteAWritingActivities.js
// "a harf yazımı" etkinliklerinden "küçük a yazım animasyonu" hariç hepsini siler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const Lesson = require('../models/lesson');
const MiniQuestion = require('../models/miniQuestion');

async function deleteAWritingActivities() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        // Tüm lesson'larda "a harf yazımı" içeren etkinlikleri bul
        console.log('\n📚 Tüm lesson\'larda "a harf yazımı" etkinlikleri aranıyor...');
        
        // Önce tüm lesson'ları bul
        const allLessons = await Lesson.find({}).lean();
        console.log(`📋 Toplam ${allLessons.length} lesson bulundu`);
        
        // Tüm lesson'lara ait etkinlikleri bul
        let allActivities = [];
        for (const lesson of allLessons) {
            const activities = await Activity.find({ lesson: lesson._id }).lean();
            if (activities.length > 0) {
                console.log(`  📚 "${lesson.title}": ${activities.length} etkinlik`);
                allActivities = allActivities.concat(activities.map(a => ({ ...a, lessonTitle: lesson.title })));
            }
        }
        
        console.log(`\n📊 Toplam ${allActivities.length} etkinlik bulundu`);
        
        // "a harf yazımı" içeren etkinlikleri filtrele
        const writingActivities = allActivities.filter(activity => {
            const title = (activity.title || '').toLowerCase();
            return title.includes('a harf yazımı') || title.includes('a yazım') || 
                   (title.includes('a') && (title.includes('yazım') || title.includes('yazim')));
        });
        
        console.log(`\n✍️ "a harf yazımı" içeren etkinlikler (${writingActivities.length} adet):`);
        writingActivities.forEach(activity => {
            console.log(`  - ${activity.title} (Lesson: ${activity.lessonTitle}, ID: ${activity._id})`);
        });
        
        if (writingActivities.length === 0) {
            console.log('❌ "a harf yazımı" içeren etkinlik bulunamadı');
            process.exit(0);
        }
        
        // "küçük a yazım animasyonu" hariç diğerlerini sil
        const keepTitle = 'küçük a yazım animasyonu';
        const toDelete = writingActivities.filter(activity => {
            const title = (activity.title || '').toLowerCase();
            return !title.includes(keepTitle);
        });
        
        const toKeep = writingActivities.filter(activity => {
            const title = (activity.title || '').toLowerCase();
            return title.includes(keepTitle);
        });
        
        console.log(`\n✅ Korunacak etkinlik (${toKeep.length} adet):`);
        toKeep.forEach(activity => {
            console.log(`  - ${activity.title} (Lesson: ${activity.lessonTitle})`);
        });
        
        console.log(`\n🗑️ Silinecek etkinlikler (${toDelete.length} adet):`);
        toDelete.forEach(activity => {
            console.log(`  - ${activity.title} (Lesson: ${activity.lessonTitle}, ID: ${activity._id})`);
        });
        
        if (toDelete.length === 0) {
            console.log('\n✅ Silinecek etkinlik yok');
            process.exit(0);
        }
        
        // Onay iste
        console.log(`\n⚠️ ${toDelete.length} etkinlik silinecek. Devam edilsin mi? (y/n)`);
        
        // Script otomatik çalıştırılacaksa direkt sil
        const shouldDelete = process.argv.includes('--yes') || process.argv.includes('-y');
        
        if (!shouldDelete) {
            console.log('❌ İşlem iptal edildi. Otomatik silmek için --yes veya -y parametresi kullanın.');
            process.exit(0);
        }
        
        // Etkinlikleri ve ilgili soruları sil
        let deletedCount = 0;
        for (const activity of toDelete) {
            // Önce bu etkinliğe ait soruları sil
            const questionsResult = await MiniQuestion.deleteMany({ 
                activity: activity._id 
            });
            console.log(`  📝 ${activity.title} için ${questionsResult.deletedCount} soru silindi`);
            
            // Sonra etkinliği sil
            await Activity.deleteOne({ _id: activity._id });
            deletedCount++;
            console.log(`  ✅ ${activity.title} silindi`);
        }
        
        console.log(`\n✅ Toplam ${deletedCount} etkinlik ve ilgili soruları silindi`);
        process.exit(0);
        
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

deleteAWritingActivities();

