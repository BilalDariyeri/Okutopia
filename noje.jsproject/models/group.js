const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const GroupSchema = new Schema({
    name: { 
        type: String, 
        required: [true, 'Grup adı zorunludur.'] 
    },
    
    // KRİTİK İLİŞKİ: Hangi kategoriye ait olduğunu belirtir
    category: {
        type: Schema.Types.ObjectId,
        ref: 'Category',
        required: true
    },
    
    // KRİTİK ALAN: Kategori içindeki sırasını belirler (Kilit açma sırası için)
    orderIndex: { 
        type: Number, 
        required: true,
        default: 0 
    },
    
    // 💡 EKLENTİ: Grup Tipi (Soru tipi gibi)
    groupType: {
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
// Kategori bazlı sorgular için index
GroupSchema.index({ category: 1 });
// Kategori ve orderIndex kombinasyonu için compound index (sıralama sorguları için)
GroupSchema.index({ category: 1, orderIndex: 1 });

// Modeli yeniden tanımlamayı engeller (Hata çözümü için kritik)
module.exports = mongoose.models.Group || mongoose.model('Group', GroupSchema);