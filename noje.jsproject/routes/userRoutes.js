// routes/userRoutes.js

const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { validateTeacherRegistration, validateLogin, validateStudent } = require('../middleware/validators');
const { loginLimiter } = require('../middleware/rateLimiter'); // 💡 GÜVENLİK: Login rate limiter

/**
 * @swagger
 * tags:
 *   - name: Users
 *     description: Öğretmen ve Temel Kullanıcı İşlemleri
 */

/**
 * @swagger
 * /api/users/register/teacher:
 *   post:
 *     summary: Yeni Öğretmen Kaydı ve Otomatik Sınıf Oluşturma
 *     tags: [Users]
 *     description: Yeni bir öğretmeni sisteme kaydeder, otomatik sınıf oluşturur.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/TeacherRegistration'
 *     responses:
 *       '201':
 *         description: Öğretmen başarıyla kaydedildi ve sınıf oluşturuldu.
 *         content:
 *           application/json:
 *             schema:
 *               type: 'object'
 *               properties:
 *                 success:
 *                   type: 'boolean'
 *                   example: true
 *                 message:
 *                   type: 'string'
 *                   example: 'Öğretmen başarıyla kaydedildi ve sınıf oluşturuldu.'
 *                 token:
 *                   type: 'string'
 *                   description: JWT token
 *                 teacher:
 *                   type: object
 *                   properties:
 *                     firstName:
 *                       type: string
 *                       example: 'Ahmet'
 *                     lastName:
 *                       type: string
 *                       example: 'Yılmaz'
 *                 classroom:
 *                   $ref: '#/components/schemas/Classroom'
 *             example:
 *               success: true
 *               message: 'Öğretmen başarıyla kaydedildi ve sınıf oluşturuldu.'
 *               token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
 *               teacher:
 *                 firstName: 'Ahmet'
 *                 lastName: 'Yılmaz'
 *               classroom:
 *                 id: '507f1f77bcf86cd799439012'
 *                 name: "Ahmet Yılmaz'ın Sınıfı"
 *       '400':
 *         description: Geçersiz istek verisi veya e-posta zaten kayıtlı.
 */
/**
 * @swagger
 * /api/users/login:
 *   post:
 *     summary: Öğretmen Girişi
 *     tags: [Users]
 *     description: Öğretmen girişi yapar ve JWT token döner.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: ahmet.yilmaz@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: securePassword123
 *     responses:
 *       '200':
 *         description: Giriş başarılı, token döndürüldü.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 token:
 *                   type: string
 *                 user:
 *                   type: object
 *                   properties:
 *                     firstName:
 *                       type: string
 *                       example: 'Ahmet'
 *                     lastName:
 *                       type: string
 *                       example: 'Yılmaz'
 *                 classroom:
 *                   $ref: '#/components/schemas/Classroom'
 *                   nullable: true
 *             example:
 *               success: true
 *               message: 'Giriş başarılı.'
 *               token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
 *               user:
 *                 firstName: 'Ahmet'
 *                 lastName: 'Yılmaz'
 *               classroom:
 *                 id: '507f1f77bcf86cd799439012'
 *                 name: "Ahmet Yılmaz'ın Sınıfı"
 *                 teacher:
 *                   firstName: 'Ahmet'
 *                   lastName: 'Yılmaz'
 *                 students: []
 *       '401':
 *         description: Geçersiz e-posta veya şifre.
 */
// 💡 GÜVENLİK: Login için özel rate limiter (15 dakikada 5 deneme)
router.post('/login', loginLimiter, validateLogin, userController.login);

// Register endpoint - Rate limit kaldırıldı (sadece genel rate limit geçerli)
router.post('/register/teacher', validateTeacherRegistration, userController.registerTeacherAndCreateClass);

/**
 * @swagger
 * /api/users/add-student:
 *   post:
 *     summary: Öğretmenin kendi sınıfına öğrenci ekleme (Otomatik sınıf bulma)
 *     tags: [Users]
 *     description: Öğretmen sadece öğrencinin adını ve soyadını gönderir. Sistem otomatik olarak token'dan öğretmen ID'sini alır ve öğretmenin sınıfını bulup öğrenciyi ekler.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - firstName
 *               - lastName
 *             properties:
 *               firstName:
 *                 type: string
 *                 minLength: 2
 *                 maxLength: 50
 *               lastName:
 *                 type: string
 *                 minLength: 2
 *                 maxLength: 50
 *             additionalProperties: false
 *           examples:
 *             default:
 *               value:
 *                 firstName: "Mehmet"
 *                 lastName: "Demir"
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '201':
 *         description: Öğrenci başarıyla oluşturuldu ve öğretmenin sınıfına eklendi.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 student:
 *                   type: object
 *                   properties:
 *                     firstName:
 *                       type: string
 *                     lastName:
 *                       type: string
 *             example:
 *               success: true
 *               message: "Öğrenci başarıyla kaydedildi ve sınıfa eklendi."
 *               student:
 *                 firstName: "Mehmet"
 *                 lastName: "Demir"
 *       '400':
 *         description: Geçersiz veri (firstName veya lastName eksik/hatalı)
 *       '401':
 *         description: Token bulunamadı veya geçersiz
 *       '404':
 *         description: Öğretmenin sınıfı bulunamadı
 */
// Öğretmenin kendi sınıfına öğrenci ekleme (otomatik sınıf bulma)
router.post('/add-student', validateStudent, userController.addStudentToMyClassroom);

module.exports = router;
