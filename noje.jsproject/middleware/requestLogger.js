// middleware/requestLogger.js - HTTP Request Logging Middleware

const morgan = require('morgan');
const logger = require('../config/logger');

// Morgan için custom format
const morganFormat = ':method :url :status :response-time ms - :res[content-length] - :remote-addr';

// Morgan stream (Winston'a yönlendirme)
const morganStream = {
    write: (message) => {
        // Morgan'dan gelen mesajı temizle ve logla
        const cleanMessage = message.trim();
        logger.info(cleanMessage, { type: 'http' });
    }
};

// Development için renkli ve detaylı format
const devFormat = morgan(morganFormat, {
    stream: morganStream,
    skip: (req, res) => {
        // Swagger UI isteklerini loglama
        return req.url.startsWith('/api-docs');
    }
});

// Production için sadeleştirilmiş format
const prodFormat = morgan('combined', {
    stream: morganStream,
    skip: (req, res) => {
        return req.url.startsWith('/api-docs');
    }
});

// Request logging middleware
const requestLogger = process.env.NODE_ENV === 'production' ? prodFormat : devFormat;

// Manuel request logging fonksiyonu (daha fazla kontrol için)
exports.logRequest = (req, res, next) => {
    const startTime = Date.now();
    
    // Response tamamlandığında logla
    res.on('finish', () => {
        const duration = Date.now() - startTime;
        const logData = {
            method: req.method,
            url: req.url,
            status: res.statusCode,
            duration: `${duration}ms`,
            ip: req.ip || req.connection.remoteAddress,
            userAgent: req.get('user-agent'),
            userId: req.user ? req.user._id : null
        };

        // Status code'a göre log seviyesi
        if (res.statusCode >= 500) {
            logger.error('HTTP Request', logData);
        } else if (res.statusCode >= 400) {
            logger.warn('HTTP Request', logData);
        } else {
            logger.info('HTTP Request', logData);
        }
    });

    next();
};

module.exports = requestLogger;

