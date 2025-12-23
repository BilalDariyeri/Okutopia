// models/progress.js - Öğrenci İlerleme Takibi

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const ProgressSchema = new Schema({
    // Hangi öğrenci
    student: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    // Hangi sınıf
    classroom: {
        type: Schema.Types.ObjectId,
        ref: 'Classroom',
        required: true
    },
    // Toplam puan
    overallScore: {
        type: Number,
        default: 0
    },
    // Tamamlanan aktiviteler
    activityRecords: [{
        activityId: {
            type: Schema.Types.ObjectId,
            ref: 'Activity',
            required: true
        },
        finalScore: {
            type: Number,
            default: 0
        },
        completionDate: {
            type: Date,
            default: Date.now
        }
    }]
}, {
    timestamps: true
});

// 💡 PERFORMANS: Index'ler
ProgressSchema.index({ student: 1, classroom: 1 }, { unique: true });
ProgressSchema.index({ student: 1 });
ProgressSchema.index({ classroom: 1 });

// Modeli yeniden tanımlamayı engeller
const Progress = mongoose.models.Progress || mongoose.model('Progress', ProgressSchema);

module.exports = Progress;

