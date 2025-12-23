// middleware/upload.js - Multer dosya upload middleware (ÜCRETSİZ)

const multer = require('multer');
const path = require('path');

// Memory storage (GridFS için buffer kullanacağız)
const storage = multer.memoryStorage();

// Dosya filtresi (sadece resim, video, audio)
const fileFilter = (req, file, cb) => {
    const allowedMimes = [
        // Resimler
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/gif',
        'image/webp',
        'image/svg+xml',
        // Videolar
        'video/mp4',
        'video/webm',
        'video/ogg',
        'video/quicktime',
        'video/x-msvideo',
        // Sesler
        'audio/mpeg',
        'audio/mp3',
        'audio/wav',
        'audio/ogg',
        'audio/mp4',
        'audio/x-m4a',
        'audio/aac',
        'audio/flac',
        'audio/webm'
    ];

    if (allowedMimes.includes(file.mimetype)) {
        cb(null, true);
    } else {
        cb(new Error('Geçersiz dosya tipi. Sadece resim, video ve ses dosyaları kabul edilir.'), false);
    }
};

// Multer yapılandırması
const upload = multer({
    storage: storage,
    fileFilter: fileFilter,
    limits: {
        fileSize: 100 * 1024 * 1024  // 100MB limit (GridFS için yeterli)
    }
});

// Tek dosya upload
const uploadSingle = upload.single('file');

// Çoklu dosya upload (opsiyonel)
const uploadMultiple = upload.array('files', 10);  // Maksimum 10 dosya

module.exports = {
    uploadSingle,
    uploadMultiple,
    upload
};

