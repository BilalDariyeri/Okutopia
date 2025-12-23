// scripts/checkUser.js - Kullanıcı bilgilerini kontrol et

require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const User = require('../models/user');
const bcrypt = require('bcryptjs');

const checkUser = async () => {
    try {
        await connectDB();

        const email = 'dariyeribilal3@gmail.com';
        const password = 'Sanane12bb.';

        console.log('🔍 Kullanıcı kontrol ediliyor...');
        
        // Email'i farklı şekillerde ara
        const user1 = await User.findOne({ email: email }).select('+password');
        const user2 = await User.findOne({ email: email.toLowerCase() }).select('+password');
        const user3 = await User.findOne({ email: email.trim().toLowerCase() }).select('+password');
        
        console.log('\n📧 Email arama sonuçları:');
        console.log('  - Orijinal email:', email);
        console.log('  - user1 (orijinal):', user1 ? 'BULUNDU' : 'BULUNAMADI');
        console.log('  - user2 (lowercase):', user2 ? 'BULUNDU' : 'BULUNAMADI');
        console.log('  - user3 (trim+lowercase):', user3 ? 'BULUNDU' : 'BULUNAMADI');
        
        const user = user1 || user2 || user3;
        
        if (!user) {
            console.log('\n❌ Kullanıcı hiçbir şekilde bulunamadı!');
            await mongoose.connection.close();
            process.exit(1);
        }

        console.log('\n✅ Kullanıcı bulundu:');
        console.log('  - Email (DB):', user.email);
        console.log('  - Role:', user.role);
        console.log('  - Has Password:', !!user.password);
        console.log('  - Password length:', user.password?.length);

        // Şifre kontrolü
        console.log('\n🔐 Şifre kontrol ediliyor...');
        const test1 = await user.comparePassword(password);
        const test2 = await bcrypt.compare(password, user.password);
        
        console.log('  - comparePassword:', test1);
        console.log('  - bcrypt.compare:', test2);
        
        if (!test1 && !test2) {
            console.log('\n❌ Şifre eşleşmedi!');
            console.log('  - Denenen şifre:', password);
        } else {
            console.log('\n✅ Şifre doğru!');
        }

        await mongoose.connection.close();
        process.exit(0);

    } catch (error) {
        console.error('❌ Hata:', error.message);
        await mongoose.connection.close();
        process.exit(1);
    }
};

checkUser();

