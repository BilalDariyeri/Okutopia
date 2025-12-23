// models/lesson.js - Grup içindeki seçilebilir harf/konu birimi

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const LessonSchema = new Schema({
    title: { 
        type: String, 
        required: [true, 'Ders/Ünite başlığı zorunludur.'] 
    },
    
    // İlişki: Hangi gruba ait olduğunu belirtir
    group: {
        type: Schema.Types.ObjectId,
        ref: 'Group',
        required: true
    },
    
    // Hangi harf, sayı vb. hedeflediğini tutar (Örn: "A", "L")
    targetContent: {
        type: String,
        required: [true, 'Hedef içerik zorunludur.']
    },

    orderIndex: { 
        type: Number, 
        default: 0 // Grubun içindeki sıralama (A harfi 1, B harfi 2)
    },
    
    // 💡 EKLENTİ: Ders Tipi (Soru tipi gibi)
    lessonType: {
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
    }]
}, {
    timestamps: true
});

// 💡 PERFORMANS: Database Indexing (uzun vadede kritik)
// Grup bazlı sorgular için index
LessonSchema.index({ group: 1 });
// Grup ve orderIndex kombinasyonu için compound index (sıralama sorguları için)
LessonSchema.index({ group: 1, orderIndex: 1 });

module.exports = mongoose.models.Lesson || mongoose.model('Lesson', LessonSchema);