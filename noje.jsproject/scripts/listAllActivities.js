// scripts/listAllActivities.js
// Tüm lesson'ları ve etkinliklerini listeler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const Lesson = require('../models/lesson');

async function listAllActivities() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        // Tüm lesson'ları bul
        const lessons = await Lesson.find({}).sort({ title: 1 }).lean();

        console.log(`\n📚 Toplam ${lessons.length} lesson bulundu:\n`);
        
        for (const lesson of lessons) {
            console.log(`📖 "${lesson.title}" (targetContent: "${lesson.targetContent}")`);
            console.log(`   ID: ${lesson._id}`);
            
            // Bu lesson'a ait tüm etkinlikleri bul
            const activities = await Activity.find({ 
                lesson: lesson._id 
            }).sort({ title: 1 }).lean();
            
            if (activities.length > 0) {
                console.log(`   📊 ${activities.length} etkinlik:`);
                activities.forEach((activity, index) => {
                    console.log(`      ${index + 1}. ${activity.title} (ID: ${activity._id})`);
                });
            } else {
                console.log(`   ℹ️ Etkinlik yok`);
            }
            console.log('');
        }

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

listAllActivities();






