// scripts/makeSuperAdmin.js - Kullanıcıyı SuperAdmin Yapma Scripti

require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const User = require('../models/user');

const makeSuperAdmin = async () => {
    try {
        // MongoDB'ye bağlan
        await connectDB();

        // Email parametresini al
        const args = process.argv.slice(2);
        let email = args[0];

        // Eğer email verilmemişse interaktif mod
        if (!email || email === '--interactive' || email === '-i') {
            const readline = require('readline');
            const rl = readline.createInterface({
                input: process.stdin,
                output: process.stdout
            });

            const question = (query) => new Promise(resolve => rl.question(query, resolve));

            email = await question('SuperAdmin yapmak istediğiniz kullanıcının e-posta adresini girin: ');

            if (!email) {
                console.log('❌ E-posta adresi boş olamaz!');
                rl.close();
                await mongoose.connection.close();
                process.exit(1);
            }

            rl.close();
        }

        // Kullanıcıyı bul
        const user = await User.findOne({ email });
        
        if (!user) {
            console.log(`❌ E-posta adresi "${email}" ile kayıtlı kullanıcı bulunamadı!`);
            await mongoose.connection.close();
            process.exit(1);
        }

        // Zaten SuperAdmin mi kontrol et
        if (user.role === 'SuperAdmin') {
            console.log(`\n✅ "${user.firstName} ${user.lastName}" zaten SuperAdmin!`);
            console.log(`   E-posta: ${user.email}`);
            console.log(`   Mevcut Rol: ${user.role}\n`);
            await mongoose.connection.close();
            process.exit(0);
        }

        // Kullanıcıyı SuperAdmin yap
        const oldRole = user.role;
        user.role = 'SuperAdmin';
        await user.save();

        console.log('\n✅ Kullanıcı başarıyla SuperAdmin yapıldı!');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`👤 Ad Soyad: ${user.firstName} ${user.lastName}`);
        console.log(`📧 E-posta: ${user.email}`);
        console.log(`🔄 Eski Rol: ${oldRole}`);
        console.log(`👑 Yeni Rol: ${user.role}`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('\n💡 Artık bu kullanıcı ile admin paneline giriş yapabilirsiniz!');
        console.log(`   URL: http://localhost:${process.env.PORT || 3000}/admin\n`);

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
makeSuperAdmin();

