// config/logger.js - Winston Logging Konfigürasyonu

const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');
const path = require('path');
const fs = require('fs');

// Logs klasörünü oluştur (yoksa)
const logsDir = path.join(__dirname, '../logs');
if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
}

// Log formatı tanımla
const logFormat = winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
);

// Console formatı (daha okunabilir)
const consoleFormat = winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.printf(({ timestamp, level, message, ...meta }) => {
        let msg = `${timestamp} [${level}]: ${message}`;
        if (Object.keys(meta).length > 0) {
            msg += ` ${JSON.stringify(meta)}`;
        }
        return msg;
    })
);

// Günlük rotasyonlu dosya transport'u (her gün yeni dosya)
const dailyRotateFileTransport = new DailyRotateFile({
    filename: path.join(logsDir, 'application-%DATE%.log'),
    datePattern: 'YYYY-MM-DD',
    zippedArchive: true, // Eski logları zip'le
    maxSize: '20m', // Maksimum dosya boyutu
    maxFiles: '14d', // 14 günlük log tut
    format: logFormat
});

// Hata logları için ayrı dosya
const errorFileTransport = new DailyRotateFile({
    filename: path.join(logsDir, 'error-%DATE%.log'),
    datePattern: 'YYYY-MM-DD',
    level: 'error', // Sadece error seviyesindeki loglar
    zippedArchive: true,
    maxSize: '20m',
    maxFiles: '30d', // Hata loglarını 30 gün tut
    format: logFormat
});

// Winston logger oluştur
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info', // LOG_LEVEL env değişkeni ile kontrol edilebilir
    format: logFormat,
    defaultMeta: { service: 'egitim-api' },
    transports: [
        // Console'a yaz (development'ta renkli, production'da sade)
        new winston.transports.Console({
            format: consoleFormat,
            level: process.env.NODE_ENV === 'production' ? 'info' : 'debug'
        }),
        // Günlük rotasyonlu dosya
        dailyRotateFileTransport,
        // Hata logları için ayrı dosya
        errorFileTransport
    ],
    // Exception ve rejection handler'ları
    exceptionHandlers: [
        new DailyRotateFile({
            filename: path.join(logsDir, 'exceptions-%DATE%.log'),
            datePattern: 'YYYY-MM-DD',
            zippedArchive: true,
            maxSize: '20m',
            maxFiles: '30d'
        })
    ],
    rejectionHandlers: [
        new DailyRotateFile({
            filename: path.join(logsDir, 'rejections-%DATE%.log'),
            datePattern: 'YYYY-MM-DD',
            zippedArchive: true,
            maxSize: '20m',
            maxFiles: '30d'
        })
    ]
});

// Production'da console'a yazmayı kapat (sadece dosyaya yaz)
if (process.env.NODE_ENV === 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple()
    }));
}

module.exports = logger;

