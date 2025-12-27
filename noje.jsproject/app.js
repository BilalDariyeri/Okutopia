const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const swaggerJSDoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');
const path = require('path'); 
const connectDB = require('./config/db'); // MongoDB bağlantı fonksiyonu
const cors = require('cors'); // 💡 1. EKLENTİ: CORS paketini dahil et
const helmet = require('helmet'); // 💡 GÜVENLİK: HTTP header güvenliği
const { errorHandler, notFound } = require('./middleware/errorHandler'); // 💡 GÜVENLİK: Merkezi hata yönetimi
const requestLogger = require('./middleware/requestLogger'); // 💡 LOGGING: HTTP request logging
const logger = require('./config/logger'); // 💡 LOGGING: Winston logger
const compression = require('compression'); // 💡 PERFORMANS: Response compression
const { generalLimiter } = require('./middleware/rateLimiter'); // 💡 GÜVENLİK: Rate limiting

// .env dosyasındaki değişkenleri yükle
dotenv.config();

const app = express();

// 💡 LOGGING: Uygulama başlangıcını logla
logger.info('🚀 Uygulama başlatılıyor...', {
    nodeEnv: process.env.NODE_ENV || 'development',
    port: process.env.PORT || 3000
});

// 💡 GÜVENLİK: Helmet - HTTP header güvenliği (X-Powered-By header'ını kaldır)
app.use(helmet({
    hidePoweredBy: true, // X-Powered-By header'ını kaldır (bilgi sızıntısını önler)
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"], // Swagger UI ve inline style'lar için gerekli
            scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"], // Swagger UI için gerekli
            scriptSrcAttr: ["'unsafe-inline'"], // Inline event handler'lar için (onclick, onchange vb.)
        },
    },
}));

// 💡 GÜVENLİK: X-Powered-By header'ını kaldır (Express bilgi sızıntısını önler)
app.disable('x-powered-by');

// 💡 PERFORMANS: Response compression (bandwidth tasarrufu)
app.use(compression());

// 💡 GÜVENLİK: CORS yapılandırması (production'da spesifik origin'ler belirtilmeli)
const corsOptions = {
    origin: process.env.CORS_ORIGIN 
        ? process.env.CORS_ORIGIN.split(',') // Birden fazla origin için
        : (process.env.NODE_ENV === 'production' 
            ? false // Production'da origin belirtilmeli
            : true), // Development'ta tüm origin'lere izin
    credentials: true,
    optionsSuccessStatus: 200
};
app.use(cors(corsOptions));

// 💡 GÜVENLİK: Rate limiting (DDoS koruması) - Health check ve admin login hariç tüm endpoint'ler için
app.use('/api/', (req, res, next) => {
    // Health check endpoint'lerini rate limit'ten muaf tut
    if (req.path.startsWith('/health')) {
        return next();
    }
    // Admin login endpoint'ini rate limit'ten muaf tut (kendi loginLimiter'ı var)
    if (req.path === '/admin/login') {
        return next();
    }
    return generalLimiter(req, res, next);
});

// 💡 FAVICON: Favicon isteğini en başta handle et (tarayıcılar otomatik olarak ister)
// Middleware'lerden önce olmalı ki hiçbir işlem yapılmasın
app.get('/favicon.ico', (req, res) => {
    res.status(204).end(); // 204 No Content - favicon yok ama hata da verme
});

// Middleware: Gelen JSON verisini işlemek için (10mb limit)
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' })); 

// 💡 LOGGING: HTTP request logging (route'lardan önce)
app.use(requestLogger);

// MongoDB bağlantısını başlat
connectDB();

// --- BÜTÜN MODELLERİ YÜKLE (Hata çözümü için kritik) ---
require('./models/user');
require('./models/classroom');
require('./models/Progress');
require('./models/category');
require('./models/group');
require('./models/lesson'); // Lesson modeli
require('./models/activity');
require('./models/miniQuestion');
require('./models/studentSession'); // 💡 İSTATİSTİK: Öğrenci oturum takibi
require('./models/dailyStatistics'); // 💡 İSTATİSTİK: Günlük istatistikler
require('./models/readingSession'); // 💡 OKUMA: Okuma süresi takibi
require('./models/teacherNote'); // 💡 ÖĞRETMEN NOTLARI: Öğretmen notları
// -------------------------------------------------------------------

// --- Rota Dosyalarını İçe Aktarma ---
const userRoutes = require('./routes/userRoutes');
const classroomRoutes = require('./routes/classroomRoutes');
const contentRoutes = require('./routes/contentRoutes');
const progressRoutes = require('./routes/progressRoutes'); // 💡 İLERLEME: Progress takibi
const statisticsRoutes = require('./routes/statisticsRoutes'); // 💡 İSTATİSTİK: İstatistik takibi ve email
const teacherNoteRoutes = require('./routes/teacherNoteRoutes'); // 💡 ÖĞRETMEN NOTLARI: Öğretmen notları
const healthRoutes = require('./routes/healthRoutes'); // 💡 MONITORING: Health check
const fileRoutes = require('./routes/fileRoutes'); // 💡 FILES: GridFS dosya yönetimi (ÜCRETSİZ)
const adminRoutes = require('./routes/adminRoutes'); // 💡 ADMIN: Admin panel routes

// API Rota Tanımlamaları
// ÖNEMLİ: Daha spesifik route'lar (admin) önce tanımlanmalı
app.use('/api/admin', adminRoutes); // 💡 ADMIN: Admin panel routes (önce tanımlanmalı)
app.use('/api/health', healthRoutes); // Health check (rate limit dışında)
app.use('/api/users', userRoutes); 
app.use('/api/classrooms', classroomRoutes); 
app.use('/api/content', contentRoutes);
app.use('/api/progress', progressRoutes); // İlerleme takibi
app.use('/api/statistics', statisticsRoutes); // 💡 İSTATİSTİK: İstatistik takibi ve email
app.use('/api/teacher-notes', teacherNoteRoutes); // 💡 ÖĞRETMEN NOTLARI: Öğretmen notları
app.use('/api/files', fileRoutes); // 💡 FILES: GridFS dosya yönetimi (ÜCRETSİZ) 

// Swagger yapılandırması
const swaggerOptions = {
    definition: {
        openapi: "3.0.0",
        info: {
            title: "Eğitim Gelişim Takip API",
            version: "1.0.0",
            description: "Flutter uygulaması için Öğretmen/Sınıf/İlerleme API'si"
        },
        // Swagger components
        components: {
            // 💡 KRİTİK EKLENTİ: Tüm şemaları global olarak tanımlıyoruz
            schemas: {
                User: {
                    type: 'object',
                    properties: {
                        id: { 
                            type: 'string', 
                            format: 'ObjectId',
                            description: 'Kullanıcı ID',
                            example: '507f1f77bcf86cd799439011'
                        },
                        firstName: { 
                            type: 'string',
                            description: 'Ad',
                            example: 'Ahmet'
                        },
                        lastName: { 
                            type: 'string',
                            description: 'Soyad',
                            example: 'Yılmaz'
                        },
                        email: { 
                            type: 'string', 
                            format: 'email',
                            description: 'E-posta adresi',
                            example: 'ahmet.yilmaz@example.com'
                        },
                        role: { 
                            type: 'string', 
                            enum: ['Teacher', 'Student'],
                            description: 'Kullanıcı rolü',
                            example: 'Teacher'
                        }
                    },
                    required: ['firstName', 'lastName'],
                    example: {
                        firstName: 'Ahmet',
                        lastName: 'Yılmaz'
                    }
                },
                TeacherRegistration: {
                    type: 'object',
                    required: ['firstName', 'lastName', 'email', 'password'],
                    properties: {
                        firstName: { 
                            type: 'string',
                            description: 'Öğretmenin adı',
                            example: 'Ahmet'
                        },
                        lastName: { 
                            type: 'string',
                            description: 'Öğretmenin soyadı',
                            example: 'Yılmaz'
                        },
                        email: { 
                            type: 'string',
                            format: 'email',
                            description: 'Öğretmenin e-posta adresi',
                            example: 'ahmet.yilmaz@example.com'
                        },
                        password: { 
                            type: 'string',
                            format: 'password',
                            description: 'Öğretmenin şifresi',
                            example: 'securePassword123'
                        }
                    }
                },
                Classroom: {
                    type: 'object',
                    properties: {
                        id: { type: 'string', format: 'ObjectId' },
                        name: { type: 'string' },
                        teacher: {
                            type: 'object',
                            properties: {
                                firstName: { type: 'string', example: 'Ahmet' },
                                lastName: { type: 'string', example: 'Yılmaz' }
                            }
                        },
                        students: { 
                            type: 'array', 
                            items: {
                                type: 'object',
                                properties: {
                                    firstName: { type: 'string', example: 'Mehmet' },
                                    lastName: { type: 'string', example: 'Demir' }
                                }
                            }
                        }
                    }
                },
                Category: {
                    type: 'object',
                    properties: {
                        id: { type: 'string', format: 'ObjectId' },
                        name: { type: 'string' },
                        flowType: { type: 'string', enum: ['Default', 'Linear', 'ScoreBased'] }
                    }
                },
                Group: {
                    type: 'object',
                    properties: {
                        id: { type: 'string', format: 'ObjectId' },
                        name: { type: 'string' },
                        category: { type: 'string', format: 'ObjectId' },
                        orderIndex: { type: 'integer' }
                    }
                },
                Lesson: {
                    type: 'object',
                    properties: {
                        id: { type: 'string', format: 'ObjectId' },
                        title: { type: 'string' },
                        group: { type: 'string', format: 'ObjectId' },
                        targetContent: { type: 'string' }
                    }
                },
                Activity: {
                    type: 'object',
                    properties: {
                        id: { type: 'string', format: 'ObjectId' },
                        title: { type: 'string' },
                        lesson: { type: 'string', format: 'ObjectId' },
                        type: { type: 'string', enum: ['Drawing', 'Listening', 'Quiz', 'Visual'] }
                    }
                },
                MiniQuestion: {
                    type: 'object',
                    properties: {
                        id: { type: 'string', format: 'ObjectId' },
                        activity: { type: 'string', format: 'ObjectId' },
                        questionType: { type: 'string', enum: ['Image', 'Audio', 'Drawing', 'Text'] }
                    }
                },
                Progress: {
                    type: 'object',
                    properties: {
                        id: { type: 'string', format: 'ObjectId' },
                        student: { type: 'string', format: 'ObjectId' },
                        activityRecords: { type: 'array', items: { type: 'object' } }
                    }
                },
                Activity: {
                    type: 'object',
                    properties: {
                        id: { 
                            type: 'string', 
                            format: 'ObjectId',
                            description: 'Etkinlik ID',
                            example: '507f1f77bcf86cd799439011'
                        },
                        title: { 
                            type: 'string',
                            description: 'Etkinlik başlığı',
                            example: 'A Harfi Çizim Çalışması'
                        },
                        lesson: { 
                            type: 'string', 
                            format: 'ObjectId',
                            description: 'Ders ID',
                            example: '507f1f77bcf86cd799439012'
                        },
                        type: { 
                            type: 'string', 
                            enum: ['Drawing', 'Listening', 'Quiz', 'Visual'],
                            description: 'Etkinlik tipi',
                            example: 'Drawing'
                        },
                        durationMinutes: { 
                            type: 'integer',
                            description: 'Tahmini süre (dakika)',
                            example: 5
                        }
                    },
                    required: ['title', 'lesson'],
                    example: {
                        title: 'A Harfi Çizim Çalışması',
                        lesson: '507f1f77bcf86cd799439012',
                        type: 'Drawing',
                        durationMinutes: 5
                    }
                }
            },
            securitySchemes: {
                bearerAuth: {
                    type: 'http',
                    scheme: 'bearer',
                    bearerFormat: 'JWT',
                    description: 'JWT token ile yetkilendirme. Login endpoint\'inden alınan token\'ı "Bearer {token}" formatında gönderin.'
                }
            }
        },
        // 💡 KRİTİK EKLENTİ: Tüm tag'leri global olarak tanımlıyoruz
        tags: [
            { name: "Users", description: "Öğretmen ve Temel Kullanıcı İşlemleri" },
            { name: "Classrooms", description: "Sınıf Yönetimi ve Öğrenci Ekleme" },
            { name: "Content", description: "İçerik Yönetimi ve Kilit Kontrolü" },
            { name: "Admin", description: "Admin Panel İşlemleri - Kullanıcı, Sınıf ve Etkinlik Yönetimi" },
            { name: "Files", description: "GridFS Dosya Yönetimi - Resim, Video ve Ses Dosyası Yükleme" },
            { name: "Statistics", description: "Öğrenci İstatistik Takibi ve Email Gönderimi" },
            { name: "TeacherNotes", description: "Öğretmen Notları Yönetimi - Her Öğrenciye Özel Notlar" }
        ],
        servers: [
            { url: `http://localhost:${process.env.PORT || 3000}` }
        ]
    },
    // Rota dosyalarını tek tek listeleme (Hata çözümü için)
    apis: [
        path.join(__dirname, 'routes/userRoutes.js'),
        path.join(__dirname, 'routes/classroomRoutes.js'),
        path.join(__dirname, 'routes/contentRoutes.js'),
        path.join(__dirname, 'routes/adminRoutes.js'),
        path.join(__dirname, 'routes/fileRoutes.js'),  // 💡 FILES: GridFS dosya yönetimi
        path.join(__dirname, 'routes/statisticsRoutes.js'),  // 💡 İSTATİSTİK: İstatistik takibi
        path.join(__dirname, 'routes/teacherNoteRoutes.js')  // 💡 ÖĞRETMEN NOTLARI: Öğretmen notları
    ], 
};

const swaggerDocs = swaggerJSDoc(swaggerOptions);

// Swagger UI'yi Express'e bağlama. Dokümantasyon adresi: /api-docs
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerDocs));

// 💡 ADMIN: Admin paneli için static dosya servisi
// Not: HTML dosyasına erişim serbest, ancak frontend'de admin kontrolü yapılıyor
// Backend API endpoint'leri authenticate ve requireAdmin middleware'leri ile korunuyor
app.use('/admin', express.static(path.join(__dirname, 'admin')));
app.get('/admin', (req, res) => {
    res.sendFile(path.join(__dirname, 'admin', 'index.html'));
});

// 💡 GÜVENLİK: 404 handler (tüm route'lardan sonra)
app.use(notFound);

// 💡 GÜVENLİK: Merkezi hata yönetimi (en sonda olmalı)
app.use(errorHandler);

// Sunucuyu başlatma
const PORT = process.env.PORT || 3000;
// Tüm ağ arayüzlerinde dinle (0.0.0.0) - Flutter ve diğer cihazlardan erişim için
const HOST = process.env.HOST || '0.0.0.0';
const server = app.listen(PORT, HOST, () => {
    logger.info(`✅ Sunucu http://localhost:${PORT} üzerinde çalışıyor!`);
    logger.info(`📚 Swagger Dokümantasyonu: http://localhost:${PORT}/api-docs`);
    logger.info(`📝 Log dosyaları: ./logs klasöründe`);
    logger.info(`🏥 Health Check: http://localhost:${PORT}/api/health`);
    
    // Console'a da yazdır (kullanıcı için) - logger zaten yukarıda logluyor
    // Bu console.log'lar kullanıcıya bilgi vermek için bırakıldı
    logger.info(`Sunucu http://localhost:${PORT} üzerinde çalışıyor!`);
    logger.info(`📱 Flutter için: http://10.0.2.2:${PORT}/api (Android emülatör)`);
    logger.info(`📱 Fiziksel cihaz için: http://192.168.1.105:${PORT}/api (IP adresinizi kullanın)`);
    logger.info(`Swagger Dokümantasyonu: http://localhost:${PORT}/api-docs`);
    logger.info(`Health Check: http://localhost:${PORT}/api/health`);
});

// 💡 PERFORMANS: Graceful Shutdown (Düzgün kapanma)
const gracefulShutdown = (signal) => {
    logger.info(`${signal} sinyali alındı. Sunucu düzgün şekilde kapatılıyor...`);
    
    server.close(() => {
        logger.info('HTTP sunucusu kapatıldı.');
        
        // MongoDB bağlantısını kapat (yeni mongoose versiyonunda callback yok)
        mongoose.connection.close(false).then(() => {
            logger.info('MongoDB bağlantısı kapatıldı.');
            logger.info('Uygulama başarıyla kapatıldı.');
            process.exit(0);
        }).catch((error) => {
            logger.error('MongoDB bağlantısı kapatılırken hata:', error);
            process.exit(1);
        });
    });
    
    // 10 saniye içinde kapanmazsa zorla kapat
    setTimeout(() => {
        logger.error('Sunucu zorla kapatılıyor...');
        process.exit(1);
    }, 10000);
};

// Graceful shutdown sinyallerini dinle
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Yakalanmamış hataları yakala
process.on('uncaughtException', (error) => {
    logger.error('Yakalanmamış Exception:', error);
    gracefulShutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('Yakalanmamış Promise Rejection:', { reason, promise });
    gracefulShutdown('unhandledRejection');
});

