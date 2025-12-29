// scripts/listAActivities.js
// "A a" harfine ait tüm lesson'ları ve etkinliklerini listeler

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const Lesson = require('../models/lesson');
const Group = require('../models/group');

async function listAActivities() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        // "A" içeren tüm lesson'ları bul
        const lessons = await Lesson.find({ 
            $or: [
                { title: { $regex: /^A$/i } },
                { targetContent: { $regex: /^A$/i } }
            ]
        }).populate('group').lean();

        console.log(`\n📚 "A" içeren lesson'lar (${lessons.length} adet):\n`);
        
        for (const lesson of lessons) {
            console.log(`📖 "${lesson.title}" (targetContent: "${lesson.targetContent}")`);
            console.log(`   Group: ${lesson.group?.name || 'N/A'}`);
            console.log(`   ID: ${lesson._id}\n`);
            
            // Bu lesson'a ait tüm etkinlikleri bul
            const activities = await Activity.find({ 
                lesson: lesson._id 
            }).lean();
            
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

        // Ayrıca "a harf yazımı" içeren tüm etkinlikleri bul
        console.log('\n🔍 "a harf yazımı" içeren tüm etkinlikler:\n');
        const allActivities = await Activity.find({}).populate('lesson').lean();
        const writingActivities = allActivities.filter(activity => {
            const title = (activity.title || '').toLowerCase();
            return title.includes('a') && (title.includes('yazım') || title.includes('yazim'));
        });
        
        writingActivities.forEach((activity, index) => {
            console.log(`${index + 1}. ${activity.title}`);
            console.log(`   Lesson: ${activity.lesson?.title || 'N/A'} (ID: ${activity.lesson?._id || 'N/A'})`);
            console.log(`   Activity ID: ${activity._id}\n`);
        });

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

listAActivities();


