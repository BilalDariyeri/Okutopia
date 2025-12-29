// scripts/listWritingActivities.js
// "Harf Yazımı" lesson'ındaki tüm etkinlikleri listeler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const Lesson = require('../models/lesson');

async function listWritingActivities() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        // "Harf Yazımı" lesson'ını bul
        const writingLesson = await Lesson.findOne({ 
            title: { $regex: /harf yazımı/i } 
        }).lean();

        if (!writingLesson) {
            console.log('❌ "Harf Yazımı" lesson\'ı bulunamadı');
            process.exit(1);
        }

        console.log(`\n✅ Lesson bulundu: "${writingLesson.title}" (ID: ${writingLesson._id})`);

        // Bu lesson'a ait tüm etkinlikleri bul
        const activities = await Activity.find({ 
            lesson: writingLesson._id 
        }).lean();

        console.log(`\n📊 Toplam ${activities.length} etkinlik bulundu:\n`);
        
        activities.forEach((activity, index) => {
            console.log(`${index + 1}. ${activity.title} (ID: ${activity._id})`);
        });

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

listWritingActivities();


