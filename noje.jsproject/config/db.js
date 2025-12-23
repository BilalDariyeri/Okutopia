// config/db.js
const mongoose = require('mongoose');
require('dotenv').config();
const logger = require('./logger');

const connectDB = async () => {
    try {
        const uri = process.env.MONGO_URI;

        if (!uri) {
            logger.error('HATA: MONGO_URI ortam değişkeni .env dosyasında tanımlı değil!');
            console.error('HATA: MONGO_URI ortam değişkeni .env dosyasında tanımlı değil!');
            process.exit(1); // Uygulamayı hemen sonlandır
        }

        logger.info('🔄 MongoDB bağlantısı kuruluyor...');
        
        // 💡 PERFORMANS: Connection pooling ayarları (yüksek trafik için)
        const conn = await mongoose.connect(uri, {
            maxPoolSize: 10, // Maksimum bağlantı sayısı
            minPoolSize: 5, // Minimum bağlantı sayısı
            serverSelectionTimeoutMS: 5000, // 5 saniye timeout
            socketTimeoutMS: 45000, // 45 saniye socket timeout
            family: 4 // IPv4 kullan
        });

        // Bağlantı başarılı olduğunda logla
        logger.info(`✅ MongoDB Bağlantısı Başarılı: ${conn.connection.host}`, {
            database: conn.connection.name,
            host: conn.connection.host
        });
        console.log(`MongoDB Bağlantısı Başarılı: ${conn.connection.host}`);
        
        // 💡 GRIDFS: GridFS'i başlat (dosya depolama için)
        const { initGridFS } = require('../utils/gridfs');
        initGridFS();
    } catch (error) {
        // Bağlantı başarısız olduğunda logla
        logger.error('MongoDB BAĞLANTI HATASI', {
            message: error.message,
            stack: error.stack
        });
        console.error(`MongoDB BAĞLANTI HATASI: Bağlantı dizesini kontrol edin. Hata Detayı: ${error.message}`);
        process.exit(1); // Uygulamayı hemen sonlandır
    }
};

module.exports = connectDB;
