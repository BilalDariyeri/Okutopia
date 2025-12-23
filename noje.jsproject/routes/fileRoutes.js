// routes/fileRoutes.js - GridFS dosya yönetimi route'ları (ÜCRETSİZ)

const express = require('express');
const router = express.Router();
const { uploadSingle } = require('../middleware/upload');
const {
    uploadFile,
    downloadFile,
    getFileInfo,
    deleteFile,
    listFiles
} = require('../controllers/fileController');

// ======================================================================
// DOSYA YÖNETİMİ ENDPOINT'LERİ
// ======================================================================

/**
 * @swagger
 * /api/files/upload:
 *   post:
 *     summary: Dosya yükle (Resim, Video, Audio/Ses)
 *     description: |
 *       GridFS kullanarak dosya yükleme endpoint'i.
 *       
 *       **Desteklenen Formatlar:**
 *       - **Resimler:** JPG, JPEG, PNG, GIF, WEBP, SVG
 *       - **Videolar:** MP4, WEBM, OGG, MOV, AVI
 *       - **Ses Dosyaları:** MP3, WAV, OGG, M4A, AAC, FLAC, WEBM Audio
 *       
 *       **Maksimum Dosya Boyutu:** 100MB
 *       
 *       **Örnek Kullanım (Ses Dosyası):**
 *       ```bash
 *       curl -X POST http://localhost:3000/api/files/upload \
 *         -H "Authorization: Bearer YOUR_TOKEN" \
 *         -F "file=@ses_dosyasi.mp3"
 *       ```
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - file
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *                 description: |
 *                   Yüklenecek dosya (Resim, Video veya Ses).
 *                   
 *                   **Ses Dosyası Örnekleri:**
 *                   - MP3: `audio/mpeg`
 *                   - WAV: `audio/wav`
 *                   - OGG: `audio/ogg`
 *                   - M4A: `audio/mp4`
 *                   - AAC: `audio/aac`
 *                   - FLAC: `audio/flac`
 *               questionId:
 *                 type: string
 *                 format: ObjectId
 *                 description: Soru ID'si (opsiyonel - Mini Question ile ilişkilendirme için)
 *                 example: "507f1f77bcf86cd799439011"
 *               activityId:
 *                 type: string
 *                 format: ObjectId
 *                 description: Aktivite ID'si (opsiyonel - Activity ile ilişkilendirme için)
 *                 example: "507f1f77bcf86cd799439012"
 *     responses:
 *       201:
 *         description: Dosya başarıyla yüklendi
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
 *                   example: "Dosya başarıyla yüklendi."
 *                 file:
 *                   type: object
 *                   properties:
 *                     fileId:
 *                       type: string
 *                       format: ObjectId
 *                       description: GridFS dosya ID'si (Mini Question'da kullanılacak)
 *                       example: "507f1f77bcf86cd799439013"
 *                     filename:
 *                       type: string
 *                       example: "1699123456789-ses_dosyasi.mp3"
 *                     size:
 *                       type: number
 *                       description: Dosya boyutu (byte)
 *                       example: 1024000
 *                     contentType:
 *                       type: string
 *                       example: "audio/mpeg"
 *                     url:
 *                       type: string
 *                       description: Dosya indirme URL'si
 *                       example: "/api/files/507f1f77bcf86cd799439013"
 *             example:
 *               success: true
 *               message: "Dosya başarıyla yüklendi."
 *               file:
 *                 fileId: "507f1f77bcf86cd799439013"
 *                 filename: "1699123456789-ses_dosyasi.mp3"
 *                 size: 1024000
 *                 contentType: "audio/mpeg"
 *                 url: "/api/files/507f1f77bcf86cd799439013"
 *       400:
 *         description: Geçersiz istek (dosya seçilmedi veya geçersiz format)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 message:
 *                   type: string
 *                   example: "Dosya yüklenmedi. Lütfen bir dosya seçin."
 *       401:
 *         description: Yetkilendirme hatası
 *       500:
 *         description: Sunucu hatası
 */
/**
 * @swagger
 * /api/files/upload/audio:
 *   post:
 *     summary: Ses dosyası yükle (Özel endpoint)
 *     description: |
 *       Sadece ses dosyaları için özel yükleme endpoint'i.
 *       
 *       **Desteklenen Ses Formatları:**
 *       - MP3 (`audio/mpeg`)
 *       - WAV (`audio/wav`)
 *       - OGG (`audio/ogg`)
 *       - M4A (`audio/mp4`)
 *       - AAC (`audio/aac`)
 *       - FLAC (`audio/flac`)
 *       - WebM Audio (`audio/webm`)
 *       
 *       **Maksimum Dosya Boyutu:** 100MB
 *       
 *       **Örnek Kullanım:**
 *       ```bash
 *       curl -X POST http://localhost:3000/api/files/upload/audio \
 *         -H "Authorization: Bearer YOUR_TOKEN" \
 *         -F "file=@ses_dosyasi.mp3"
 *       ```
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - file
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *                 description: Ses dosyası (MP3, WAV, OGG, M4A, AAC, FLAC, WEBM)
 *     responses:
 *       201:
 *         description: Ses dosyası başarıyla yüklendi
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
 *                   example: "Ses dosyası başarıyla yüklendi."
 *                 file:
 *                   type: object
 *                   properties:
 *                     fileId:
 *                       type: string
 *                       format: ObjectId
 *                       description: GridFS dosya ID'si (Mini Question'da kullanılacak)
 *                       example: "507f1f77bcf86cd799439013"
 *                     filename:
 *                       type: string
 *                       example: "1699123456789-ses_dosyasi.mp3"
 *                     size:
 *                       type: number
 *                       example: 1024000
 *                     contentType:
 *                       type: string
 *                       example: "audio/mpeg"
 *                     url:
 *                       type: string
 *                       example: "/api/files/507f1f77bcf86cd799439013"
 *       400:
 *         description: Geçersiz istek (ses dosyası değil veya format desteklenmiyor)
 *       401:
 *         description: Yetkilendirme hatası
 *       500:
 *         description: Sunucu hatası
 */
// ÖNEMLİ: /upload/audio route'u /upload'dan ÖNCE olmalı (daha spesifik route önce)
router.post('/upload/audio', uploadSingle, uploadFile);

// Dosya yükleme - Authentication gerekli
router.post('/upload', uploadSingle, uploadFile);

/**
 * @swagger
 * /api/files:
 *   get:
 *     summary: Tüm dosyaları listele
 *     tags: [Files]
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
 *         description: Sayfa başına dosya sayısı
 *     responses:
 *       200:
 *         description: Dosya listesi
 */
// ÖNEMLİ: Bu route /:fileId'den ÖNCE olmalı, yoksa /api/files isteği /:fileId route'una düşer
router.get('/', (req, res, next) => {
    console.log('✅ GET /api/files route çağrıldı');
    console.log('Query:', req.query);
    return listFiles(req, res, next);
});

/**
 * @swagger
 * /api/files/{fileId}/info:
 *   get:
 *     summary: Dosya bilgilerini al
 *     tags: [Files]
 *     parameters:
 *       - in: path
 *         name: fileId
 *         required: true
 *         schema:
 *           type: string
 *         description: GridFS dosya ID'si
 *     responses:
 *       200:
 *         description: Dosya bilgileri
 *       404:
 *         description: Dosya bulunamadı
 */
// ÖNEMLİ: /info route'u /:fileId'den ÖNCE olmalı
router.get('/:fileId/info', getFileInfo);

/**
 * @swagger
 * /api/files/{fileId}:
 *   get:
 *     summary: Dosya indir
 *     tags: [Files]
 *     parameters:
 *       - in: path
 *         name: fileId
 *         required: true
 *         schema:
 *           type: string
 *         description: GridFS dosya ID'si
 *     responses:
 *       200:
 *         description: Dosya içeriği
 *         content:
 *           image/*:
 *             schema:
 *               type: string
 *               format: binary
 *           video/*:
 *             schema:
 *               type: string
 *               format: binary
 *           audio/*:
 *             schema:
 *               type: string
 *               format: binary
 *       404:
 *         description: Dosya bulunamadı
 */

// ÖNEMLİ: Bu route EN SON olmalı, yoksa diğer route'ları ezer
router.get('/:fileId', downloadFile);

/**
 * @swagger
 * /api/files/{fileId}:
 *   delete:
 *     summary: Dosya sil
 *     tags: [Files]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: fileId
 *         required: true
 *         schema:
 *           type: string
 *         description: GridFS dosya ID'si
 *     responses:
 *       200:
 *         description: Dosya başarıyla silindi
 *       404:
 *         description: Dosya bulunamadı
 */
router.delete('/:fileId', deleteFile);

module.exports = router;

