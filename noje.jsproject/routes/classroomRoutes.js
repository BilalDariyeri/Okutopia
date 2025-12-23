// routes/classroomRoutes.js

const express = require('express');
const router = express.Router();
const classroomController = require('../controllers/classroomController');
const { validateStudent } = require('../middleware/validators');

/**
 * @swagger
 * tags:
 * - name: Classrooms
 *   description: Sınıf Yönetimi (Oluşturma, listeleme, öğrenci ekleme)
 */

/**
 * @swagger
 * /api/classrooms/teacher/{teacherId}:
 *   get:
 *     summary: Öğretmene ait tüm sınıfları listeleme (Public - Token gerekmez)
 *     tags: [Classrooms]
 *     description: Öğretmen ID'si ile sınıfları çeker. Token gerektirmez.
 *     parameters:
 *       - in: path
 *         name: teacherId
 *         required: true
 *         schema:
 *           type: string
 *         description: Öğretmenin ID'si
 *     responses:
 *       '200':
 *         description: Sınıflar listesi başarıyla getirildi.
 *       '404':
 *         description: Öğretmen bulunamadı veya sınıf yok
 */
// Öğretmen sınıflarını listeleme endpoint'i - Public (Token gerektirmez)
router.get('/teacher/:teacherId', classroomController.getTeacherClassrooms);

/**
 * @swagger
 * /api/classrooms/{classId}/students:
 *   get:
 *     summary: Sınıftaki Tüm Öğrencileri Listeleme
 *     tags: [Classrooms]
 *     description: Sınıftaki tüm öğrencileri ilerleme bilgileri ile birlikte getirir
 *     parameters:
 *       - in: path
 *         name: classId
 *         required: true
 *         schema:
 *           type: string
 *         description: Sınıfın ID'si
 *       - in: query
 *         name: teacherId
 *         schema:
 *           type: string
 *         description: Öğretmen ID'si (güvenlik kontrolü için, opsiyonel)
 *     responses:
 *       '200':
 *         description: Öğrenciler başarıyla getirildi
 *       '403':
 *         description: Yetkisiz işlem
 *       '404':
 *         description: Sınıf bulunamadı
 */
router.get('/:classId/students', classroomController.getClassroomStudents);

/**
 * @swagger
 * /api/classrooms/{classId}/add-student:
 *   post:
 *     summary: Öğrenciyi sınıfa ekleme ve ilerleme kaydı başlatma
 *     tags: [Classrooms]
 *     description: |
 *       Öğretmen sadece öğrencinin adını ve soyadını gönderir.
 *       Sistem otomatik olarak token'dan öğretmen ID'sini alır ve sınıfın sahibi olduğunu kontrol eder.
 *       Öğrenci hem users hem de students koleksiyonuna kaydedilir.
 *     parameters:
 *       - in: path
 *         name: classId
 *         required: true
 *         schema:
 *           type: string
 *         description: Öğrencinin ekleneceği sınıfın ID'si
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
 *         description: Öğrenci başarıyla oluşturuldu ve sınıfa eklendi.
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
 *       '401':
 *         description: Token bulunamadı veya geçersiz
 *       '403':
 *         description: Yetkisiz işlem - Bu sınıf size ait değil
 *       '404':
 *         description: Sınıf bulunamadı
 */
router.post('/:classId/add-student', validateStudent, classroomController.addStudentToClass);

module.exports = router;
