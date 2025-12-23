// models/readingSession.js - Okuma Süresi Takibi

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const ReadingSessionSchema = new Schema({
    // Hangi öğrenci okuma yapıyor
    student: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    // Hangi aktivite/ders için okuma yapılıyor
    activity: {
        type: Schema.Types.ObjectId,
        ref: 'Activity',
        required: true
    },
    // Okuma başlangıç zamanı
    startTime: {
        type: Date,
        required: true,
        default: Date.now
    },
    // Okuma bitiş zamanı
    endTime: {
        type: Date,
        default: null
    },
    // Okuma süresi (saniye cinsinden)
    duration: {
        type: Number,
        default: 0
    },
    // Okunan kelime sayısı
    wordCount: {
        type: Number,
        default: 0
    },
    // Okuma hızı (kelime/dakika)
    readingSpeed: {
        type: Number, // Kelime/dakika
        default: 0
    },
    // Tarih (sadece tarih kısmı)
    date: {
        type: Date,
        required: true,
        default: Date.now
    },
    // Oturum aktif mi?
    isActive: {
        type: Boolean,
        default: true
    }
}, {
    timestamps: true
});

// 💡 PERFORMANS: Index'ler
ReadingSessionSchema.index({ student: 1, date: -1 });
ReadingSessionSchema.index({ student: 1, activity: 1 });
ReadingSessionSchema.index({ student: 1, isActive: 1 });

// Okuma oturumu bitirme metodu
ReadingSessionSchema.methods.endReading = function(wordCount = 0) {
    if (!this.endTime) {
        this.endTime = new Date();
        this.duration = Math.floor((this.endTime - this.startTime) / 1000); // Saniye cinsinden
        this.wordCount = wordCount;
        
        // Okuma hızını hesapla (kelime/dakika)
        if (this.duration > 0 && wordCount > 0) {
            const minutes = this.duration / 60;
            this.readingSpeed = Math.round((wordCount / minutes) * 100) / 100; // 2 ondalık basamak
        }
        
        this.isActive = false;
    }
    return this;
};

// Tarih formatını düzelt (sadece tarih kısmı, saat olmadan)
ReadingSessionSchema.pre('save', function(next) {
    if (this.date) {
        const dateOnly = new Date(this.date);
        dateOnly.setHours(0, 0, 0, 0);
        this.date = dateOnly;
    }
    next();
});

module.exports = mongoose.models.ReadingSession || mongoose.model('ReadingSession', ReadingSessionSchema);

