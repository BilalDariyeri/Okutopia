// middleware/rateLimiter.js - Rate Limiting Middleware

const rateLimit = require('express-rate-limit');
const logger = require('../config/logger');

// Genel API rate limiter (tüm endpoint'ler için)
// 🔒 SECURITY: Rate limiting aktif - DDoS koruması
const generalLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 dakika
    max: process.env.RATE_LIMIT_MAX_REQUESTS ? parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) : 2000, // Environment'dan al veya varsayılan 2000 (20x artırıldı)
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
// 🔒 SECURITY: Rate limiting aktif - Brute force koruması
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 dakika
    max: process.env.RATE_LIMIT_LOGIN_MAX ? parseInt(process.env.RATE_LIMIT_LOGIN_MAX) : 50, // Environment'dan al veya varsayılan 50 (10x artırıldı)
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
// 🔒 SECURITY: Rate limiting aktif - Spam koruması
const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 saat
    max: process.env.RATE_LIMIT_REGISTER_MAX ? parseInt(process.env.RATE_LIMIT_REGISTER_MAX) : 20, // Environment'dan al veya varsayılan 20 (yaklaşık 7x artırıldı)
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
// 🔒 SECURITY: Rate limiting aktif - API abuse koruması
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 dakika
    max: process.env.RATE_LIMIT_API_MAX ? parseInt(process.env.RATE_LIMIT_API_MAX) : 5000, // Environment'dan al veya varsayılan 5000 (25x artırıldı)
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

