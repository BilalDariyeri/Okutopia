// scripts/cleanStudentsCollection.js
// Students koleksiyonundaki öğretmenleri temizler

const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

async function cleanStudentsCollection() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        const db = mongoose.connection.db;
        const studentsCollection = db.collection('students');

        // Öğretmenleri bul
        const teachers = await studentsCollection.find({ role: { $in: ['Teacher', 'Admin', 'SuperAdmin'] } }).toArray();
        console.log(`📊 Bulunan öğretmen/admin sayısı: ${teachers.length}`);

        if (teachers.length > 0) {
            // Öğretmenleri sil
            const result = await studentsCollection.deleteMany({ role: { $in: ['Teacher', 'Admin', 'SuperAdmin'] } });
            console.log(`✅ ${result.deletedCount} öğretmen/admin students koleksiyonundan silindi`);
        } else {
            console.log('ℹ️ Students koleksiyonunda öğretmen/admin bulunamadı');
        }

        // Sadece Student role'üne sahip kayıtları kontrol et
        const students = await studentsCollection.find({ role: 'Student' }).toArray();
        console.log(`📊 Students koleksiyonundaki öğrenci sayısı: ${students.length}`);

        // Role'ü olmayan veya geçersiz role'e sahip kayıtları bul
        const invalidRoles = await studentsCollection.find({ 
            $or: [
                { role: { $exists: false } },
                { role: { $nin: ['Student'] } }
            ]
        }).toArray();
        
        if (invalidRoles.length > 0) {
            console.log(`⚠️ Geçersiz role'e sahip ${invalidRoles.length} kayıt bulundu`);
            console.log('Örnek kayıtlar:', invalidRoles.slice(0, 3).map(r => ({ _id: r._id, role: r.role })));
        }

        console.log('✅ Temizleme işlemi tamamlandı');
        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

cleanStudentsCollection();

