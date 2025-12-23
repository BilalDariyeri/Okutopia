// middleware/validators.js - Input Validation Middleware

const { body, validationResult } = require('express-validator');

// Validation hatalarını kontrol et
const validate = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            message: 'Geçersiz giriş verileri',
            errors: errors.array()
        });
    }
    next();
};

// Öğretmen kayıt validasyonu
exports.validateTeacherRegistration = [
    body('firstName')
        .trim()
        .notEmpty().withMessage('Ad alanı zorunludur')
        .isLength({ min: 2, max: 50 }).withMessage('Ad 2-50 karakter arasında olmalıdır'),
    
    body('lastName')
        .trim()
        .notEmpty().withMessage('Soyad alanı zorunludur')
        .isLength({ min: 2, max: 50 }).withMessage('Soyad 2-50 karakter arasında olmalıdır'),
    
    body('email')
        .trim()
        .notEmpty().withMessage('E-posta alanı zorunludur')
        .isEmail().withMessage('Geçerli bir e-posta adresi giriniz')
        .normalizeEmail(),
    
    body('password')
        .notEmpty().withMessage('Şifre alanı zorunludur')
        .isLength({ min: 6 }).withMessage('Şifre en az 6 karakter olmalıdır')
        .matches(/^(?=.*[A-Z])(?=.*\d)/)
        .withMessage('Şifre en az bir büyük harf ve bir rakam içermelidir (küçük harf isteğe bağlıdır)'),
    
    validate
];

// Öğrenci ekleme validasyonu (sadece firstName ve lastName - teacherId token'dan alınacak)
exports.validateStudent = [
    body('firstName')
        .trim()
        .notEmpty().withMessage('Ad alanı zorunludur')
        .isLength({ min: 2, max: 50 }).withMessage('Ad 2-50 karakter arasında olmalıdır'),
    
    body('lastName')
        .trim()
        .notEmpty().withMessage('Soyad alanı zorunludur')
        .isLength({ min: 2, max: 50 }).withMessage('Soyad 2-50 karakter arasında olmalıdır'),
    
    validate
];

// Login validasyonu
exports.validateLogin = [
    body('email')
        .trim()
        .notEmpty().withMessage('E-posta alanı zorunludur')
        .isEmail().withMessage('Geçerli bir e-posta adresi giriniz')
        .normalizeEmail(),
    
    body('password')
        .notEmpty().withMessage('Şifre alanı zorunludur'),
    
    validate
];

