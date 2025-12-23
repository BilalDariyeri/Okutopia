// utils/questionStrategies.js - Soru Tipi Strategy Pattern Implementation

/**
 * Base Question Strategy Interface
 * Her soru tipi bu interface'i implement etmeli
 */
class BaseQuestionStrategy {
    /**
     * Soru tipinin adı
     */
    getType() {
        throw new Error('getType() must be implemented');
    }

    /**
     * Soru tipi için gerekli alanları döndürür
     */
    getRequiredFields() {
        throw new Error('getRequiredFields() must be implemented');
    }

    /**
     * Soru tipi için opsiyonel alanları döndürür
     */
    getOptionalFields() {
        return [];
    }

    /**
     * Soru verisini validate eder
     * @param {Object} questionData - Soru verisi
     * @returns {Object} { valid: boolean, errors: Array<string> }
     */
    validate(questionData) {
        throw new Error('validate() must be implemented');
    }

    /**
     * Soru verisini normalize eder (veritabanına kaydetmeden önce)
     * @param {Object} questionData - Ham soru verisi
     * @returns {Object} Normalize edilmiş soru verisi
     */
    normalize(questionData) {
        return questionData;
    }

    /**
     * Soru tipine özel form alanlarını döndürür (frontend için)
     * @returns {Array<Object>} Form field tanımları
     */
    getFormFields() {
        throw new Error('getFormFields() must be implemented');
    }
}

/**
 * ONLY_TEXT Strategy - Sadece metin soruları
 */
class OnlyTextStrategy extends BaseQuestionStrategy {
    getType() {
        return 'ONLY_TEXT';
    }

    getRequiredFields() {
        return ['questionText'];
    }

    getOptionalFields() {
        return ['instruction', 'correctAnswer'];
    }

    validate(questionData) {
        const errors = [];
        
        if (!questionData.data?.questionText || questionData.data.questionText.trim() === '') {
            errors.push('Soru metni zorunludur');
        }

        return {
            valid: errors.length === 0,
            errors
        };
    }

    normalize(questionData) {
        return {
            ...questionData,
            questionType: 'Text',
            mediaType: 'None',
            mediaStorage: 'None',
            mediaFileId: null,
            data: {
                questionText: questionData.data?.questionText?.trim() || '',
                instruction: questionData.data?.instruction?.trim() || null,
                ...questionData.data
            }
        };
    }

    getFormFields() {
        return [
            {
                name: 'questionText',
                type: 'textarea',
                label: 'Soru Metni *',
                required: true,
                placeholder: 'Soruyu buraya yazın...'
            },
            {
                name: 'instruction',
                type: 'textarea',
                label: 'Açıklama',
                required: false,
                placeholder: 'Ek açıklama (opsiyonel)...'
            },
            {
                name: 'correctAnswer',
                type: 'text',
                label: 'Doğru Cevap',
                required: false,
                placeholder: 'Evet/Hayır veya true/false'
            }
        ];
    }
}

/**
 * AUDIO_TEXT Strategy - Ses + Metin soruları
 */
class AudioTextStrategy extends BaseQuestionStrategy {
    getType() {
        return 'AUDIO_TEXT';
    }

    getRequiredFields() {
        return ['questionText', 'audioFileId'];
    }

    getOptionalFields() {
        return ['instruction', 'correctAnswer'];
    }

    validate(questionData) {
        const errors = [];
        
        if (!questionData.data?.questionText || questionData.data.questionText.trim() === '') {
            errors.push('Soru metni zorunludur');
        }

        if (!questionData.mediaFileId && !questionData.data?.audioFileId) {
            errors.push('Ses dosyası zorunludur');
        }

        return {
            valid: errors.length === 0,
            errors
        };
    }

    normalize(questionData) {
        const audioFileId = questionData.mediaFileId || questionData.data?.audioFileId;
        
        return {
            ...questionData,
            questionType: 'Audio',
            mediaType: 'Audio',
            mediaStorage: audioFileId ? 'GridFS' : 'None',
            mediaFileId: audioFileId || null,
            data: {
                questionText: questionData.data?.questionText?.trim() || '',
                instruction: questionData.data?.instruction?.trim() || null,
                audioFileId: audioFileId || null,
                ...questionData.data
            }
        };
    }

    getFormFields() {
        return [
            {
                name: 'questionText',
                type: 'textarea',
                label: 'Soru Metni *',
                required: true,
                placeholder: 'Soruyu buraya yazın...'
            },
            {
                name: 'audioFile',
                type: 'file',
                label: 'Ses Dosyası *',
                required: true,
                accept: 'audio/*',
                description: 'MP3, WAV veya diğer ses formatları'
            },
            {
                name: 'instruction',
                type: 'textarea',
                label: 'Açıklama',
                required: false,
                placeholder: 'Ek açıklama (opsiyonel)...'
            },
            {
                name: 'correctAnswer',
                type: 'text',
                label: 'Doğru Cevap',
                required: false,
                placeholder: 'Evet/Hayır veya true/false'
            }
        ];
    }
}

/**
 * IMAGE_TEXT Strategy - Resim + Metin soruları
 */
class ImageTextStrategy extends BaseQuestionStrategy {
    getType() {
        return 'IMAGE_TEXT';
    }

    getRequiredFields() {
        return ['questionText', 'imageFileId'];
    }

    getOptionalFields() {
        return ['instruction', 'correctAnswer'];
    }

    validate(questionData) {
        const errors = [];
        
        if (!questionData.data?.questionText || questionData.data.questionText.trim() === '') {
            errors.push('Soru metni zorunludur');
        }

        if (!questionData.mediaFileId && !questionData.data?.imageFileId) {
            errors.push('Resim dosyası zorunludur');
        }

        return {
            valid: errors.length === 0,
            errors
        };
    }

    normalize(questionData) {
        const imageFileId = questionData.mediaFileId || questionData.data?.imageFileId;
        
        return {
            ...questionData,
            questionType: 'Image',
            mediaType: 'Image',
            mediaStorage: imageFileId ? 'GridFS' : 'None',
            mediaFileId: imageFileId || null,
            data: {
                questionText: questionData.data?.questionText?.trim() || '',
                instruction: questionData.data?.instruction?.trim() || null,
                imageFileId: imageFileId || null,
                ...questionData.data
            }
        };
    }

    getFormFields() {
        return [
            {
                name: 'questionText',
                type: 'textarea',
                label: 'Soru Metni *',
                required: true,
                placeholder: 'Soruyu buraya yazın...'
            },
            {
                name: 'imageFile',
                type: 'file',
                label: 'Resim Dosyası *',
                required: true,
                accept: 'image/*',
                description: 'JPG, PNG veya diğer resim formatları'
            },
            {
                name: 'instruction',
                type: 'textarea',
                label: 'Açıklama',
                required: false,
                placeholder: 'Ek açıklama (opsiyonel)...'
            },
            {
                name: 'correctAnswer',
                type: 'text',
                label: 'Doğru Cevap',
                required: false,
                placeholder: 'Evet/Hayır veya true/false'
            }
        ];
    }
}

/**
 * AUDIO_IMAGE_TEXT Strategy - Ses + Resim + Metin soruları
 */
class AudioImageTextStrategy extends BaseQuestionStrategy {
    getType() {
        return 'AUDIO_IMAGE_TEXT';
    }

    getRequiredFields() {
        return ['questionText', 'audioFileId', 'imageFileId'];
    }

    getOptionalFields() {
        return ['instruction', 'correctAnswer'];
    }

    validate(questionData) {
        const errors = [];
        
        if (!questionData.data?.questionText || questionData.data.questionText.trim() === '') {
            errors.push('Soru metni zorunludur');
        }

        const audioFileId = questionData.mediaFileId || questionData.data?.audioFileId;
        const imageFileId = questionData.data?.imageFileId || questionData.mediaFiles?.find(m => m.mediaType === 'Image')?.fileId;

        if (!audioFileId) {
            errors.push('Ses dosyası zorunludur');
        }

        if (!imageFileId) {
            errors.push('Resim dosyası zorunludur');
        }

        return {
            valid: errors.length === 0,
            errors
        };
    }

    normalize(questionData) {
        const audioFileId = questionData.mediaFileId || questionData.data?.audioFileId;
        const imageFileId = questionData.data?.imageFileId || questionData.mediaFiles?.find(m => m.mediaType === 'Image')?.fileId;
        
        // Media files array oluştur
        const mediaFiles = [];
        if (imageFileId) {
            mediaFiles.push({
                fileId: imageFileId,
                mediaType: 'Image',
                order: 0
            });
        }
        if (audioFileId) {
            mediaFiles.push({
                fileId: audioFileId,
                mediaType: 'Audio',
                order: imageFileId ? 1 : 0
            });
        }

        return {
            ...questionData,
            questionType: 'Image', // Ana tip resim olarak ayarla
            mediaType: 'Image', // İlk medya tipi
            mediaStorage: (imageFileId || audioFileId) ? 'GridFS' : 'None',
            mediaFileId: imageFileId || audioFileId || null,
            mediaFiles: mediaFiles.length > 0 ? mediaFiles : undefined,
            data: {
                questionText: questionData.data?.questionText?.trim() || '',
                instruction: questionData.data?.instruction?.trim() || null,
                audioFileId: audioFileId || null,
                imageFileId: imageFileId || null,
                ...questionData.data
            }
        };
    }

    getFormFields() {
        return [
            {
                name: 'questionText',
                type: 'textarea',
                label: 'Soru Metni *',
                required: true,
                placeholder: 'Soruyu buraya yazın...'
            },
            {
                name: 'imageFile',
                type: 'file',
                label: 'Resim Dosyası *',
                required: true,
                accept: 'image/*',
                description: 'JPG, PNG veya diğer resim formatları'
            },
            {
                name: 'audioFile',
                type: 'file',
                label: 'Ses Dosyası *',
                required: true,
                accept: 'audio/*',
                description: 'MP3, WAV veya diğer ses formatları'
            },
            {
                name: 'instruction',
                type: 'textarea',
                label: 'Açıklama',
                required: false,
                placeholder: 'Ek açıklama (opsiyonel)...'
            },
            {
                name: 'correctAnswer',
                type: 'text',
                label: 'Doğru Cevap',
                required: false,
                placeholder: 'Evet/Hayır veya true/false'
            }
        ];
    }
}

/**
 * DRAG_DROP Strategy - Sürükle-Bırak etkinlikleri
 */
class DragDropStrategy extends BaseQuestionStrategy {
    getType() {
        return 'DRAG_DROP';
    }

    getRequiredFields() {
        return ['questionText', 'contentObject'];
    }

    getOptionalFields() {
        return ['instruction'];
    }

    validate(questionData) {
        const errors = [];
        
        if (!questionData.data?.questionText || questionData.data.questionText.trim() === '') {
            errors.push('Soru metni zorunludur');
        }

        if (!questionData.data?.contentObject || typeof questionData.data.contentObject !== 'object') {
            errors.push('İçerik objesi (contentObject) zorunludur');
        }

        // İçerik objesi validasyonu
        const contentObject = questionData.data?.contentObject;
        if (contentObject) {
            if (!contentObject.items || !Array.isArray(contentObject.items)) {
                errors.push('İçerik objesi items array içermelidir');
            }
            if (!contentObject.targets || !Array.isArray(contentObject.targets)) {
                errors.push('İçerik objesi targets array içermelidir');
            }
        }

        return {
            valid: errors.length === 0,
            errors
        };
    }

    normalize(questionData) {
        return {
            ...questionData,
            questionType: 'Drawing', // Drag-drop için Drawing tipi kullanılıyor
            mediaType: 'None',
            mediaStorage: 'None',
            mediaFileId: null,
            data: {
                questionText: questionData.data?.questionText?.trim() || '',
                instruction: questionData.data?.instruction?.trim() || null,
                contentObject: questionData.data?.contentObject || {},
                ...questionData.data
            }
        };
    }

    getFormFields() {
        return [
            {
                name: 'questionText',
                type: 'textarea',
                label: 'Soru Metni *',
                required: true,
                placeholder: 'Soruyu buraya yazın...'
            },
            {
                name: 'contentObject',
                type: 'json',
                label: 'İçerik Objesi (JSON) *',
                required: true,
                placeholder: '{"items": [...], "targets": [...]}',
                description: 'Sürükle-bırak için gerekli JSON yapısı'
            },
            {
                name: 'instruction',
                type: 'textarea',
                label: 'Açıklama',
                required: false,
                placeholder: 'Ek açıklama (opsiyonel)...'
            }
        ];
    }
}

/**
 * Question Strategy Factory
 * Soru tipine göre doğru strategy'yi döndürür
 */
class QuestionStrategyFactory {
    static strategies = {
        'ONLY_TEXT': new OnlyTextStrategy(),
        'AUDIO_TEXT': new AudioTextStrategy(),
        'IMAGE_TEXT': new ImageTextStrategy(),
        'AUDIO_IMAGE_TEXT': new AudioImageTextStrategy(),
        'DRAG_DROP': new DragDropStrategy(),
        // Eski tipler için mapping (backward compatibility)
        'Text': new OnlyTextStrategy(),
        'Audio': new AudioTextStrategy(),
        'Image': new ImageTextStrategy(),
        'Video': new ImageTextStrategy(), // Video için Image strategy kullan
        'Drawing': new DragDropStrategy()
    };

    /**
     * Soru tipine göre strategy döndürür
     * @param {String} questionType - Soru tipi
     * @returns {BaseQuestionStrategy} Strategy instance
     */
    static getStrategy(questionType) {
        const strategy = this.strategies[questionType];
        if (!strategy) {
            throw new Error(`Unknown question type: ${questionType}`);
        }
        return strategy;
    }

    /**
     * Tüm mevcut soru tiplerini döndürür
     * @returns {Array<String>} Soru tipi listesi
     */
    static getAvailableTypes() {
        return Object.keys(this.strategies).filter(key => 
            !['Text', 'Audio', 'Image', 'Video', 'Drawing'].includes(key) // Eski tipleri filtrele
        );
    }

    /**
     * Soru verisini validate eder
     * @param {Object} questionData - Soru verisi
     * @returns {Object} { valid: boolean, errors: Array<string> }
     */
    static validate(questionData) {
        const questionType = questionData.questionType || questionData.questionFormat;
        if (!questionType) {
            return {
                valid: false,
                errors: ['Soru tipi belirtilmelidir']
            };
        }

        try {
            const strategy = this.getStrategy(questionType);
            return strategy.validate(questionData);
        } catch (error) {
            return {
                valid: false,
                errors: [error.message]
            };
        }
    }

    /**
     * Soru verisini normalize eder
     * @param {Object} questionData - Ham soru verisi
     * @returns {Object} Normalize edilmiş soru verisi
     */
    static normalize(questionData) {
        const questionType = questionData.questionType || questionData.questionFormat;
        if (!questionType) {
            throw new Error('Soru tipi belirtilmelidir');
        }

        const strategy = this.getStrategy(questionType);
        return strategy.normalize(questionData);
    }

    /**
     * Soru tipine göre form alanlarını döndürür
     * @param {String} questionType - Soru tipi
     * @returns {Array<Object>} Form field tanımları
     */
    static getFormFields(questionType) {
        const strategy = this.getStrategy(questionType);
        return strategy.getFormFields();
    }
}

module.exports = {
    BaseQuestionStrategy,
    OnlyTextStrategy,
    AudioTextStrategy,
    ImageTextStrategy,
    AudioImageTextStrategy,
    DragDropStrategy,
    QuestionStrategyFactory
};

