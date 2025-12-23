// models/activity.js - GÜNCELLENDİ: Artık Lesson modeline bağlanıyor

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const ActivitySchema = new Schema({
    title: { 
        type: String, 
        required: [true, 'Aktivite başlığı zorunludur.'] 
    },
    
    // KRİTİK DEĞİŞİKLİK: 'group' yerine 'lesson' modeline referans veriyor
    lesson: {
        type: Schema.Types.ObjectId,
        ref: 'Lesson', // Yeni Lesson modeline referans
        required: true
    },
    
    // Aktivitenin türü (Örn: Çizim, Dinleme, Eşleştirme)
    type: {
        type: String,
        enum: ['Drawing', 'Listening', 'Quiz', 'Visual'], // Kabul edilen etkinlik türleri
        default: 'Quiz'
    },

    // Ortalama tamamlanma süresi (Opsiyonel)
    durationMinutes: {
        type: Number,
        default: 5
    },
    
    // 💡 EKLENTİ: Etkinlik Tipi (Soru tipi gibi)
    activityType: {
        type: String,
        enum: ['Image', 'Audio', 'Video', 'Drawing', 'Text'], 
        default: 'Text'
    },
    
    // 💡 GRIDFS: Büyük dosyalar için GridFS referansı (Resim, Video, Audio)
    mediaFileId: {
        type: Schema.Types.ObjectId,  // GridFS file ID
        default: null
    },
    mediaUrl: {
        type: String,  // Alternatif: Direct URL (local file storage için)
        default: null
    },
    
    // 💡 EKLENTİ: Medya türü (GridFS veya Base64)
    mediaType: {
        type: String,
        enum: ['None', 'Audio', 'Image', 'Video'], 
        default: 'None'
    },
    
    // 💡 EKLENTİ: Medya depolama tipi
    mediaStorage: {
        type: String,
        enum: ['None', 'GridFS', 'Base64', 'URL'],  // GridFS (büyük), Base64 (küçük), URL (external)
        default: 'None'
    },
    
    // 💡 EKLENTİ: Birden fazla medya dosyası (array)
    // Ses dosyaları, görseller, videolar burada tutulur
    mediaFiles: [{
        fileId: {
            type: Schema.Types.ObjectId,
            required: true
        },
        mediaType: {
            type: String,
            enum: ['Audio', 'Image', 'Video'],
            required: true
        },
        order: {
            type: Number,
            default: 0
        }
    }],
    
    // 💡 OKUMA METNİ: Okuma metni satırları (activityType: 'Text' olduğunda kullanılır)
    // Örn: ["Ahmet yaptı.", "Ahmet ödevi yaptı.", "Ahmet ödevi doğru yaptı."]
    textLines: [{
        type: String
    }],
    
    // 💡 OKUMA METNİ: Okuma süresi (saniye cinsinden)
    // Örn: 60 saniye = 1 dakika
    readingDuration: {
        type: Number, // Saniye cinsinden
        default: null
    },
    
    // 💡 OKUMA METNİ: Metin içeriği (alternatif - textLines yerine tek bir string)
    content: {
        type: String,
        default: null
    },
    
    // NOT: targetContent alanı kaldırıldı, çünkü bu bilgi Lesson modelinde saklanacak.
    
}, { 
    timestamps: true
});

// 💡 PERFORMANS: Database Indexing (uzun vadede kritik)
// Lesson bazlı sorgular için index
ActivitySchema.index({ lesson: 1 });

// Modeli yeniden tanımlamayı engeller (Hata çözümü için kritik)
module.exports = mongoose.models.Activity || mongoose.model('Activity', ActivitySchema);
