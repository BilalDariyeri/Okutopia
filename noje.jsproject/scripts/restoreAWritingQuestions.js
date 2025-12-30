// scripts/restoreAWritingQuestions.js
// Silinen "A harfi nasıl yazılır" sorularını geri getirir

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
const Activity = require('../models/activity');
const MiniQuestion = require('../models/miniQuestion');

async function restoreAWritingQuestions() {
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

        // Silinen soruların ID'leri ve bilgileri
        const deletedQuestions = [
            {
                _id: '694eca4bc476fea3f6481887',
                title: 'A Harfi Serbest Çizim',
                questionType: 'Image',
                questionLevel: 'Lesson',
                data: {
                    questionText: 'A Harfi Serbest Çizim',
                    instruction: 'A harfini serbest şekilde çizin',
                    audioFileId: null,
                    imageFileId: null,
                    contentObject: {}
                }
            },
            {
                _id: '694ecf45c476fea3f64818c2',
                title: 'A Harfi Noktalı Yazım',
                questionType: 'AUDIO_TEXT',
                questionLevel: 'Lesson',
                data: {
                    questionText: 'A Harfi Noktalı Yazım',
                    instruction: 'A harfini noktalı çizgileri takip ederek yazın',
                    audioFileId: null,
                    imageFileId: null,
                    contentObject: {}
                }
            },
            {
                _id: '694fc2d4c476fea3f6481a98',
                title: 'A harfi yazı tahtası',
                questionType: 'Image',
                questionLevel: 'Lesson',
                data: {
                    questionText: 'A harfi yazı tahtası',
                    instruction: 'A harfini yazı tahtasında yazın',
                    imageFileId: null,
                    audioFileId: null,
                    videoFileId: null,
                    contentObject: {}
                }
            },
            {
                _id: '694fcdbfc476fea3f6481b70',
                title: 'A yazı tahtası',
                questionType: 'Image',
                questionLevel: 'Lesson',
                data: {
                    questionText: 'A yazı tahtası',
                    instruction: 'A harfini yazı tahtasında yazın',
                    imageFileId: null,
                    audioFileId: null,
                    videoFileId: null,
                    contentObject: {}
                }
            }
        ];

        console.log(`\n📝 ${deletedQuestions.length} soru geri getirilecek:\n`);
        
        let restoredCount = 0;
        for (const questionData of deletedQuestions) {
            // Sorunun zaten var olup olmadığını kontrol et
            const existing = await MiniQuestion.findById(questionData._id).lean();
            
            if (existing) {
                console.log(`  ⚠️ "${questionData.title}" zaten mevcut, atlanıyor`);
                continue;
            }

            // Yeni soru oluştur
            const newQuestion = await MiniQuestion.create({
                _id: new mongoose.Types.ObjectId(questionData._id),
                activity: activity._id,
                lesson: activity.lesson,
                title: questionData.title,
                questionType: questionData.questionType,
                questionLevel: questionData.questionLevel,
                data: questionData.data
            });

            restoredCount++;
            console.log(`  ✅ "${questionData.title}" geri getirildi (ID: ${newQuestion._id})`);
        }

        console.log(`\n✅ Toplam ${restoredCount} soru geri getirildi`);

        // Tüm soruları listele
        const allQuestions = await MiniQuestion.find({ 
            activity: activity._id 
        }).sort({ createdAt: 1 }).lean();

        console.log(`\n📊 Etkinlikteki toplam soru sayısı: ${allQuestions.length}\n`);
        allQuestions.forEach((q, index) => {
            console.log(`${index + 1}. ${q.data?.questionText || q.title || 'Başlıksız'} (ID: ${q._id})`);
        });

        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

restoreAWritingQuestions();






