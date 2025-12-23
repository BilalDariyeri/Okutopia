// models/miniQuestion.js - Esnek soru yapısı: Grup, Aktivite veya Nested sorular

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const MiniQuestionSchema = new Schema({
    // 💡 ESNEK YAPI: Sorular farklı seviyelerde olabilir
    // 1. Aktiviteye bağlı sorular (mevcut kullanım)
    activity: {
        type: Schema.Types.ObjectId,
        ref: 'Activity',
        required: false, // Artık optional
        default: null
    },
    
    // 💡 YENİ: Gruba bağlı sorular (grup seviyesinde sorular)
    group: {
        type: Schema.Types.ObjectId,
        ref: 'Group',
        required: false,
        default: null
    },
    
    // 💡 YENİ: Nested sorular (soruların içinde sorular)
    parentQuestion: {
        type: Schema.Types.ObjectId,
        ref: 'MiniQuestion',
        required: false,
        default: null
    },
    
    // 💡 YENİ: Soru seviyesi (hangi seviyede olduğunu belirtir)
    questionLevel: {
        type: String,
        enum: ['Group', 'Activity', 'Nested'], // Grup, Aktivite veya İç içe soru
        required: true,
        default: 'Activity'
    },

    // 2. Soru Tipi: Uygulamanın hangi arayüzü kullanacağını belirler
    questionType: {
        type: String,
        enum: ['Image', 'Audio', 'Video', 'Drawing', 'Text', 'ONLY_TEXT', 'AUDIO_TEXT', 'IMAGE_TEXT', 'AUDIO_IMAGE_TEXT', 'DRAG_DROP'], 
        required: true
    },
    
    // 💡 YENİ: Soru Formatı (dinamik soru tipleri için)
    questionFormat: {
        type: String,
        enum: ['ONLY_TEXT', 'AUDIO_TEXT', 'IMAGE_TEXT', 'AUDIO_IMAGE_TEXT', 'DRAG_DROP'],
        required: false // Opsiyonel (geriye uyumluluk için)
    },
    
    // 💡 GRIDFS: Büyük dosyalar için GridFS referansı (Resim, Video, Audio)
    // Küçük dosyalar için hala data objesi kullanılabilir
    mediaFileId: {
        type: Schema.Types.ObjectId,  // GridFS file ID
        default: null
    },
    mediaUrl: {
        type: String,  // Alternatif: Direct URL (local file storage için)
        default: null
    },
    
    // 3. Dinamik İçerik: Soruya ait tüm özel veriler (Küçük veriler için - Base64 sadece küçük dosyalar)
    data: {
        type: Object, 
        default: {}
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
    
    // 4. Cevap Anahtarı
    // 💡 ESNEK: Kod yazma etkinliklerinde correctAnswer olmayabilir
    correctAnswer: {
        type: String, 
        required: false, // Artık optional (kod yazma etkinlikleri için)
        default: null
    }
}, {
    timestamps: true
});

// 💡 PERFORMANS: Database Indexing (uzun vadede kritik)
// Activity bazlı sorgular için index
MiniQuestionSchema.index({ activity: 1 });
// Group bazlı sorgular için index
MiniQuestionSchema.index({ group: 1 });
// Nested sorular için index
MiniQuestionSchema.index({ parentQuestion: 1 });
// Question level bazlı sorgular için index
MiniQuestionSchema.index({ questionLevel: 1 });
// Compound index: level ve ilgili ID kombinasyonu
MiniQuestionSchema.index({ questionLevel: 1, activity: 1 });
MiniQuestionSchema.index({ questionLevel: 1, group: 1 });
MiniQuestionSchema.index({ questionLevel: 1, parentQuestion: 1 });

// 💡 VALIDATION: En az bir ilişki olmalı (activity, group veya parentQuestion)
MiniQuestionSchema.pre('validate', function(next) {
    const hasActivity = this.activity != null;
    const hasGroup = this.group != null;
    const hasParentQuestion = this.parentQuestion != null;
    
    if (!hasActivity && !hasGroup && !hasParentQuestion) {
        const error = new Error('Soru en az bir seviyeye bağlı olmalıdır (activity, group veya parentQuestion)');
        return next(error);
    }
    
    // Question level'ı otomatik belirle
    if (hasGroup && !this.questionLevel) {
        this.questionLevel = 'Group';
    } else if (hasActivity && !this.questionLevel) {
        this.questionLevel = 'Activity';
    } else if (hasParentQuestion && !this.questionLevel) {
        this.questionLevel = 'Nested';
    }
    
    next();
});

// KRİTİK DÜZELTME: Modeli yeniden tanımlamayı engeller (OverwriteModelError çözümü için en güvenli yol)
module.exports = mongoose.models.MiniQuestion 
  ? mongoose.model('MiniQuestion') 
  : mongoose.model('MiniQuestion', MiniQuestionSchema);
