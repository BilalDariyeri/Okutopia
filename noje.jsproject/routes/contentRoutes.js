// routes/contentRoutes.js

const express = require('express');
const router = express.Router();
const contentController = require('../controllers/contentController');

/**
 * @swagger
 * tags:
 * - name: Content
 *   description: İçerik Hiyerarşisi Yönetimi (Kategori, Grup, Aktivite, Soru)
 */

// ======================================================================
// I. CRUD (Oluşturma) Rotasyonları
// ======================================================================

/**
 * @swagger
 * /api/content/category:
 *   post:
 *     summary: Yeni Kategori Ekleme
 *     tags: [Content]
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Category'
 *     responses:
 *       '201':
 *         description: Kategori başarıyla eklendi.
 */
router.post('/category', contentController.createCategory);

/**
 * @swagger
 * /api/content/group:
 *   post:
 *     summary: Yeni Grup Ekleme
 *     tags: [Content]
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Group'
 *     responses:
 *       '201':
 *         description: Grup başarıyla eklendi.
 */
router.post('/group', contentController.createGroup);

/**
 * @swagger
 * /api/content/lesson:
 *   post:
 *     summary: Yeni Ders (Harf/Ünite) Ekleme
 *     tags: [Content]
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Lesson'
 *     responses:
 *       '201':
 *         description: Ders başarıyla eklendi.
 */
router.post('/lesson', contentController.createLesson);

/**
 * @swagger
 * /api/content/activity:
 *   post:
 *     summary: Yeni Aktivite (Görev Tipi) Ekleme
 *     tags: [Content]
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Activity'
 *     responses:
 *       '201':
 *         description: Aktivite başarıyla eklendi.
 */
router.post('/activity', contentController.createActivity);

/**
 * @swagger
 * /api/content/question:
 *   post:
 *     summary: Yeni Mini Soru Ekleme
 *     tags: [Content]
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/MiniQuestion'
 *     responses:
 *       '201':
 *         description: Soru başarıyla eklendi.
 */
router.post('/question', contentController.createMiniQuestion);

// ======================================================================
// II. HİYERARŞİ VE KİLİT MANTIĞI
// ======================================================================

/**
 * @swagger
 * /api/content/categories:
 *   get:
 *     summary: Tüm Kategorileri Getirme
 *     tags: [Content]
 *     responses:
 *       '200':
 *         description: Kategoriler başarıyla getirildi.
 */
router.get('/categories', contentController.getAllCategories);

/**
 * @swagger
 * /api/content/category/{categoryId}/hierarchy:
 *   get:
 *     summary: Kategori Hiyerarşisini Getirme
 *     tags: [Content]
 *     parameters:
 *       - in: path
 *         name: categoryId
 *         required: true
 *         schema:
 *           type: string
 *         description: Kategori ID'si
 *     responses:
 *       '200':
 *         description: Hiyerarşi başarıyla getirildi.
 */
router.get('/category/:categoryId/hierarchy', contentController.getCategoryHierarchy);

/**
 * @swagger
 * /api/content/group/{groupId}/lessons:
 *   get:
 *     summary: Grup ID'sine Göre Dersleri Getirme
 *     tags: [Content]
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: Grup ID'si
 *     responses:
 *       '200':
 *         description: Dersler başarıyla getirildi.
 */
router.get('/group/:groupId/lessons', contentController.getLessonsForGroup);

/**
 * @swagger
 * /api/content/lesson/{lessonId}/activities:
 *   get:
 *     summary: Ders ID'sine Göre Etkinlikleri Getirme
 *     tags: [Content]
 *     parameters:
 *       - in: path
 *         name: lessonId
 *         required: true
 *         schema:
 *           type: string
 *         description: Ders ID'si
 *     responses:
 *       '200':
 *         description: Etkinlikler başarıyla getirildi.
 */
router.get('/lesson/:lessonId/activities', contentController.getActivitiesForLesson);

/**
 * @swagger
 * /api/content/activities/{activityId}/questions:
 *   get:
 *     summary: Bir aktiviteye ait tüm soruları getirme
 *     tags: [Content]
 *     parameters:
 *       - in: path
 *         name: activityId
 *         required: true
 *         schema:
 *           type: string
 *         description: Aktivite ID'si
 *     responses:
 *       '200':
 *         description: Sorular başarıyla getirildi.
 */
router.get('/activities/:activityId/questions', contentController.getQuestionsForActivity);

/**
 * @swagger
 * /api/content/groups/{groupId}/questions:
 *   get:
 *     summary: Bir gruba ait tüm soruları getirme
 *     tags: [Content]
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: Grup ID'si
 *     responses:
 *       '200':
 *         description: Sorular başarıyla getirildi.
 */
router.get('/groups/:groupId/questions', contentController.getQuestionsForGroup);

/**
 * @swagger
 * /api/content/questions/{questionId}/nested:
 *   get:
 *     summary: Bir soruya ait nested (iç içe) soruları getirme
 *     tags: [Content]
 *     parameters:
 *       - in: path
 *         name: questionId
 *         required: true
 *         schema:
 *           type: string
 *         description: Ana soru ID'si
 *     responses:
 *       '200':
 *         description: Nested sorular başarıyla getirildi.
 */
router.get('/questions/:questionId/nested', contentController.getNestedQuestions);

/**
 * @swagger
 * /api/content/lock-status/{studentId}/{groupId}:
 *   get:
 *     summary: Grup Kilidi Kontrolü
 *     tags: [Content]
 *     parameters:
 *       - in: path
 *         name: studentId
 *         required: true
 *         schema:
 *           type: string
 *         description: Öğrencinin ID'si
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: Grubun ID'si
 *     responses:
 *       '200':
 *         description: Kilit durumu döndürüldü.
 */
router.get('/lock-status/:studentId/:groupId', contentController.checkLockStatus);

/**
 * @swagger
 * /api/content/complete-activity:
 *   post:
 *     summary: Aktiviteyi Tamamlandı Olarak Kaydetme
 *     tags: [Content]
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               studentId:
 *                 type: string
 *               activityId:
 *                 type: string
 *               finalScore:
 *                 type: number
 *     responses:
 *       '200':
 *         description: Kayıt başarıyla güncellendi.
 */
router.post('/complete-activity', contentController.completeActivity);

module.exports = router;
