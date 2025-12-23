// scripts/createAdmin.js - İlk Admin Kullanıcısı Oluşturma Scripti

require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const User = require('../models/user');

const createAdmin = async () => {
    try {
        // MongoDB'ye bağlan
        await connectDB();

        // Admin bilgileri (komut satırından al veya varsayılan kullan)
        const args = process.argv.slice(2);
        let email = args[0] || 'admin@example.com';
        let password = args[1] || 'admin123';
        let firstName = args[2] || 'Admin';
        let lastName = args[3] || 'User';

        // Eğer email parametresi olarak '--interactive' gelirse interaktif mod
        if (email === '--interactive' || email === '-i') {
            const readline = require('readline');
            const rl = readline.createInterface({
                input: process.stdin,
                output: process.stdout
            });

            const question = (query) => new Promise(resolve => rl.question(query, resolve));

            firstName = await question('Ad: ') || 'Admin';
            lastName = await question('Soyad: ') || 'User';
            email = await question('E-posta: ') || 'admin@example.com';
            password = await question('Şifre: ') || 'admin123';

            rl.close();
        }

        // Email kontrolü
        const existingAdmin = await User.findOne({ email });
        if (existingAdmin) {
            console.log('❌ Bu e-posta adresi zaten kullanılıyor!');
            console.log(`   Mevcut kullanıcı: ${existingAdmin.firstName} ${existingAdmin.lastName} (${existingAdmin.role})`);
            process.exit(1);
        }

        // Admin kullanıcısı oluştur
        const admin = await User.create({
            firstName,
            lastName,
            email,
            password, // User modeli otomatik hash'leyecek
            role: 'Admin'
        });

        console.log('\n✅ Admin kullanıcısı başarıyla oluşturuldu!');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`👤 Ad Soyad: ${admin.firstName} ${admin.lastName}`);
        console.log(`📧 E-posta: ${admin.email}`);
        console.log(`🔑 Şifre: ${password}`);
        console.log(`👑 Rol: ${admin.role}`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('\n💡 Admin paneline giriş yapmak için:');
        console.log(`   URL: http://localhost:${process.env.PORT || 3000}/admin`);
        console.log(`   E-posta: ${admin.email}`);
        console.log(`   Şifre: ${password}\n`);

        // Bağlantıyı kapat
        await mongoose.connection.close();
        process.exit(0);

    } catch (error) {
        console.error('❌ Hata:', error.message);
        if (error.code === 11000) {
            console.error('   Bu e-posta adresi zaten kayıtlı!');
        }
        await mongoose.connection.close();
        process.exit(1);
    }
};

// Script'i çalıştır
createAdmin();

