// models/category.js

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const CategorySchema = new Schema({
    name: { 
        type: String, 
        required: [true, 'Kategori adı zorunludur.'], 
        unique: true 
    },
    description: String,
    
    // 💡 KRİTİK EKLENTİ: Bu kategorideki ilerleme akış tipini belirler.
    // Örn: 'Default' (%90 kuralı), 'Linear' (%100 kuralı), 'ScoreBased' (Skora dayalı)
    flowType: {
        type: String,
        enum: ['Default', 'Linear', 'ScoreBased'],
        default: 'Default',
        required: true
    },

    iconUrl: String 
    
}, {
    timestamps: true 
});

module.exports = mongoose.models.Category || mongoose.model('Category', CategorySchema);