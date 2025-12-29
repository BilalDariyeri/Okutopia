// routes/adminRoutes.js - Admin Panel Routes

const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { authenticate, requireAdmin } = require('../middleware/auth');
const { loginLimiter } = require('../middleware/rateLimiter');

/**
 * @swagger
 * tags:
 *   - name: Admin
 *     description: Admin Panel İşlemleri
 */

/**
 * @swagger
 * /api/admin/login:
 *   post:
 *     summary: Admin Girişi
 *     tags: [Admin]
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
 *               password:
 *                 type: string
 *                 format: password
 *     responses:
 *       '200':
 *         description: Giriş başarılı
 *       '401':
 *         description: Geçersiz kimlik bilgileri
 *       '403':
 *         description: Admin yetkisi gerekli
 */
// 💡 DEV: Rate limiting devre dışı
router.post('/login', /* loginLimiter, */ adminController.adminLogin);

/**
 * @swagger
 * /api/admin/statistics:
 *   get:
 *     summary: Sistem İstatistikleri
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '200':
 *         description: İstatistikler başarıyla getirildi
 */
router.get('/statistics', authenticate, requireAdmin, adminController.getStatistics);

/**
 * @swagger
 * /api/admin/users:
 *   get:
 *     summary: Tüm Kullanıcıları Listele
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         description: Sayfa numarası
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *         description: Sayfa başına kayıt sayısı
 *       - in: query
 *         name: role
 *         schema:
 *           type: string
 *           enum: [Admin, Teacher, Student]
 *         description: Rol filtresi
 *     responses:
 *       '200':
 *         description: Kullanıcılar başarıyla getirildi
 */
router.get('/users', authenticate, requireAdmin, adminController.getAllUsers);

/**
 * @swagger
 * /api/admin/users/{id}:
 *   get:
 *     summary: Kullanıcı Detayı
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       '200':
 *         description: Kullanıcı detayı başarıyla getirildi
 *       '404':
 *         description: Kullanıcı bulunamadı
 */
router.get('/users/:id', authenticate, requireAdmin, adminController.getUserById);

/**
 * @swagger
 * /api/admin/users:
 *   post:
 *     summary: Yeni Kullanıcı Oluştur
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
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
 *               lastName:
 *                 type: string
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *               role:
 *                 type: string
 *                 enum: [Admin, Teacher, Student]
 *     responses:
 *       '201':
 *         description: Kullanıcı başarıyla oluşturuldu
 */
router.post('/users', authenticate, requireAdmin, adminController.createUser);

/**
 * @swagger
 * /api/admin/users/{id}:
 *   put:
 *     summary: Kullanıcı Güncelle
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *               role:
 *                 type: string
 *                 enum: [Admin, Teacher, Student]
 *     responses:
 *       '200':
 *         description: Kullanıcı başarıyla güncellendi
 */
router.put('/users/:id', authenticate, requireAdmin, adminController.updateUser);

/**
 * @swagger
 * /api/admin/users/{id}:
 *   delete:
 *     summary: Kullanıcı Sil
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       '200':
 *         description: Kullanıcı başarıyla silindi
 */
router.delete('/users/:id', authenticate, requireAdmin, adminController.deleteUser);

/**
 * @swagger
 * /api/admin/classrooms:
 *   get:
 *     summary: Tüm Sınıfları Listele
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         description: Sayfa numarası
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *         description: Sayfa başına kayıt sayısı
 *     responses:
 *       '200':
 *         description: Sınıflar başarıyla getirildi
 */
router.get('/classrooms', authenticate, requireAdmin, adminController.getAllClassrooms);

/**
 * @swagger
 * /api/admin/teachers/{teacherId}/classrooms:
 *   get:
 *     summary: Öğretmenin Sınıflarını Getir
 *     tags: [Admin]
 *     description: Öğrenci eklerken öğretmen seçildikten sonra o öğretmenin sınıflarını getirir
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: teacherId
 *         required: true
 *         schema:
 *           type: string
 *           format: ObjectId
 *         description: Öğretmen ID'si
 *     responses:
 *       '200':
 *         description: Sınıflar başarıyla getirildi
 *       '404':
 *         description: Öğretmen bulunamadı
 */
router.get('/teachers/:teacherId/classrooms', authenticate, requireAdmin, adminController.getTeacherClassrooms);

/**
 * @swagger
 * /api/admin/teachers:
 *   get:
 *     summary: Tüm Öğretmenleri Listele
 *     tags: [Admin]
 *     description: Öğrenci ekleme formunda öğretmen seçimi için kullanılır
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '200':
 *         description: Öğretmenler başarıyla getirildi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       firstName:
 *                         type: string
 *                       lastName:
 *                         type: string
 *                       fullName:
 *                         type: string
 *                       email:
 *                         type: string
 */
router.get('/teachers', authenticate, requireAdmin, adminController.getAllTeachers);

/**
 * @swagger
 * /api/admin/classrooms/{classroomId}/students:
 *   get:
 *     summary: Sınıftaki Öğrencileri Getir
 *     tags: [Admin]
 *     description: Sınıf seçildikten sonra o sınıftaki öğrencileri getirir
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: classroomId
 *         required: true
 *         schema:
 *           type: string
 *           format: ObjectId
 *         description: Sınıf ID'si
 *     responses:
 *       '200':
 *         description: Öğrenciler başarıyla getirildi
 *       '404':
 *         description: Sınıf bulunamadı
 */
router.get('/classrooms/:classroomId/students', authenticate, requireAdmin, adminController.getClassroomStudents);

// ======================================================================
// ETKİNLİK YÖNETİMİ
// ======================================================================

/**
 * @swagger
 * /api/admin/categories:
 *   get:
 *     summary: Tüm Kategorileri Listele
 *     tags: [Admin]
 *     description: Etkinlik eklerken kategori seçimi için kullanılır
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '200':
 *         description: Kategoriler başarıyla getirildi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Category'
 *       '401':
 *         description: Yetkilendirme hatası
 */
router.get('/categories', authenticate, requireAdmin, adminController.getAllCategories);

/**
 * @swagger
 * /api/admin/categories/{categoryId}/groups:
 *   get:
 *     summary: Kategoriye Göre Grupları Listele
 *     tags: [Admin]
 *     description: Etkinlik eklerken kategori seçildikten sonra grupları getirir
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: categoryId
 *         required: true
 *         schema:
 *           type: string
 *           format: ObjectId
 *         description: Kategori ID'si
 *         example: "507f1f77bcf86cd799439011"
 *     responses:
 *       '200':
 *         description: Gruplar başarıyla getirildi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Group'
 *       '401':
 *         description: Yetkilendirme hatası
 */
router.get('/categories/:categoryId/groups', authenticate, requireAdmin, adminController.getGroupsByCategory);

/**
 * @swagger
 * /api/admin/groups/{groupId}/lessons:
 *   get:
 *     summary: Gruba Göre Dersleri Listele
 *     tags: [Admin]
 *     description: Etkinlik eklerken grup seçildikten sonra dersleri getirir
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *           format: ObjectId
 *         description: Grup ID'si
 *         example: "507f1f77bcf86cd799439011"
 *     responses:
 *       '200':
 *         description: Dersler başarıyla getirildi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Lesson'
 *       '401':
 *         description: Yetkilendirme hatası
 */
router.get('/groups/:groupId/lessons', authenticate, requireAdmin, adminController.getLessonsByGroup);

/**
 * @swagger
 * /api/admin/activities:
 *   get:
 *     summary: Tüm Etkinlikleri Listele
 *     tags: [Admin]
 *     description: Sayfalama ile tüm etkinlikleri listeler. Ders ID'sine göre filtreleme yapılabilir.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Sayfa numarası
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Sayfa başına kayıt sayısı
 *       - in: query
 *         name: lessonId
 *         schema:
 *           type: string
 *           format: ObjectId
 *         description: Belirli bir derse ait etkinlikleri filtrele
 *     responses:
 *       '200':
 *         description: Etkinlikler başarıyla getirildi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Activity'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     page:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     total:
 *                       type: integer
 *                     pages:
 *                       type: integer
 *       '401':
 *         description: Yetkilendirme hatası
 */
router.get('/activities', authenticate, requireAdmin, adminController.getAllActivities);

/**
 * @swagger
 * /api/admin/activities/{id}:
 *   get:
 *     summary: Etkinlik Detayı
 *     tags: [Admin]
 *     description: Etkinlik detayını ve bağlı soruları getirir
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: ObjectId
 *         description: Etkinlik ID'si
 *         example: "507f1f77bcf86cd799439011"
 *     responses:
 *       '200':
 *         description: Etkinlik detayı başarıyla getirildi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   allOf:
 *                     - $ref: '#/components/schemas/Activity'
 *                     - type: object
 *                       properties:
 *                         questions:
 *                           type: array
 *                           items:
 *                             type: object
 *       '401':
 *         description: Yetkilendirme hatası
 *       '404':
 *         description: Etkinlik bulunamadı
 */
router.get('/activities/:id', authenticate, requireAdmin, adminController.getActivityById);

/**
 * @swagger
 * /api/admin/activities:
 *   post:
 *     summary: Yeni Etkinlik Oluştur
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - lesson
 *             properties:
 *               title:
 *                 type: string
 *                 example: "A Harfi Çizim Çalışması"
 *               lesson:
 *                 type: string
 *                 format: ObjectId
 *                 example: "507f1f77bcf86cd799439012"
 *               type:
 *                 type: string
 *                 enum: [Drawing, Listening, Quiz, Visual]
 *                 example: "Drawing"
 *               durationMinutes:
 *                 type: integer
 *                 example: 5
 *           example:
 *             title: "A Harfi Çizim Çalışması"
 *             lesson: "507f1f77bcf86cd799439012"
 *             type: "Drawing"
 *             durationMinutes: 5
 *     responses:
 *       '201':
 *         description: Etkinlik başarıyla oluşturuldu
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: "Etkinlik başarıyla oluşturuldu."
 *                 data:
 *                   $ref: '#/components/schemas/Activity'
 *       '400':
 *         description: Geçersiz istek verisi
 *       '401':
 *         description: Yetkilendirme hatası
 *       '404':
 *         description: Ders bulunamadı
 */
router.post('/activities', authenticate, requireAdmin, adminController.createActivity);

/**
 * @swagger
 * /api/admin/activities/{id}:
 *   put:
 *     summary: Etkinlik Güncelle
 *     tags: [Admin]
 *     description: Mevcut bir etkinliği günceller
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: ObjectId
 *         description: Güncellenecek etkinlik ID'si
 *         example: "507f1f77bcf86cd799439011"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 example: "A Harfi Çizim Çalışması"
 *               lesson:
 *                 type: string
 *                 format: ObjectId
 *                 example: "507f1f77bcf86cd799439012"
 *               type:
 *                 type: string
 *                 enum: [Drawing, Listening, Quiz, Visual]
 *                 example: "Drawing"
 *               durationMinutes:
 *                 type: integer
 *                 example: 5
 *           example:
 *             title: "A Harfi Çizim Çalışması (Güncellenmiş)"
 *             type: "Drawing"
 *             durationMinutes: 10
 *     responses:
 *       '200':
 *         description: Etkinlik başarıyla güncellendi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: "Etkinlik başarıyla güncellendi."
 *                 data:
 *                   $ref: '#/components/schemas/Activity'
 *       '400':
 *         description: Geçersiz istek verisi
 *       '401':
 *         description: Yetkilendirme hatası
 *       '404':
 *         description: Etkinlik veya ders bulunamadı
 */
router.put('/activities/:id', authenticate, requireAdmin, adminController.updateActivity);

/**
 * @swagger
 * /api/admin/activities/{id}:
 *   delete:
 *     summary: Etkinlik Sil
 *     tags: [Admin]
 *     description: Etkinliği ve bağlı tüm soruları siler
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: ObjectId
 *         description: Silinecek etkinlik ID'si
 *         example: "507f1f77bcf86cd799439011"
 *     responses:
 *       '200':
 *         description: Etkinlik başarıyla silindi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: "Etkinlik ve bağlı sorular başarıyla silindi."
 *       '401':
 *         description: Yetkilendirme hatası
 *       '404':
 *         description: Etkinlik bulunamadı
 */
router.delete('/activities/:id', authenticate, requireAdmin, adminController.deleteActivity);

// ======================================================================
// İÇERİK YÖNETİMİ (Content Management)
// ======================================================================

/**
 * @swagger
 * /api/admin/content/category:
 *   post:
 *     summary: Yeni Kategori Oluştur
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               flowType:
 *                 type: string
 *                 enum: [Default, Linear, ScoreBased]
 *               iconUrl:
 *                 type: string
 *     responses:
 *       '201':
 *         description: Kategori başarıyla oluşturuldu
 */
router.post('/content/category', authenticate, requireAdmin, adminController.createCategory);
router.delete('/content/category/:id', authenticate, requireAdmin, adminController.deleteCategory);

/**
 * @swagger
 * /api/admin/content/group:
 *   post:
 *     summary: Yeni Grup Oluştur
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - category
 *             properties:
 *               name:
 *                 type: string
 *               category:
 *                 type: string
 *                 format: ObjectId
 *               orderIndex:
 *                 type: integer
 *     responses:
 *       '201':
 *         description: Grup başarıyla oluşturuldu
 */
router.post('/content/group', authenticate, requireAdmin, adminController.createGroup);
router.delete('/content/group/:id', authenticate, requireAdmin, adminController.deleteGroup);

/**
 * @swagger
 * /api/admin/content/lesson:
 *   post:
 *     summary: Yeni Ders Oluştur
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - group
 *               - targetContent
 *             properties:
 *               title:
 *                 type: string
 *               group:
 *                 type: string
 *                 format: ObjectId
 *               targetContent:
 *                 type: string
 *               orderIndex:
 *                 type: integer
 *     responses:
 *       '201':
 *         description: Ders başarıyla oluşturuldu
 */
router.post('/content/lesson', authenticate, requireAdmin, adminController.createLesson);
router.delete('/content/lesson/:id', authenticate, requireAdmin, adminController.deleteLesson);

/**
 * @swagger
 * /api/admin/content/question:
 *   post:
 *     summary: Yeni Soru Oluştur
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - activity
 *               - questionType
 *               - correctAnswer
 *             properties:
 *               activity:
 *                 type: string
 *                 format: ObjectId
 *               questionType:
 *                 type: string
 *                 enum: [Image, Audio, Video, Drawing, Text]
 *               correctAnswer:
 *                 type: string
 *               data:
 *                 type: object
 *               mediaFileId:
 *                 type: string
 *               mediaUrl:
 *                 type: string
 *               mediaType:
 *                 type: string
 *                 enum: [None, Audio, Image, Video]
 *               mediaStorage:
 *                 type: string
 *                 enum: [None, GridFS, Base64, URL]
 *     responses:
 *       '201':
 *         description: Soru başarıyla oluşturuldu
 */
router.get('/content/question-types', authenticate, requireAdmin, adminController.getQuestionTypes);
router.post('/content/question', authenticate, requireAdmin, adminController.createQuestion);

/**
 * @swagger
 * /api/admin/content/question/{id}:
 *   put:
 *     summary: Soru Güncelle
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: ObjectId
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               activity:
 *                 type: string
 *                 format: ObjectId
 *               questionType:
 *                 type: string
 *                 enum: [Image, Audio, Video, Drawing, Text]
 *               correctAnswer:
 *                 type: string
 *               mediaFiles:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     fileId:
 *                       type: string
 *                     mediaType:
 *                       type: string
 *                       enum: [Audio, Image, Video]
 *                     order:
 *                       type: integer
 *               mediaFileId:
 *                 type: string
 *               mediaUrl:
 *                 type: string
 *               mediaType:
 *                 type: string
 *                 enum: [None, Audio, Image, Video]
 *               mediaStorage:
 *                 type: string
 *                 enum: [None, GridFS, Base64, URL]
 *     responses:
 *       '200':
 *         description: Soru başarıyla güncellendi
 */
router.put('/content/question/:id', authenticate, requireAdmin, adminController.updateQuestion);

/**
 * @swagger
 * /api/admin/content/question/{id}:
 *   delete:
 *     summary: Soru Sil
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       '200':
 *         description: Soru başarıyla silindi
 *       '404':
 *         description: Soru bulunamadı
 */
router.delete('/content/question/:id', authenticate, requireAdmin, adminController.deleteQuestion);

/**
 * @swagger
 * /api/admin/content/groups:
 *   get:
 *     summary: Tüm Grupları Listele
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *       - in: query
 *         name: categoryId
 *         schema:
 *           type: string
 *     responses:
 *       '200':
 *         description: Gruplar başarıyla getirildi
 */
router.get('/content/groups', authenticate, requireAdmin, adminController.getAllGroups);

/**
 * @swagger
 * /api/admin/content/lessons:
 *   get:
 *     summary: Tüm Dersleri Listele
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *       - in: query
 *         name: groupId
 *         schema:
 *           type: string
 *     responses:
 *       '200':
 *         description: Dersler başarıyla getirildi
 */
router.get('/content/lessons', authenticate, requireAdmin, adminController.getAllLessons);

/**
 * @swagger
 * /api/admin/content/questions:
 *   get:
 *     summary: Tüm Soruları Listele
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *       - in: query
 *         name: activityId
 *         schema:
 *           type: string
 *     responses:
 *       '200':
 *         description: Sorular başarıyla getirildi
 */
router.get('/content/questions', authenticate, requireAdmin, adminController.getAllQuestions);
router.delete('/content/question/:id', authenticate, requireAdmin, adminController.deleteQuestion);

// 💡 İSTATİSTİK: Admin panel için istatistik endpoint'leri (proxy)
const statisticsController = require('../controllers/statisticsController');

/**
 * @swagger
 * /api/admin/statistics/teacher/student/{studentId}:
 *   get:
 *     summary: Admin Panel - Öğrenci İstatistiklerini Görüntüleme
 *     tags: [Admin]
 *     description: Admin panelinden öğrenci istatistiklerini görüntüler
 *     security:
 *       - bearerAuth: []
 */
router.get('/statistics/teacher/student/:studentId', authenticate, requireAdmin, statisticsController.getStudentStatisticsForTeacher);

/**
 * @swagger
 * /api/admin/statistics/student/{studentId}/send-email:
 *   post:
 *     summary: Admin Panel - İstatistikleri Email Gönderme
 *     tags: [Admin]
 *     description: Admin panelinden öğrenci istatistiklerini email olarak gönderir
 *     security:
 *       - bearerAuth: []
 */
router.post('/statistics/student/:studentId/send-email', authenticate, requireAdmin, statisticsController.sendStatisticsEmail);

/**
 * @swagger
 * /api/admin/statistics/student/{studentId}/send-session-email:
 *   post:
 *     summary: Admin Panel - Oturum Bazlı İstatistikleri Email Olarak Gönderme
 *     tags: [Admin]
 *     description: Admin panelinden öğrencinin oturum bazlı istatistiklerini email olarak gönderir
 *     security:
 *       - bearerAuth: []
 */
router.post('/statistics/student/:studentId/send-session-email', authenticate, requireAdmin, statisticsController.sendSessionStatisticsEmail);

// 💡 ÖĞRETMEN NOTLARI: Admin panel için öğretmen notları endpoint'leri (proxy)
const teacherNoteController = require('../controllers/teacherNoteController');

/**
 * @swagger
 * /api/admin/teacher-notes/student/{studentId}:
 *   get:
 *     summary: Admin Panel - Öğrenci Notlarını Getirme
 *     tags: [Admin]
 *     description: Admin panelinden öğrenci notlarını getirir
 *     security:
 *       - bearerAuth: []
 */
router.get('/teacher-notes/student/:studentId', authenticate, requireAdmin, teacherNoteController.getStudentNotes);

/**
 * @swagger
 * /api/admin/teacher-notes/student/{studentId}:
 *   post:
 *     summary: Admin Panel - Öğrenciye Not Ekleme
 *     tags: [Admin]
 *     description: Admin panelinden öğrenciye not ekler
 *     security:
 *       - bearerAuth: []
 */
router.post('/teacher-notes/student/:studentId', authenticate, requireAdmin, teacherNoteController.createNote);

/**
 * @swagger
 * /api/admin/teacher-notes/{noteId}:
 *   put:
 *     summary: Admin Panel - Notu Güncelleme
 *     tags: [Admin]
 *     description: Admin panelinden notu günceller
 *     security:
 *       - bearerAuth: []
 */
router.put('/teacher-notes/:noteId', authenticate, requireAdmin, teacherNoteController.updateNote);

/**
 * @swagger
 * /api/admin/teacher-notes/{noteId}:
 *   delete:
 *     summary: Admin Panel - Notu Silme
 *     tags: [Admin]
 *     description: Admin panelinden notu siler
 *     security:
 *       - bearerAuth: []
 */
router.delete('/teacher-notes/:noteId', authenticate, requireAdmin, teacherNoteController.deleteNote);

module.exports = router;

