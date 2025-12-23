// models/studentSession.js - Öğrenci Oturum Takibi

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const StudentSessionSchema = new Schema({
    student: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    startTime: {
        type: Date,
        required: true,
        default: Date.now
    },
    endTime: {
        type: Date,
        default: null
    },
    duration: {
        type: Number, // Saniye cinsinden süre
        default: 0
    },
    isActive: {
        type: Boolean,
        default: true
    },
    date: {
        type: Date,
        required: true,
        default: Date.now
    }
}, {
    timestamps: true
});

// 💡 PERFORMANS: Index'ler
StudentSessionSchema.index({ student: 1, date: -1 });
StudentSessionSchema.index({ student: 1, isActive: 1 });

// Oturum bitirme metodu
StudentSessionSchema.methods.endSession = function() {
    if (!this.endTime) {
        this.endTime = new Date();
        this.duration = Math.floor((this.endTime - this.startTime) / 1000); // Saniye cinsinden
        this.isActive = false;
    }
    return this;
};

module.exports = mongoose.models.StudentSession || mongoose.model('StudentSession', StudentSessionSchema);




