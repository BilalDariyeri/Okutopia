// middleware/rateLimiter.js - Rate Limiting Middleware

const rateLimit = require('express-rate-limit');
const logger = require('../config/logger');

// Genel API rate limiter (tüm endpoint'ler için)
const generalLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 dakika
    max: 100, // Her IP için 15 dakikada maksimum 100 istek
    message: {
        success: false,
        message: 'Çok fazla istek gönderildi. Lütfen 15 dakika sonra tekrar deneyin.'
    },
    standardHeaders: true, // Rate limit bilgilerini `RateLimit-*` header'larında döndür
    legacyHeaders: false, // `X-RateLimit-*` header'larını devre dışı bırak
    handler: (req, res) => {
        logger.warn('Rate limit aşıldı', {
            ip: req.ip,
            url: req.url,
            method: req.method
        });
        res.status(429).json({
            success: false,
            message: 'Çok fazla istek gönderildi. Lütfen 15 dakika sonra tekrar deneyin.'
        });
    }
});

// Login endpoint için özel rate limiter (admin login için daha esnek)
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 dakika
    max: 30, // Her IP için 15 dakikada maksimum 30 login denemesi (artırıldı)
    message: {
        success: false,
        message: 'Çok fazla giriş denemesi. Lütfen 15 dakika sonra tekrar deneyin.'
    },
    skipSuccessfulRequests: true, // Başarılı istekleri sayma (sadece başarısız denemeler sayılır)
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
        logger.warn('Login rate limit aşıldı', {
            ip: req.ip,
            email: req.body?.email,
            url: req.url
        });
        res.status(429).json({
            success: false,
            message: 'Çok fazla giriş denemesi. Lütfen 15 dakika sonra tekrar deneyin.'
        });
    }
});

// Register endpoint için özel rate limiter
const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 saat
    max: 3, // Her IP için 1 saatte maksimum 3 kayıt
    message: {
        success: false,
        message: 'Çok fazla kayıt denemesi. Lütfen 1 saat sonra tekrar deneyin.'
    },
    handler: (req, res) => {
        logger.warn('Register rate limit aşıldı', {
            ip: req.ip,
            email: req.body.email,
            url: req.url
        });
        res.status(429).json({
            success: false,
            message: 'Çok fazla kayıt denemesi. Lütfen 1 saat sonra tekrar deneyin.'
        });
    }
});

// API endpoint'leri için rate limiter (daha yüksek limit)
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 dakika
    max: 200, // Authenticated kullanıcılar için daha yüksek limit
    message: {
        success: false,
        message: 'API rate limit aşıldı. Lütfen daha sonra tekrar deneyin.'
    },
    standardHeaders: true,
    legacyHeaders: false
});

module.exports = {
    generalLimiter,
    loginLimiter,
    registerLimiter,
    apiLimiter
};

