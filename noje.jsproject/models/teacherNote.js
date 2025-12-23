// models/teacherNote.js - Öğretmen Notları Modeli

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const TeacherNoteSchema = new Schema({
    // Hangi öğrenci için not
    student: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    // Hangi öğretmen notu yazdı
    teacher: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    // Not başlığı
    title: {
        type: String,
        required: [true, 'Not başlığı zorunludur.'],
        trim: true,
        maxlength: [200, 'Not başlığı en fazla 200 karakter olabilir.']
    },
    // Not içeriği
    content: {
        type: String,
        required: [true, 'Not içeriği zorunludur.'],
        trim: true
    },
    // Not önceliği (Normal, Önemli, Acil)
    priority: {
        type: String,
        enum: ['Normal', 'Önemli', 'Acil'],
        default: 'Normal'
    },
    // Not kategorisi (opsiyonel - Genel, Davranış, Akademik, vb.)
    category: {
        type: String,
        trim: true,
        default: 'Genel'
    }
}, {
    timestamps: true
});

// 💡 PERFORMANS: Index'ler
TeacherNoteSchema.index({ student: 1, teacher: 1 });
TeacherNoteSchema.index({ student: 1, createdAt: -1 });
TeacherNoteSchema.index({ teacher: 1, createdAt: -1 });

// Öğrenci ve öğretmen kombinasyonu için compound index
TeacherNoteSchema.index({ student: 1, teacher: 1, createdAt: -1 });

module.exports = mongoose.models.TeacherNote || mongoose.model('TeacherNote', TeacherNoteSchema);

