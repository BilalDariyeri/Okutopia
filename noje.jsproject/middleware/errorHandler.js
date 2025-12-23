// middleware/errorHandler.js - Merkezi Hata Yönetimi

const logger = require('../config/logger');

// Merkezi hata yakalama middleware'i
exports.errorHandler = (err, req, res, next) => {
    let error = { ...err };
    error.message = err.message;

    // Mongoose bad ObjectId
    if (err.name === 'CastError') {
        const message = 'Geçersiz ID formatı';
        error = { message, statusCode: 400 };
    }

    // Mongoose duplicate key
    if (err.code === 11000) {
        const field = Object.keys(err.keyValue)[0];
        const message = `${field} zaten kullanılıyor`;
        error = { message, statusCode: 400 };
    }

    // Mongoose validation error
    if (err.name === 'ValidationError') {
        const message = Object.values(err.errors).map(val => val.message).join(', ');
        error = { message, statusCode: 400 };
    }

    // JWT errors
    if (err.name === 'JsonWebTokenError') {
        const message = 'Geçersiz token';
        error = { message, statusCode: 401 };
    }

    if (err.name === 'TokenExpiredError') {
        const message = 'Token süresi dolmuş';
        error = { message, statusCode: 401 };
    }

    // Varsayılan hata
    const statusCode = error.statusCode || 500;
    const message = error.message || 'Sunucu hatası';

    // 💡 LOGGING: Hata detaylarını logla
    const errorLog = {
        message: err.message,
        stack: err.stack,
        path: req.path,
        method: req.method,
        ip: req.ip || req.connection.remoteAddress,
        userId: req.user ? req.user._id : null,
        statusCode: statusCode,
        body: req.body,
        query: req.query,
        params: req.params
    };

    // Status code'a göre log seviyesi
    if (statusCode >= 500) {
        logger.error('Application Error', errorLog);
    } else if (statusCode >= 400) {
        logger.warn('Client Error', errorLog);
    } else {
        logger.info('Error Handled', errorLog);
    }

    res.status(statusCode).json({
        success: false,
        message,
        ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    });
};

// 404 Not Found handler
exports.notFound = (req, res, next) => {
    const error = new Error(`Bulunamadı - ${req.originalUrl}`);
    error.statusCode = 404;
    next(error);
};

