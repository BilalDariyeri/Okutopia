// models/user.js

const mongoose = require('mongoose');
const Schema = mongoose.Schema;
const bcrypt = require('bcryptjs');

// Bu şema hem Öğretmen hem de Öğrenci rollerini tutar
const UserSchema = new Schema({
    // Temel Kimlik Bilgileri
    firstName: { 
        type: String, 
        required: [true, 'Ad alanı zorunludur.'], 
        trim: true 
    },
    lastName: { 
        type: String, 
        required: [true, 'Soyad alanı zorunludur.'], 
        trim: true 
    },

    // Rol ayrımı (SuperAdmin, Admin, Teacher veya Student)
    role: {
        type: String,
        enum: ['SuperAdmin', 'Admin', 'Teacher', 'Student'], 
        default: 'Student'
    },
    
    // 💡 Öğrenci için özel alanlar
    courses: [{
        type: Schema.Types.ObjectId,
        ref: 'Classroom'
    }],
    // 💡 İSTATİSTİK: Öğrenci için veli email adresi
    parentEmail: {
        type: String,
        trim: true,
        lowercase: true,
        validate: {
            validator: function(v) {
                // Sadece öğrenci rolünde email gerekirse kontrol et
                if (this.role === 'Student' && v) {
                    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
                }
                return true; // Diğer rollerde veya boşsa geçerli
            },
            message: 'Geçerli bir e-posta adresi giriniz.'
        }
    },
    // 💡 VERİTABANI OPTİMİZASYONU: Son oturum istatistikleri (overwrite mantığı)
    lastSessionStats: {
        totalDurationSeconds: {
            type: Number,
            default: 0
        },
        activities: [{
            activityId: {
                type: Schema.Types.ObjectId,
                ref: 'Activity'
            },
            activityTitle: {
                type: String,
                default: ''
            },
            durationSeconds: {
                type: Number,
                default: 0
            },
            completedAt: {
                type: Date,
                default: Date.now
            },
            successStatus: {
                type: String,
                default: null
            }
        }],
        sessionStartTime: {
            type: Date,
            default: null
        },
        lastUpdated: {
            type: Date,
            default: Date.now
        }
    },
    
    // 💡 KRİTİK DÜZELTME: Öğretmen, Admin ve SuperAdmin'e özel alanlar
    email: {
        type: String,
        // Sadece role 'Teacher', 'Admin' veya 'SuperAdmin' ise zorunludur
        required: function() { return this.role === 'Teacher' || this.role === 'Admin' || this.role === 'SuperAdmin'; }, 
        unique: true,
        sparse: true // Sadece email değeri olanlar için unique (null değerler için çakışma olmaz)
    },
    password: {
        type: String,
        // Sadece role 'Teacher', 'Admin' veya 'SuperAdmin' ise zorunludur
        required: function() { return this.role === 'Teacher' || this.role === 'Admin' || this.role === 'SuperAdmin'; },
        select: false // Şifrenin sorgularda otomatik gelmesini engeller
    },
    // 💡 EMAIL: Email göndermek için kullanıcının Gmail App Password'ü (opsiyonel)
    emailAppPassword: {
        type: String,
        select: false, // Güvenlik için sorgularda otomatik gelmesini engeller
        default: null
    }
}, {
    timestamps: true 
});

// 💡 GÜVENLİK: Şifreyi kaydetmeden önce hash'le
UserSchema.pre('save', async function(next) {
    // Sadece şifre değiştiyse veya yeni kullanıcıysa hash'le
    if (!this.isModified('password') || !this.password) {
        return next();
    }
    
    try {
        // Şifreyi hash'le (10 salt rounds)
        const salt = await bcrypt.genSalt(10);
        this.password = await bcrypt.hash(this.password, salt);
        next();
    } catch (error) {
        next(error);
    }
});

// 💡 GÜVENLİK: Şifre karşılaştırma metodu
UserSchema.methods.comparePassword = async function(candidatePassword) {
    if (!this.password) {
        return false;
    }
    return await bcrypt.compare(candidatePassword, this.password);
};

// 💡 PERFORMANS: Database Indexing (uzun vadede kritik)
// Email zaten unique ama index olarak da tanımlı (otomatik)
// Role bazlı sorgular için index
UserSchema.index({ role: 1 });
// Email ve role kombinasyonu için compound index (login sorguları için)
UserSchema.index({ email: 1, role: 1 });

// OverwriteModelError hatasını önlemek için güvenli model tanımı
module.exports = mongoose.models.User || mongoose.model('User', UserSchema);

