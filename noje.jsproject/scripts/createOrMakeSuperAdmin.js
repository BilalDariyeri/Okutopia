// scripts/createOrMakeSuperAdmin.js - Kullanıcıyı SuperAdmin Yap veya Oluştur

require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const User = require('../models/user');

const createOrMakeSuperAdmin = async () => {
    try {
        // MongoDB'ye bağlan
        await connectDB();

        const email = 'dariyeribilal3@gmail.com';
        const password = 'Sanane12bb.';
        const firstName = 'Dariye';
        const lastName = 'Rıbilal';

        console.log('🔍 Kullanıcı kontrol ediliyor...');
        
        // Kullanıcıyı bul
        let user = await User.findOne({ email: email.trim().toLowerCase() });
        
        if (!user) {
            console.log('📝 Kullanıcı bulunamadı, yeni SuperAdmin kullanıcısı oluşturuluyor...');
            
            // Yeni kullanıcı oluştur (User modeli otomatik hash'leyecek)
            user = await User.create({
                firstName,
                lastName,
                email: email.trim().toLowerCase(),
                password: password, // Pre-save hook otomatik hash'leyecek
                role: 'SuperAdmin'
            });
            
            console.log('✅ Yeni SuperAdmin kullanıcısı oluşturuldu!');
        } else {
            console.log('✅ Kullanıcı bulundu, SuperAdmin yapılıyor...');
            
            // Kullanıcıyı SuperAdmin yap ve şifreyi güncelle (pre-save hook otomatik hash'leyecek)
            user.role = 'SuperAdmin';
            user.password = password; // Pre-save hook otomatik hash'leyecek
            user.firstName = firstName;
            user.lastName = lastName;
            await user.save();
            
            console.log('✅ Kullanıcı SuperAdmin yapıldı ve şifre güncellendi!');
        }

        console.log('\n✅ İşlem başarılı!');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`👤 Ad Soyad: ${user.firstName} ${user.lastName}`);
        console.log(`📧 E-posta: ${user.email}`);
        console.log(`👑 Rol: ${user.role}`);
        console.log(`🔑 Şifre: ${password}`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('\n💡 Artık bu bilgilerle giriş yapabilirsiniz:');
        console.log(`   📱 Flutter Uygulaması: E-posta ve şifre ile giriş`);
        console.log(`   🌐 Admin Panel: http://localhost:${process.env.PORT || 3000}/admin`);
        console.log(`   📧 E-posta: ${user.email}`);
        console.log(`   🔑 Şifre: ${password}\n`);

        // Bağlantıyı kapat
        await mongoose.connection.close();
        process.exit(0);

    } catch (error) {
        console.error('❌ Hata:', error.message);
        console.error('Stack:', error.stack);
        await mongoose.connection.close();
        process.exit(1);
    }
};

// Script'i çalıştır
createOrMakeSuperAdmin();

