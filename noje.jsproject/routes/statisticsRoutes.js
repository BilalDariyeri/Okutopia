// routes/statisticsRoutes.js - İstatistik Route'ları

const express = require('express');
const router = express.Router();
const statisticsController = require('../controllers/statisticsController');
const { authenticate, requireTeacher } = require('../middleware/auth');

/**
 * @swagger
 * tags:
 * - name: Statistics
 *   description: Öğrenci İstatistik Takibi ve Email Gönderimi
 */

/**
 * @swagger
 * /api/statistics/start-session:
 *   post:
 *     summary: Öğrenci Oturumu Başlatma (Otomatik)
 *     tags: [Statistics]
 *     description: |
 *       Öğrencinin uygulamada geçirdiği süreyi takip etmek için oturum başlatır.
 *       Frontend'de öğrenci giriş yaptığında otomatik olarak çağrılmalıdır.
 *       Genel ekran süresi sağ üstte görüntülenir.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - studentId
 *             properties:
 *               studentId:
 *                 type: string
 *                 description: Öğrenci ID'si
 *     responses:
 *       '201':
 *         description: Oturum başarıyla başlatıldı
 *       '400':
 *         description: Geçersiz istek
 *       '404':
 *         description: Öğrenci bulunamadı
 */
router.post('/start-session', statisticsController.startSession);

/**
 * @swagger
 * /api/statistics/end-session:
 *   post:
 *     summary: Öğrenci Oturumu Bitirme
 *     tags: [Statistics]
 *     description: Öğrencinin oturumunu bitirir ve günlük istatistikleri günceller
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - studentId
 *             properties:
 *               studentId:
 *                 type: string
 *                 description: Öğrenci ID'si
 *     responses:
 *       '200':
 *         description: Oturum başarıyla bitirildi
 *       '404':
 *         description: Aktif oturum bulunamadı
 */
router.post('/end-session', statisticsController.endSession);

/**
 * @swagger
 * /api/statistics/student/{studentId}:
 *   get:
 *     summary: Öğrenci İstatistiklerini Getirme
 *     tags: [Statistics]
 *     description: Öğrencinin günlük ve toplam istatistiklerini getirir
 *     parameters:
 *       - in: path
 *         name: studentId
 *         required: true
 *         schema:
 *           type: string
 *         description: Öğrenci ID'si
 *       - in: query
 *         name: date
 *         schema:
 *           type: string
 *           format: date
 *         description: İstatistiklerin alınacağı tarih (opsiyonel, varsayılan bugün)
 *     responses:
 *       '200':
 *         description: İstatistikler başarıyla getirildi
 *       '404':
 *         description: Öğrenci bulunamadı
 */
router.get('/student/:studentId', statisticsController.getStudentStatistics);

/**
 * @swagger
 * /api/statistics/student/{studentId}/parent-email:
 *   put:
 *     summary: Veli Email Adresini Güncelleme
 *     tags: [Statistics]
 *     description: Öğrencinin veli e-posta adresini günceller
 *     parameters:
 *       - in: path
 *         name: studentId
 *         required: true
 *         schema:
 *           type: string
 *         description: Öğrenci ID'si
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               parentEmail:
 *                 type: string
 *                 format: email
 *                 description: Veli e-posta adresi
 *     responses:
 *       '200':
 *         description: Veli e-posta adresi başarıyla güncellendi
 *       '400':
 *         description: Geçersiz e-posta formatı
 *       '404':
 *         description: Öğrenci bulunamadı
 */
router.put('/student/:studentId/parent-email', statisticsController.updateParentEmail);

/**
 * @swagger
 * /api/statistics/student/{studentId}/send-email:
 *   post:
 *     summary: İstatistikleri Veliye Email Olarak Gönderme
 *     tags: [Statistics]
 *     description: Öğrencinin günlük istatistiklerini veliye e-posta olarak gönderir
 *     parameters:
 *       - in: path
 *         name: studentId
 *         required: true
 *         schema:
 *           type: string
 *         description: Öğrenci ID'si
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               parentEmail:
 *                 type: string
 *                 format: email
 *                 description: Veli e-posta adresi (opsiyonel, öğrenci kaydından alınır)
 *     responses:
 *       '200':
 *         description: Email başarıyla gönderildi
 *       '400':
 *         description: Email adresi bulunamadı veya gönderilecek istatistik yok
 *       '404':
 *         description: Öğrenci bulunamadı
 */
router.post('/student/:studentId/send-email', authenticate, requireTeacher, statisticsController.sendStatisticsEmail);

/**
 * @swagger
 * /api/statistics/start-reading:
 *   post:
 *     summary: Okuma Süresi Başlatma (Öğretmen Tarafından)
 *     tags: [Statistics]
 *     description: Öğretmen öğrencinin okuma süresini takip etmek için okuma oturumu başlatır
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - studentId
 *               - activityId
 *             properties:
 *               studentId:
 *                 type: string
 *                 description: Öğrenci ID'si
 *               activityId:
 *                 type: string
 *                 description: Aktivite ID'si
 *     responses:
 *       '201':
 *         description: Okuma oturumu başarıyla başlatıldı
 *       '401':
 *         description: Yetkilendirme hatası
 *       '403':
 *         description: Öğretmen yetkisi gerekli
 *       '404':
 *         description: Öğrenci veya aktivite bulunamadı
 */
router.post('/start-reading', authenticate, requireTeacher, statisticsController.startReading);

/**
 * @swagger
 * /api/statistics/end-reading:
 *   post:
 *     summary: Okuma Süresi Bitirme
 *     tags: [Statistics]
 *     description: Öğrencinin okuma oturumunu bitirir ve okuma istatistiklerini günceller
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - studentId
 *               - activityId
 *             properties:
 *               studentId:
 *                 type: string
 *                 description: Öğrenci ID'si
 *               activityId:
 *                 type: string
 *                 description: Aktivite ID'si
 *               wordCount:
 *                 type: number
 *                 description: Okunan kelime sayısı
 *     responses:
 *       '200':
 *         description: Okuma oturumu başarıyla bitirildi
 *       '404':
 *         description: Aktif okuma oturumu bulunamadı
 */
router.post('/end-reading', statisticsController.endReading);

/**
 * @swagger
 * /api/statistics/teacher/students:
 *   get:
 *     summary: Öğretmenin Öğrencilerini Getirme
 *     tags: [Statistics]
 *     description: Öğretmenin sınıflarındaki tüm öğrencileri getirir (Classroom'dan)
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '200':
 *         description: Öğrenciler başarıyla getirildi
 *       '401':
 *         description: Yetkilendirme hatası
 *       '403':
 *         description: Öğretmen yetkisi gerekli
 */
router.get('/teacher/students', authenticate, requireTeacher, statisticsController.getTeacherStudents);

/**
 * @swagger
 * /api/statistics/teacher/student/{studentId}:
 *   get:
 *     summary: Öğretmenin Öğrenci İstatistiklerini Görüntüleme
 *     tags: [Statistics]
 *     description: |
 *       Öğretmen bir öğrencinin istatistiklerini görüntüler (email göndermek için).
 *       Varsayılan olarak günlük veri gösterilir. period=weekly parametresi ile son 7 günün verileri görüntülenebilir.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: studentId
 *         required: true
 *         schema:
 *           type: string
 *         description: Öğrenci ID'si
 *       - in: query
 *         name: date
 *         schema:
 *           type: string
 *           format: date
 *         description: İstatistiklerin alınacağı tarih (opsiyonel, varsayılan bugün)
 *       - in: query
 *         name: period
 *         schema:
 *           type: string
 *           enum: [daily, weekly]
 *         description: Görüntüleme periyodu - 'daily' (varsayılan, günlük) veya 'weekly' (son 7 gün)
 *     responses:
 *       '200':
 *         description: İstatistikler başarıyla getirildi
 *       '401':
 *         description: Yetkilendirme hatası
 *       '403':
 *         description: Öğretmen yetkisi gerekli
 *       '404':
 *         description: Öğrenci bulunamadı
 */
router.get('/teacher/student/:studentId', authenticate, requireTeacher, statisticsController.getStudentStatisticsForTeacher);

module.exports = router;

