// scripts/cleanupBSesiHissetme.js
// "b sesi hissetme" etkinliğindeki yinelenen soruları temizler
// - bulut, bebek, tabak: her birinden 2 tane varsa 1 tanesini tut, diğerini sil
// - sadece sesli sorular (audioFileId var ama imageFileId yok): hepsini sil

const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

// Modelleri yükle
require('../models/activity');
require('../models/miniQuestion');
const { getFileInfo, initGridFS } = require('../utils/gridfs');

const Activity = mongoose.model('Activity');
const MiniQuestion = mongoose.model('MiniQuestion');

async function cleanupBSesiHissetme() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');
        
        // GridFS'i başlat
        initGridFS();
        console.log('✅ GridFS başlatıldı\n');

        // "b sesi hissetme" etkinliğini bul
        const activity = await Activity.findOne({
            $or: [
                { title: { $regex: /b.*sesi.*hissetme/i } },
                { title: { $regex: /b.*harfi.*sesi/i } },
                { title: { $regex: /sesi.*hissetme.*b/i } }
            ]
        });

        if (!activity) {
            console.log('❌ "b sesi hissetme" etkinliği bulunamadı');
            console.log('💡 Mevcut etkinlikler:');
            const allActivities = await Activity.find({}).select('title').limit(10);
            allActivities.forEach(a => console.log(`   - ${a.title}`));
            await mongoose.connection.close();
            process.exit(1);
        }

        console.log(`✅ Etkinlik bulundu: "${activity.title}" (ID: ${activity._id})\n`);

        // Bu etkinliğe ait tüm soruları getir (silinmemiş olanlar)
        const questions = await MiniQuestion.find({ activity: activity._id }).lean();
        console.log(`📊 Toplam ${questions.length} soru bulundu\n`);
        
        // Eğer 3'ten fazla soru varsa, yinelenenler olabilir
        if (questions.length > 3) {
            console.log(`⚠️ Beklenenden fazla soru var (${questions.length}). Yinelenenler olabilir.\n`);
        }
        
        // Soruları göster ve dosya adlarını al (debug için)
        console.log('📋 Mevcut sorular:');
        const questionsWithFilenames = [];
        
        for (const q of questions) {
            const questionText = q.data?.questionText || q.data?.text || q.data?.soru || 'N/A';
            const imageFileId = q.data?.imageFileId || (q.mediaType === 'Image' ? q.mediaFileId : null);
            const audioFileId = q.data?.audioFileId || (q.mediaType === 'Audio' ? q.mediaFileId : null);
            
            // mediaFiles array'ini kontrol et
            let imageFromMediaFiles = null;
            let audioFromMediaFiles = null;
            if (q.mediaFiles && Array.isArray(q.mediaFiles)) {
                const imageFile = q.mediaFiles.find(mf => mf.mediaType === 'Image');
                const audioFile = q.mediaFiles.find(mf => mf.mediaType === 'Audio');
                imageFromMediaFiles = imageFile?.fileId;
                audioFromMediaFiles = audioFile?.fileId;
            }
            
            const finalImageId = imageFileId || imageFromMediaFiles;
            const finalAudioId = audioFileId || audioFromMediaFiles;
            
            // GridFS'ten dosya adlarını al
            let imageFilename = 'N/A';
            let audioFilename = 'N/A';
            
            if (finalImageId) {
                try {
                    const imageInfo = await getFileInfo(finalImageId);
                    imageFilename = imageInfo.filename || 'N/A';
                } catch (e) {
                    imageFilename = 'Bulunamadı';
                }
            }
            
            if (finalAudioId) {
                try {
                    const audioInfo = await getFileInfo(finalAudioId);
                    audioFilename = audioInfo.filename || 'N/A';
                } catch (e) {
                    audioFilename = 'Bulunamadı';
                }
            }
            
            questionsWithFilenames.push({
                ...q,
                imageFilename,
                audioFilename,
                finalImageId,
                finalAudioId
            });
            
            console.log(`   ${questionsWithFilenames.length}. ID: ${q._id}`);
            console.log(`      Metin: ${questionText}`);
            console.log(`      Resim: ${imageFilename} (ID: ${finalImageId || 'Yok'})`);
            console.log(`      Ses: ${audioFilename} (ID: ${finalAudioId || 'Yok'})`);
            console.log('');
        }

        let deletedCount = 0;
        let keptCount = 0;

        // 1. Dosya adlarına göre bulut, bebek, tabak sorularını bul
        const keywordGroups = {
            'bulut': [],
            'bebek': [],
            'tabak': []
        };
        
        questionsWithFilenames.forEach(q => {
            const searchText = (q.imageFilename + ' ' + q.audioFilename + ' ' + (q.data?.questionText || '')).toLowerCase();
            for (const keyword of Object.keys(keywordGroups)) {
                if (searchText.includes(keyword)) {
                    keywordGroups[keyword].push(q);
                }
            }
        });
        
        // Her keyword için yinelenenleri temizle
        for (const [keyword, matchingQuestions] of Object.entries(keywordGroups)) {
            if (matchingQuestions.length > 1) {
                console.log(`🔍 "${keyword}" için ${matchingQuestions.length} soru bulundu (dosya adlarına göre)`);
                // İlkini tut, diğerlerini sil
                const toKeep = matchingQuestions[0];
                const toDelete = matchingQuestions.slice(1);

                console.log(`   ✅ Tutulacak: ${toKeep._id} (${toKeep.imageFilename})`);
                
                for (const question of toDelete) {
                    await MiniQuestion.findByIdAndDelete(question._id);
                    deletedCount++;
                    console.log(`   ❌ Silindi: ${question._id} (${question.imageFilename})`);
                }
                keptCount++;
            } else if (matchingQuestions.length === 1) {
                console.log(`🔍 "${keyword}" için 1 soru bulundu (zaten tek)`);
                keptCount++;
            }
        }
        console.log('');

        // 2. Aynı imageFileId'ye sahip yinelenen soruları bul ve temizle
        const imageGroups = {};
        questionsWithFilenames.forEach(q => {
            if (q.finalImageId) {
                const imageIdStr = q.finalImageId.toString();
                if (!imageGroups[imageIdStr]) {
                    imageGroups[imageIdStr] = [];
                }
                imageGroups[imageIdStr].push(q);
            }
        });

        console.log('🔍 Aynı görsele sahip sorular:');
        for (const [imageId, groupQuestions] of Object.entries(imageGroups)) {
            if (groupQuestions.length > 1) {
                console.log(`   📷 Görsel ID ${imageId}: ${groupQuestions.length} soru bulundu`);
                // İlkini tut, diğerlerini sil
                const toKeep = groupQuestions[0];
                const toDelete = groupQuestions.slice(1);

                console.log(`      ✅ Tutulacak: ${toKeep._id}`);
                
                for (const question of toDelete) {
                    await MiniQuestion.findByIdAndDelete(question._id);
                    deletedCount++;
                    console.log(`      ❌ Silindi: ${question._id}`);
                }
                keptCount++;
            } else {
                console.log(`   📷 Görsel ID ${imageId}: 1 soru (zaten tek)`);
                keptCount++;
            }
        }
        console.log('');


        // 3. Sadece sesli soruları bul ve sil (audioFileId var ama imageFileId yok)
        // Önce güncel soru listesini yeniden al (silinenler hariç)
        const remainingQuestions = await MiniQuestion.find({ activity: activity._id }).lean();
        
        const audioOnlyQuestions = remainingQuestions.filter(q => {
            // Silinmiş soruları atla
            const imageFileId = q.data?.imageFileId || (q.mediaType === 'Image' ? q.mediaFileId : null);
            const audioFileId = q.data?.audioFileId || (q.mediaType === 'Audio' ? q.mediaFileId : null);
            
            // mediaFiles array'ini kontrol et
            let hasImageInMediaFiles = false;
            let hasAudioInMediaFiles = false;
            if (q.mediaFiles && Array.isArray(q.mediaFiles)) {
                hasImageInMediaFiles = q.mediaFiles.some(mf => mf.mediaType === 'Image');
                hasAudioInMediaFiles = q.mediaFiles.some(mf => mf.mediaType === 'Audio');
            }
            
            // Eğer ses var ama resim yoksa
            const hasAudio = !!audioFileId || hasAudioInMediaFiles;
            const hasImage = !!imageFileId || hasImageInMediaFiles;
            
            // Sadece sesli soru: ses var ama resim yok
            return hasAudio && !hasImage;
        });

        console.log(`🔍 Sadece sesli sorular: ${audioOnlyQuestions.length} adet`);

        for (const question of audioOnlyQuestions) {
            // Önce yukarıdaki keyword'lerden birini içeriyor mu kontrol et
            // Eğer içeriyorsa, zaten yukarıda işlendi, atla
            const questionText = question.data?.questionText || question.data?.text || '';
            const instruction = question.data?.instruction || '';
            const searchText = (questionText + ' ' + instruction).toLowerCase();
            
            const containsKeyword = keywords.some(kw => searchText.includes(kw.toLowerCase()));
            
            if (!containsKeyword) {
                await MiniQuestion.findByIdAndDelete(question._id);
                deletedCount++;
                console.log(`   ❌ Silindi (sadece ses): ${question._id} (${question.data?.questionText || 'N/A'})`);
            }
        }

        // Özet
        console.log('\n📊 ÖZET:');
        console.log(`   ✅ Tutulan sorular: ${keptCount}`);
        console.log(`   ❌ Silinen sorular: ${deletedCount}`);
        console.log(`   📝 Kalan toplam soru: ${questionsWithFilenames.length - deletedCount}`);

        // Son durumu kontrol et
        const finalQuestionCount = await MiniQuestion.find({ activity: activity._id }).countDocuments();
        console.log(`\n📊 Etkinlikteki kalan soru sayısı: ${finalQuestionCount}`);

        console.log('\n✅ Temizleme tamamlandı!');
        await mongoose.connection.close();
        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        await mongoose.connection.close();
        process.exit(1);
    }
}

cleanupBSesiHissetme();

