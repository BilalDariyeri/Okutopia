const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const ClassroomSchema = new Schema({
    name: {
        type: String,
        required: [true, 'Sınıf adı zorunludur.'],
        trim: true
    },
    teacher: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    students: [{
        type: Schema.Types.ObjectId,
        ref: 'User'
    }]
}, {
    timestamps: true
});

// 💡 PERFORMANS: Database Indexing (uzun vadede kritik)
// Öğretmen bazlı sorgular için index (getTeacherClassrooms için)
ClassroomSchema.index({ teacher: 1 });
// Öğrenci aramaları için index (students array içinde arama)
ClassroomSchema.index({ students: 1 });

// 💡 KRİTİK DÜZELTME: Modeli yeniden tanımlama hatasını (OverwriteModelError) çözer.
// Eğer 'Classroom' modeli zaten tanımlıysa onu kullan, değilse yeni tanımla.
module.exports = mongoose.models.Classroom 
  ? mongoose.model('Classroom') 
  : mongoose.model('Classroom', ClassroomSchema);