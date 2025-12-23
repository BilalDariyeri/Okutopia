// utils/gridfs.js - MongoDB GridFS dosya yönetimi (ÜCRETSİZ ÇÖZÜM)
// Hem resim hem video (MP4) dosyaları için kullanılabilir

const mongoose = require('mongoose');
const { Readable } = require('stream');

// GridFS bucket oluştur
let gfs;

// GridFS bağlantısını başlat
const initGridFS = () => {
    try {
        // GridFS bucket'ı oluştur (collection adı: 'uploads')
        gfs = new mongoose.mongo.GridFSBucket(mongoose.connection.db, {
            bucketName: 'uploads'
        });
        console.log('✅ GridFS başlatıldı (Resim, Video, Audio depolama hazır)');
        return gfs;
    } catch (error) {
        console.error('❌ GridFS başlatma hatası:', error);
        throw error;
    }
};

// GridFS instance'ını al
const getGridFS = () => {
    if (!gfs) {
        gfs = initGridFS();
    }
    return gfs;
};

// ======================================================================
// DOSYA YÜKLEME (Upload)
// ======================================================================

/**
 * Dosyayı GridFS'e yükle
 * @param {Buffer|Stream} fileBuffer - Yüklenecek dosya (Buffer veya Stream)
 * @param {Object} options - Dosya seçenekleri
 * @param {String} options.filename - Dosya adı
 * @param {String} options.contentType - MIME type (image/jpeg, video/mp4, etc.)
 * @param {Object} options.metadata - Ek metadata (questionId, activityId, etc.)
 * @returns {Promise<Object>} - { fileId, filename, size, contentType }
 */
const uploadFile = async (fileBuffer, options) => {
    try {
        const gfs = getGridFS();
        
        const { filename, contentType, metadata = {} } = options;
        
        if (!filename || !contentType) {
            throw new Error('filename ve contentType zorunludur');
        }

        // Dosyayı GridFS'e yaz
        const writeStream = gfs.openUploadStream(filename, {
            contentType: contentType,
            metadata: metadata
        });

        // Buffer'ı stream'e çevir ve yaz
        const bufferStream = new Readable();
        bufferStream.push(fileBuffer);
        bufferStream.push(null);

        return new Promise((resolve, reject) => {
            bufferStream
                .pipe(writeStream)
                .on('finish', () => {
                    resolve({
                        fileId: writeStream.id,
                        filename: filename,
                        size: writeStream.length,
                        contentType: contentType,
                        metadata: metadata
                    });
                })
                .on('error', (error) => {
                    reject(error);
                });
        });
    } catch (error) {
        console.error('❌ GridFS upload hatası:', error);
        throw error;
    }
};

// ======================================================================
// DOSYA İNDİRME (Download)
// ======================================================================

/**
 * GridFS'ten dosya oku
 * @param {String|ObjectId} fileId - GridFS dosya ID'si
 * @returns {Promise<Buffer>} - Dosya buffer'ı
 */
const downloadFile = async (fileId) => {
    try {
        const gfs = getGridFS();
        
        // ObjectId'ye çevir
        const _id = typeof fileId === 'string' 
            ? new mongoose.Types.ObjectId(fileId) 
            : fileId;

        // Dosya var mı kontrol et
        const files = await gfs.find({ _id }).toArray();
        if (!files || files.length === 0) {
            throw new Error('Dosya bulunamadı');
        }

        // Dosyayı oku
        const chunks = [];
        const downloadStream = gfs.openDownloadStream(_id);

        return new Promise((resolve, reject) => {
            downloadStream.on('data', (chunk) => {
                chunks.push(chunk);
            });

            downloadStream.on('end', () => {
                resolve(Buffer.concat(chunks));
            });

            downloadStream.on('error', (error) => {
                reject(error);
            });
        });
    } catch (error) {
        console.error('❌ GridFS download hatası:', error);
        throw error;
    }
};

/**
 * GridFS'ten dosya stream'i al (büyük dosyalar için)
 * @param {String|ObjectId} fileId - GridFS dosya ID'si
 * @returns {Stream} - Dosya stream'i
 */
const getFileStream = (fileId) => {
    try {
        const gfs = getGridFS();
        
        const _id = typeof fileId === 'string' 
            ? new mongoose.Types.ObjectId(fileId) 
            : fileId;

        return gfs.openDownloadStream(_id);
    } catch (error) {
        console.error('❌ GridFS stream hatası:', error);
        throw error;
    }
};

/**
 * Dosya bilgilerini al
 * @param {String|ObjectId} fileId - GridFS dosya ID'si
 * @returns {Promise<Object>} - Dosya bilgileri
 */
const getFileInfo = async (fileId) => {
    try {
        const gfs = getGridFS();
        
        const _id = typeof fileId === 'string' 
            ? new mongoose.Types.ObjectId(fileId) 
            : fileId;

        const files = await gfs.find({ _id }).toArray();
        if (!files || files.length === 0) {
            throw new Error('Dosya bulunamadı');
        }

        const file = files[0];
        return {
            fileId: file._id,
            filename: file.filename,
            size: file.length,
            contentType: file.contentType,
            uploadDate: file.uploadDate,
            metadata: file.metadata || {}
        };
    } catch (error) {
        console.error('❌ GridFS file info hatası:', error);
        throw error;
    }
};

// ======================================================================
// DOSYA SİLME (Delete)
// ======================================================================

/**
 * GridFS'ten dosya sil
 * @param {String|ObjectId} fileId - GridFS dosya ID'si
 * @returns {Promise<Boolean>} - Silme başarılı mı?
 */
const deleteFile = async (fileId) => {
    try {
        const gfs = getGridFS();
        
        const _id = typeof fileId === 'string' 
            ? new mongoose.Types.ObjectId(fileId) 
            : fileId;

        await gfs.delete(_id);
        return true;
    } catch (error) {
        console.error('❌ GridFS delete hatası:', error);
        throw error;
    }
};

// ======================================================================
// MIME TYPE HELPER
// ======================================================================

/**
 * Dosya uzantısından MIME type belirle
 * @param {String} filename - Dosya adı
 * @returns {String} - MIME type
 */
const getContentType = (filename) => {
    const ext = filename.toLowerCase().split('.').pop();
    const mimeTypes = {
        // Resimler
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif',
        'webp': 'image/webp',
        'svg': 'image/svg+xml',
        // Videolar
        'mp4': 'video/mp4',
        'webm': 'video/webm',
        'ogg': 'video/ogg',
        'mov': 'video/quicktime',
        'avi': 'video/x-msvideo',
        // Sesler
        'mp3': 'audio/mpeg',
        'wav': 'audio/wav',
        'ogg': 'audio/ogg',
        'm4a': 'audio/mp4',
        'aac': 'audio/aac',
        'flac': 'audio/flac',
        'webm': 'audio/webm'
    };
    return mimeTypes[ext] || 'application/octet-stream';
};

// ======================================================================
// TÜM DOSYALARI LİSTELE
// ======================================================================

/**
 * GridFS'teki tüm dosyaları listele
 * @param {Object} options - Sıralama ve filtreleme seçenekleri
 * @param {Number} options.limit - Maksimum dosya sayısı
 * @param {Number} options.skip - Atlanacak dosya sayısı
 * @param {Object} options.sort - Sıralama kriteri
 * @returns {Promise<Array>} - Dosya listesi
 */
const getAllFiles = async (options = {}) => {
    try {
        const gfs = getGridFS();
        
        const {
            limit = 100,
            skip = 0,
            sort = { uploadDate: -1 } // En yeni dosyalar önce
        } = options;

        const files = await gfs.find({})
            .sort(sort)
            .skip(skip)
            .limit(limit)
            .toArray();

        return files.map(file => ({
            _id: file._id,
            filename: file.filename,
            length: file.length,
            contentType: file.contentType,
            uploadDate: file.uploadDate,
            metadata: file.metadata || {}
        }));
    } catch (error) {
        console.error('❌ GridFS dosya listesi hatası:', error);
        throw error;
    }
};

module.exports = {
    initGridFS,
    getGridFS,
    uploadFile,
    downloadFile,
    getFileStream,
    getFileInfo,
    deleteFile,
    getContentType,
    getAllFiles
};

