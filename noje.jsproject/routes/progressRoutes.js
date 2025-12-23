// routes/progressRoutes.js - İlerleme Takibi Route'ları

const express = require('express');
const router = express.Router();
const progressController = require('../controllers/progressController');

/**
 * @swagger
 * tags:
 * - name: Progress
 *   description: Öğrenci İlerleme Takibi
 */

/**
 * @swagger
 * /api/progress/student/{studentId}:
 *   get:
 *     summary: Öğrenci İlerlemesini Getirme
 *     tags: [Progress]
 *     description: Tek bir öğrencinin tüm ilerleme bilgilerini getirir
 *     parameters:
 *       - in: path
 *         name: studentId
 *         required: true
 *         schema:
 *           type: string
 *         description: Öğrencinin ID'si
 *     responses:
 *       '200':
 *         description: İlerleme bilgisi başarıyla getirildi
 *       '404':
 *         description: Öğrenci bulunamadı
 */
router.get('/student/:studentId', progressController.getStudentProgress);

/**
 * @swagger
 * /api/progress/classroom/{classId}/summary:
 *   get:
 *     summary: Sınıf İlerleme Özeti
 *     tags: [Progress]
 *     description: Sınıftaki tüm öğrencilerin ilerleme özetini getirir
 *     parameters:
 *       - in: path
 *         name: classId
 *         required: true
 *         schema:
 *           type: string
 *         description: Sınıfın ID'si
 *     responses:
 *       '200':
 *         description: İlerleme özeti başarıyla getirildi
 *       '404':
 *         description: Sınıf bulunamadı
 */
router.get('/classroom/:classId/summary', progressController.getClassroomProgressSummary);

module.exports = router;

