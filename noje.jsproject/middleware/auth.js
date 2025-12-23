// middleware/auth.js - JWT Authentication Middleware

const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const User = require('../models/user');

// JWT token doğrulama middleware'i
exports.authenticate = async (req, res, next) => {
    try {
        // Token'ı header'dan al
        const authHeader = req.headers.authorization;
        
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ 
                message: 'Yetkilendirme hatası: Token bulunamadı.' 
            });
        }

        // "Bearer " kısmını çıkar
        const token = authHeader.substring(7);

        // Token'ı doğrula
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fallback-secret-key-change-in-production');

        // userId'yi kontrol et
        if (!decoded.userId) {
            return res.status(401).json({ 
                message: 'Yetkilendirme hatası: Token geçersiz - userId bulunamadı.' 
            });
        }

        // MongoDB ObjectId'ye dönüştür (eğer string ise)
        let userId = decoded.userId;
        if (typeof userId === 'string' && !mongoose.Types.ObjectId.isValid(userId)) {
            return res.status(401).json({ 
                message: 'Yetkilendirme hatası: Geçersiz kullanıcı ID formatı.' 
            });
        }

        // Kullanıcıyı bul
        const user = await User.findById(userId).select('-password');
        
        if (!user) {
            console.error('❌ Kullanıcı bulunamadı:');
            console.error('   - userId:', userId);
            console.error('   - userId type:', typeof userId);
            console.error('   - decoded.userId:', decoded.userId);
            console.error('   - decoded:', JSON.stringify(decoded, null, 2));
            
            // Alternatif olarak email ile de dene (eğer token'da email varsa)
            if (decoded.email) {
                const userByEmail = await User.findOne({ email: decoded.email }).select('-password');
                if (userByEmail) {
                    console.log('✅ Email ile kullanıcı bulundu, userId güncelleniyor...');
                    req.user = userByEmail;
                    return next();
                }
            }
            
            return res.status(401).json({ 
                message: 'Yetkilendirme hatası: Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.' 
            });
        }
        
        console.log('✅ Kullanıcı bulundu:', user.email, user.role);

        // Kullanıcıyı request'e ekle
        req.user = user;
        next();
    } catch (error) {
        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({ 
                message: 'Yetkilendirme hatası: Geçersiz token.' 
            });
        }
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({ 
                message: 'Yetkilendirme hatası: Token süresi dolmuş.' 
            });
        }
        res.status(500).json({ 
            message: 'Sunucu hatası: Token doğrulanamadı.', 
            error: error.message 
        });
    }
};

// Sadece öğretmenlere izin ver
exports.requireTeacher = (req, res, next) => {
    if (req.user && req.user.role === 'Teacher') {
        next();
    } else {
        res.status(403).json({ 
            message: 'Erişim reddedildi: Bu işlem için öğretmen yetkisi gereklidir.' 
        });
    }
};

// Sadece öğrencilere izin ver
exports.requireStudent = (req, res, next) => {
    if (req.user && req.user.role === 'Student') {
        next();
    } else {
        res.status(403).json({ 
            message: 'Erişim reddedildi: Bu işlem için öğrenci yetkisi gereklidir.' 
        });
    }
};

// Sadece adminlere izin ver (SuperAdmin de dahil)
exports.requireAdmin = (req, res, next) => {
    if (req.user && (req.user.role === 'Admin' || req.user.role === 'SuperAdmin')) {
        next();
    } else {
        res.status(403).json({ 
            message: 'Erişim reddedildi: Bu işlem için admin yetkisi gereklidir.' 
        });
    }
};

// Sadece SuperAdmin'e izin ver
exports.requireSuperAdmin = (req, res, next) => {
    if (req.user && req.user.role === 'SuperAdmin') {
        next();
    } else {
        res.status(403).json({ 
            message: 'Erişim reddedildi: Bu işlem için super admin yetkisi gereklidir.' 
        });
    }
};

