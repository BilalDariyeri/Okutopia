// routes/teacherNoteRoutes.js - Öğretmen Notları Route'ları

const express = require('express');
const router = express.Router();
const teacherNoteController = require('../controllers/teacherNoteController');
const { authenticate, requireTeacher } = require('../middleware/auth');

/**
 * @swagger
 * tags:
 * - name: TeacherNotes
 *   description: Öğretmen Notları Yönetimi
 */

/**
 * @swagger
 * /api/teacher-notes/student/{studentId}:
 *   post:
 *     summary: Öğrenciye Not Ekleme
 *     tags: [TeacherNotes]
 *     description: Öğretmen bir öğrenciye not ekler
 *     security:
 *       - bearerAuth: []
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
 *             required:
 *               - title
 *               - content
 *             properties:
 *               title:
 *                 type: string
 *                 description: Not başlığı
 *               content:
 *                 type: string
 *                 description: Not içeriği
 *               priority:
 *                 type: string
 *                 enum: [Normal, Önemli, Acil]
 *                 description: Not önceliği
 *               category:
 *                 type: string
 *                 description: Not kategorisi
 *     responses:
 *       '201':
 *         description: Not başarıyla oluşturuldu
 *       '401':
 *         description: Yetkilendirme hatası
 *       '404':
 *         description: Öğrenci bulunamadı
 */
router.post('/student/:studentId', authenticate, requireTeacher, teacherNoteController.createNote);

/**
 * @swagger
 * /api/teacher-notes/teacher/students:
 *   get:
 *     summary: Öğretmenin Öğrencilerini Getirme
 *     tags: [TeacherNotes]
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
router.get('/teacher/students', authenticate, requireTeacher, teacherNoteController.getTeacherStudents);

/**
 * @swagger
 * /api/teacher-notes/student/{studentId}:
 *   get:
 *     summary: Öğrenciye Ait Notları Getirme
 *     tags: [TeacherNotes]
 *     description: Bir öğrenciye ait tüm notları getirir (sadece giriş yapan öğretmenin notları)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: studentId
 *         required: true
 *         schema:
 *           type: string
 *         description: Öğrenci ID'si
 *     responses:
 *       '200':
 *         description: Notlar başarıyla getirildi
 *       '401':
 *         description: Yetkilendirme hatası
 *       '404':
 *         description: Öğrenci bulunamadı
 */
router.get('/student/:studentId', authenticate, requireTeacher, teacherNoteController.getStudentNotes);

/**
 * @swagger
 * /api/teacher-notes/{noteId}:
 *   put:
 *     summary: Notu Güncelleme
 *     tags: [TeacherNotes]
 *     description: Mevcut bir notu günceller (sadece notu yazan öğretmen)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: noteId
 *         required: true
 *         schema:
 *           type: string
 *         description: Not ID'si
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *               content:
 *                 type: string
 *               priority:
 *                 type: string
 *                 enum: [Normal, Önemli, Acil]
 *               category:
 *                 type: string
 *     responses:
 *       '200':
 *         description: Not başarıyla güncellendi
 *       '403':
 *         description: Bu notu güncelleme yetkiniz yok
 *       '404':
 *         description: Not bulunamadı
 */
router.put('/:noteId', authenticate, requireTeacher, teacherNoteController.updateNote);

/**
 * @swagger
 * /api/teacher-notes/{noteId}:
 *   delete:
 *     summary: Notu Silme
 *     tags: [TeacherNotes]
 *     description: Bir notu siler (sadece notu yazan öğretmen)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: noteId
 *         required: true
 *         schema:
 *           type: string
 *         description: Not ID'si
 *     responses:
 *       '200':
 *         description: Not başarıyla silindi
 *       '403':
 *         description: Bu notu silme yetkiniz yok
 *       '404':
 *         description: Not bulunamadı
 */
router.delete('/:noteId', authenticate, requireTeacher, teacherNoteController.deleteNote);

/**
 * @swagger
 * /api/teacher-notes/teacher:
 *   get:
 *     summary: Öğretmenin Tüm Notlarını Getirme
 *     tags: [TeacherNotes]
 *     description: Giriş yapan öğretmenin tüm öğrenciler için yazdığı notları getirir
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '200':
 *         description: Notlar başarıyla getirildi
 *       '401':
 *         description: Yetkilendirme hatası
 */
router.get('/teacher', authenticate, requireTeacher, teacherNoteController.getTeacherNotes);

module.exports = router;

