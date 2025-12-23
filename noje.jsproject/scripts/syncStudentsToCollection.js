// scripts/syncStudentsToCollection.js
// Users koleksiyonundaki tüm Student'ları students koleksiyonuna ekler

const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/education-tracker';

async function syncStudentsToCollection() {
    try {
        console.log('🔄 MongoDB bağlantısı kuruluyor...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ MongoDB bağlantısı başarılı');

        const db = mongoose.connection.db;
        const usersCollection = db.collection('users');
        const studentsCollection = db.collection('students');

        // Users koleksiyonundaki tüm Student'ları bul
        const students = await usersCollection.find({ role: 'Student' }).toArray();
        console.log(`📊 Users koleksiyonunda ${students.length} adet Student bulundu`);

        let addedCount = 0;
        let updatedCount = 0;
        let skippedCount = 0;
        let errorCount = 0;

        for (const student of students) {
            try {
                const studentData = {
                    _id: student._id,
                    firstName: student.firstName,
                    lastName: student.lastName,
                    role: 'Student',
                    createdAt: student.createdAt || new Date(),
                    updatedAt: new Date()
                };

                // Önce mevcut kaydı kontrol et
                const existing = await studentsCollection.findOne({ _id: student._id });

                if (existing) {
                    // Mevcut kaydı güncelle
                    await studentsCollection.updateOne(
                        { _id: student._id },
                        { 
                            $set: { 
                                firstName: student.firstName,
                                lastName: student.lastName,
                                role: 'Student',
                                updatedAt: new Date()
                            }
                        }
                    );
                    updatedCount++;
                    console.log(`✅ Güncellendi: ${student.firstName} ${student.lastName} (${student._id})`);
                } else {
                    // Yeni kayıt ekle
                    await studentsCollection.insertOne(studentData);
                    addedCount++;
                    console.log(`➕ Eklendi: ${student.firstName} ${student.lastName} (${student._id})`);
                }
            } catch (error) {
                if (error.code === 11000) {
                    // Duplicate key - zaten var, atla
                    skippedCount++;
                    console.log(`⚠️ Zaten mevcut (atlandı): ${student.firstName} ${student.lastName} (${student._id})`);
                } else {
                    errorCount++;
                    console.error(`❌ Hata (${student.firstName} ${student.lastName}):`, error.message);
                }
            }
        }

        // Özet
        console.log('\n📊 ÖZET:');
        console.log(`   ➕ Yeni eklenen: ${addedCount}`);
        console.log(`   ✅ Güncellenen: ${updatedCount}`);
        console.log(`   ⚠️ Atlanan (zaten mevcut): ${skippedCount}`);
        console.log(`   ❌ Hata: ${errorCount}`);
        console.log(`   📝 Toplam işlenen: ${students.length}`);

        // Son durumu kontrol et
        const finalCount = await studentsCollection.countDocuments({ role: 'Student' });
        console.log(`\n📊 Students koleksiyonundaki Student sayısı: ${finalCount}`);

        console.log('\n✅ Senkronizasyon tamamlandı!');
        await mongoose.connection.close();
        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        await mongoose.connection.close();
        process.exit(1);
    }
}

syncStudentsToCollection();

