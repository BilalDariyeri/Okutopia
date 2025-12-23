// models/dailyStatistics.js - Günlük İstatistikler

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const DailyStatisticsSchema = new Schema({
    student: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    date: {
        type: Date,
        required: true,
        default: Date.now
    },
    // Uygulamada geçirilen toplam süre (saniye cinsinden)
    totalTimeSpent: {
        type: Number, // Saniye cinsinden
        default: 0
    },
    // Okuma süresi (saniye cinsinden)
    totalReadingTime: {
        type: Number, // Saniye cinsinden
        default: 0
    },
    // Toplam okunan kelime sayısı
    totalWordsRead: {
        type: Number,
        default: 0
    },
    // Ortalama okuma hızı (kelime/dakika)
    averageReadingSpeed: {
        type: Number, // Kelime/dakika
        default: 0
    },
    // Tamamlanan aktivite sayısı
    completedActivities: {
        type: Number,
        default: 0
    },
    // Tamamlanan aktivitelerin detayları
    activities: [{
        activityId: {
            type: Schema.Types.ObjectId,
            ref: 'Activity'
        },
        completionTime: {
            type: Date,
            default: Date.now
        },
        score: {
            type: Number,
            default: 0
        },
        // Kategori bilgisi (aktivite -> lesson -> group -> category)
        categoryName: {
            type: String,
            default: ''
        },
        // Aktivite başlığı (hızlı erişim için)
        activityTitle: {
            type: String,
            default: ''
        }
    }],
    // Son kaldığı yer (hangi aktivitede)
    lastActivityId: {
        type: Schema.Types.ObjectId,
        ref: 'Activity',
        default: null
    },
    // İlerleme yüzdesi (bugün tamamlanan aktivitelerin toplam aktiviteye oranı)
    progressPercentage: {
        type: Number,
        default: 0,
        min: 0,
        max: 100
    },
    // Email gönderildi mi?
    emailSent: {
        type: Boolean,
        default: false
    },
    emailSentAt: {
        type: Date,
        default: null
    }
}, {
    timestamps: true
});

// 💡 PERFORMANS: Index'ler
DailyStatisticsSchema.index({ student: 1, date: -1 });
DailyStatisticsSchema.index({ student: 1, date: 1 }, { unique: true }); // Her öğrenci için günde bir kayıt

// Tarih formatını düzelt (sadece tarih kısmı, saat olmadan)
DailyStatisticsSchema.pre('save', function(next) {
    if (this.date) {
        // Tarihi sadece yıl-ay-gün olarak ayarla (saat bilgisi olmadan)
        const dateOnly = new Date(this.date);
        dateOnly.setHours(0, 0, 0, 0);
        this.date = dateOnly;
    }
    next();
});

module.exports = mongoose.models.DailyStatistics || mongoose.model('DailyStatistics', DailyStatisticsSchema);


