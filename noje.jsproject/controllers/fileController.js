// controllers/fileController.js - GridFS dosya yönetimi (ÜCRETSİZ ÇÖZÜM)

const { 
    uploadFile, 
    downloadFile, 
    getFileStream, 
    getFileInfo, 
    deleteFile,
    getContentType,
    getAllFiles
} = require('../utils/gridfs');
const logger = require('../config/logger');

// ======================================================================
// DOSYA YÜKLEME
// ======================================================================

/**
 * POST /api/files/upload
 * Dosyayı GridFS'e yükle
 */
exports.uploadFile = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                success: false,
                message: 'Dosya yüklenmedi. Lütfen bir dosya seçin.'
            });
        }

        const file = req.file;
        const { questionId, activityId } = req.body;  // Opsiyonel metadata

        // Dosya adını oluştur (unique olması için timestamp ekle)
        const timestamp = Date.now();
        const originalName = file.originalname;
        const filename = `${timestamp}-${originalName}`;

        // MIME type'ı belirle
        const contentType = file.mimetype || getContentType(originalName);

        // Metadata oluştur
        const metadata = {
            originalName: originalName,
            uploadedBy: req.user?.id || null,  // JWT'den user ID
            questionId: questionId || null,
            activityId: activityId || null,
            uploadedAt: new Date()
        };

        // GridFS'e yükle
        const result = await uploadFile(file.buffer, {
            filename: filename,
            contentType: contentType,
            metadata: metadata
        });

        res.status(201).json({
            success: true,
            message: 'Dosya başarıyla yüklendi.',
            file: {
                fileId: result.fileId,
                filename: result.filename,
                size: result.size,
                contentType: result.contentType,
                url: `/api/files/${result.fileId}`  // Download URL
            }
        });
    } catch (error) {
        logger.error('❌ Dosya yükleme hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Dosya yüklenemedi.',
            error: error.message
        });
    }
};

// ======================================================================
// DOSYA İNDİRME
// ======================================================================

/**
 * GET /api/files/:fileId
 * GridFS'ten dosya indir
 */
exports.downloadFile = async (req, res) => {
    try {
        const { fileId } = req.params;

        if (!fileId) {
            return res.status(400).json({
                success: false,
                message: 'Dosya ID\'si gerekli.'
            });
        }

        // Dosya bilgilerini al
        const fileInfo = await getFileInfo(fileId);

        // Dosya stream'ini al
        const fileStream = getFileStream(fileId);

        // Video ve audio dosyaları için özel header'lar
        const isMediaFile = fileInfo.contentType && (
            fileInfo.contentType.startsWith('video/') || 
            fileInfo.contentType.startsWith('audio/')
        );

        // Response header'larını ayarla
        res.setHeader('Content-Type', fileInfo.contentType || 'application/octet-stream');
        res.setHeader('Content-Disposition', `inline; filename="${fileInfo.filename}"`);
        
        // Video/Audio için Range Request desteği ve CORS header'ları
        if (isMediaFile) {
            res.setHeader('Accept-Ranges', 'bytes');
            res.setHeader('Cache-Control', 'public, max-age=3600');
            res.setHeader('Content-Length', fileInfo.size);
        }

        // CORS header'larını ekle (video streaming için önemli)
        // Tüm origin'lere izin ver (development için)
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Range, Content-Type, Authorization, X-Requested-With');
        res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges, Content-Type');

        // Stream'i response'a pipe et
        fileStream.pipe(res);

    } catch (error) {
        logger.error('❌ Dosya indirme hatası:', error);
        
        if (error.message === 'Dosya bulunamadı') {
            return res.status(404).json({
                success: false,
                message: 'Dosya bulunamadı.'
            });
        }

        res.status(500).json({
            success: false,
            message: 'Dosya indirilemedi.',
            error: error.message
        });
    }
};

// ======================================================================
// DOSYA BİLGİLERİ
// ======================================================================

/**
 * GET /api/files/:fileId/info
 * Dosya bilgilerini al
 */
exports.getFileInfo = async (req, res) => {
    try {
        const { fileId } = req.params;

        if (!fileId) {
            return res.status(400).json({
                success: false,
                message: 'Dosya ID\'si gerekli.'
            });
        }

        const fileInfo = await getFileInfo(fileId);

        res.status(200).json({
            success: true,
            file: fileInfo
        });
    } catch (error) {
        logger.error('❌ Dosya bilgisi alma hatası:', error);
        
        if (error.message === 'Dosya bulunamadı') {
            return res.status(404).json({
                success: false,
                message: 'Dosya bulunamadı.'
            });
        }

        res.status(500).json({
            success: false,
            message: 'Dosya bilgisi alınamadı.',
            error: error.message
        });
    }
};

// ======================================================================
// DOSYA SİLME
// ======================================================================

/**
 * DELETE /api/files/:fileId
 * GridFS'ten dosya sil
 */
exports.deleteFile = async (req, res) => {
    try {
        const { fileId } = req.params;

        if (!fileId) {
            return res.status(400).json({
                success: false,
                message: 'Dosya ID\'si gerekli.'
            });
        }

        await deleteFile(fileId);

        res.status(200).json({
            success: true,
            message: 'Dosya başarıyla silindi.'
        });
    } catch (error) {
        logger.error('❌ Dosya silme hatası:', error);
        
        if (error.message === 'Dosya bulunamadı') {
            return res.status(404).json({
                success: false,
                message: 'Dosya bulunamadı.'
            });
        }

        res.status(500).json({
            success: false,
            message: 'Dosya silinemedi.',
            error: error.message
        });
    }
};

// ======================================================================
// TÜM DOSYALARI LİSTELE
// ======================================================================

/**
 * GET /api/files
 * GridFS'teki tüm dosyaları listele
 */
exports.listFiles = async (req, res) => {
    try {
        logger.info('📋 listFiles fonksiyonu çağrıldı');
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;

        logger.info(`📄 Sayfa: ${page}, Limit: ${limit}, Skip: ${skip}`);

        const files = await getAllFiles({
            limit,
            skip,
            sort: { uploadDate: -1 }
        });

        logger.info(`✅ ${files.length} dosya bulundu`);

        // Toplam dosya sayısını al (GridFS bucket'ından)
        const { getGridFS } = require('../utils/gridfs');
        const gfs = getGridFS();
        const total = await gfs.find({}).toArray().then(files => files.length);

        logger.info(`📊 Toplam dosya sayısı: ${total}`);

        res.status(200).json({
            success: true,
            files,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        logger.error('❌ Dosya listesi hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Dosya listesi alınamadı.',
            error: error.message
        });
    }
};

