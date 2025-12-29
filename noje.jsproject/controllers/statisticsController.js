// controllers/statisticsController.js - İstatistik Controller'ı

const StudentSession = require('../models/studentSession');
const ReadingSession = require('../models/readingSession');
const DailyStatistics = require('../models/dailyStatistics');
const User = require('../models/user');
const Progress = require('../models/Progress');
const Activity = require('../models/activity');
const { sendStatisticsEmail } = require('../utils/emailService');
const logger = require('../config/logger');

// ---------------------------------------------------------------------
// 1. Öğrenci Oturumu Başlatma
// POST /api/statistics/start-session
// ---------------------------------------------------------------------
exports.startSession = async (req, res) => {
    const { studentId } = req.body;

    try {
        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('firstName lastName role').lean();
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        // Aktif oturum var mı kontrol et
        const activeSession = await StudentSession.findOne({
            student: studentId,
            isActive: true
        });

        if (activeSession) {
            return res.status(200).json({
                success: true,
                message: 'Zaten aktif bir oturum var.',
                session: {
                    id: activeSession._id,
                    startTime: activeSession.startTime,
                    isActive: true
                }
            });
        }

        // Yeni oturum oluştur
        const newSession = new StudentSession({
            student: studentId,
            startTime: new Date(),
            date: new Date(),
            isActive: true
        });

        await newSession.save();

        logger.info('Öğrenci oturumu başlatıldı', {
            studentId: studentId,
            sessionId: newSession._id
        });

        res.status(201).json({
            success: true,
            message: 'Oturum başlatıldı.',
            session: {
                id: newSession._id,
                startTime: newSession.startTime,
                isActive: true
            }
        });
    } catch (error) {
        logger.error('Oturum başlatma hatası', {
            studentId: studentId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Oturum başlatılamadı.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 2. Öğrenci Oturumu Bitirme ve İstatistik Güncelleme
// POST /api/statistics/end-session
// ---------------------------------------------------------------------
exports.endSession = async (req, res) => {
    const { studentId, sessionActivities, totalDurationSeconds } = req.body;

    try {
        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('firstName lastName role parentEmail').lean();
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        // Aktif oturumu bul
        const activeSession = await StudentSession.findOne({
            student: studentId,
            isActive: true
        });

        if (!activeSession) {
            return res.status(404).json({
                success: false,
                message: 'Aktif oturum bulunamadı.'
            });
        }

        // Oturumu bitir
        activeSession.endSession();
        await activeSession.save();

        // Bugünkü tarihi al (sadece tarih, saat olmadan)
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Günlük istatistikleri bul veya oluştur
        let dailyStats = await DailyStatistics.findOne({
            student: studentId,
            date: today
        });

        // Öğrencinin ilerlemesini al (tamamlanan aktiviteler için) - kategori bilgisi ile
        const progress = await Progress.findOne({ student: studentId })
            .populate({
                path: 'activityRecords.activityId',
                select: 'title type',
                populate: {
                    path: 'lesson',
                    select: 'title',
                    populate: {
                        path: 'group',
                        select: 'name',
                        populate: {
                            path: 'category',
                            select: 'name'
                        }
                    }
                }
            })
            .lean();

        // Bugün tamamlanan aktiviteleri filtrele
        const todayActivities = (progress?.activityRecords || []).filter(record => {
            const completionDate = new Date(record.completionDate);
            completionDate.setHours(0, 0, 0, 0);
            return completionDate.getTime() === today.getTime();
        });

        if (!dailyStats) {
            // Yeni günlük istatistik oluştur
            dailyStats = new DailyStatistics({
                student: studentId,
                date: today,
                totalTimeSpent: activeSession.duration,
                completedActivities: todayActivities.length,
                activities: todayActivities.map(record => ({
                    activityId: record.activityId?._id || record.activityId,
                    completionTime: record.completionDate,
                    score: record.finalScore || 0,
                    categoryName: record.activityId?.lesson?.group?.category?.name || 'Genel',
                    activityTitle: record.activityId?.title || ''
                })),
                lastActivityId: todayActivities.length > 0 
                    ? (todayActivities[todayActivities.length - 1].activityId?._id || todayActivities[todayActivities.length - 1].activityId)
                    : null
            });
        } else {
            // Mevcut istatistikleri güncelle
            dailyStats.totalTimeSpent += activeSession.duration;
            
            // Bugünkü aktiviteleri ekle (duplicate kontrolü ile)
            const existingActivityIds = dailyStats.activities.map(a => a.activityId?.toString());
            todayActivities.forEach(record => {
                const activityId = record.activityId?._id?.toString() || record.activityId?.toString();
                if (activityId && !existingActivityIds.includes(activityId)) {
                    dailyStats.activities.push({
                        activityId: record.activityId?._id || record.activityId,
                        completionTime: record.completionDate,
                        score: record.finalScore || 0,
                        categoryName: record.activityId?.lesson?.group?.category?.name || 'Genel',
                        activityTitle: record.activityId?.title || ''
                    });
                }
            });
            
            dailyStats.completedActivities = dailyStats.activities.length;
            dailyStats.lastActivityId = dailyStats.activities.length > 0
                ? dailyStats.activities[dailyStats.activities.length - 1].activityId
                : null;
        }

        await dailyStats.save();

        // 💡 VERİTABANI OPTİMİZASYONU: Son oturum istatistiklerini User modeline kaydet (OVERWRITE)
        // Eğer request body'de sessionActivities ve totalDurationSeconds varsa, bunları kullan
        // Yoksa Progress'ten gelen verileri kullan
        let lastSessionActivities = [];
        let sessionTotalDuration = activeSession.duration;
        let sessionStartTime = activeSession.startTime;

        if (sessionActivities && Array.isArray(sessionActivities) && sessionActivities.length > 0 && totalDurationSeconds !== undefined) {
            // Frontend'den gelen oturum verilerini kullan (daha doğru)
            lastSessionActivities = sessionActivities.map(activity => ({
                activityId: activity.activityId,
                activityTitle: activity.activityTitle || 'Bilinmeyen Aktivite',
                durationSeconds: activity.durationSeconds || 0,
                completedAt: activity.completedAt ? new Date(activity.completedAt) : new Date(),
                successStatus: activity.successStatus || null
            }));
            sessionTotalDuration = totalDurationSeconds;
            // İlk aktivitenin tamamlanma zamanını sessionStartTime olarak kullan
            if (lastSessionActivities.length > 0 && lastSessionActivities[0].completedAt) {
                sessionStartTime = lastSessionActivities[0].completedAt;
            }
        } else {
            // Progress'ten gelen verileri kullan (fallback)
            lastSessionActivities = todayActivities.map(record => ({
                activityId: record.activityId?._id || record.activityId,
                activityTitle: record.activityId?.title || '',
                durationSeconds: 0, // Progress'ten süre bilgisi yok
                completedAt: record.completionDate,
                successStatus: null
            }));
        }

        // User modelindeki lastSessionStats'ı güncelle (OVERWRITE - append değil)
        await User.findByIdAndUpdate(studentId, {
            'lastSessionStats.totalDurationSeconds': sessionTotalDuration,
            'lastSessionStats.activities': lastSessionActivities,
            'lastSessionStats.sessionStartTime': sessionStartTime,
            'lastSessionStats.lastUpdated': new Date()
        }, { new: true });

        logger.info('Oturum bitirildi ve istatistikler güncellendi', {
            studentId: studentId,
            sessionId: activeSession._id,
            duration: activeSession.duration,
            activitiesCompleted: todayActivities.length
        });

        res.status(200).json({
            success: true,
            message: 'Oturum bitirildi ve istatistikler güncellendi.',
            session: {
                id: activeSession._id,
                startTime: activeSession.startTime,
                endTime: activeSession.endTime,
                duration: activeSession.duration
            },
            statistics: {
                totalTimeSpent: dailyStats.totalTimeSpent,
                completedActivities: dailyStats.completedActivities,
                activities: dailyStats.activities
            }
        });
    } catch (error) {
        logger.error('Oturum bitirme hatası', {
            studentId: studentId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Oturum bitirilemedi.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 3. Öğrenci İstatistiklerini Getirme
// GET /api/statistics/student/:studentId
// ---------------------------------------------------------------------
exports.getStudentStatistics = async (req, res) => {
    const { studentId } = req.params;
    const { date } = req.query; // Opsiyonel: belirli bir tarih için

    try {
        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('firstName lastName role parentEmail').lean();
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        // Tarih belirtilmişse o tarihi kullan, yoksa bugünü kullan
        const targetDate = date ? new Date(date) : new Date();
        targetDate.setHours(0, 0, 0, 0);

        // Günlük istatistikleri getir
        const dailyStats = await DailyStatistics.findOne({
            student: studentId,
            date: targetDate
        })
        .populate({
            path: 'activities.activityId',
            select: 'title type'
        })
        .populate('lastActivityId', 'title type')
        .lean();

        // Aktif oturum var mı kontrol et
        const activeSession = await StudentSession.findOne({
            student: studentId,
            isActive: true
        }).lean();

        // Toplam istatistikler (tüm zamanlar)
        const allSessions = await StudentSession.find({
            student: studentId
        }).lean();

        const totalTimeSpent = allSessions.reduce((sum, session) => {
            return sum + (session.duration || 0);
        }, 0);

        const allDailyStats = await DailyStatistics.find({
            student: studentId
        }).lean();

        const totalActivitiesCompleted = allDailyStats.reduce((sum, stat) => {
            return sum + (stat.completedActivities || 0);
        }, 0);

        res.status(200).json({
            success: true,
            student: {
                id: student._id,
                firstName: student.firstName,
                lastName: student.lastName,
                parentEmail: student.parentEmail || null
            },
            date: targetDate,
            dailyStatistics: dailyStats ? {
                totalTimeSpent: dailyStats.totalTimeSpent,
                completedActivities: dailyStats.completedActivities,
                activities: dailyStats.activities || [],
                lastActivityId: dailyStats.lastActivityId,
                emailSent: dailyStats.emailSent,
                emailSentAt: dailyStats.emailSentAt
            } : {
                totalTimeSpent: 0,
                completedActivities: 0,
                activities: [],
                lastActivityId: null,
                emailSent: false,
                emailSentAt: null
            },
            activeSession: activeSession ? {
                id: activeSession._id,
                startTime: activeSession.startTime,
                isActive: true
            } : null,
            totalStatistics: {
                totalTimeSpent: totalTimeSpent,
                totalActivitiesCompleted: totalActivitiesCompleted,
                totalDays: allDailyStats.length
            }
        });
    } catch (error) {
        logger.error('İstatistik getirme hatası', {
            studentId: studentId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'İstatistikler yüklenemedi.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 4. Veli Email Güncelleme
// PUT /api/statistics/student/:studentId/parent-email
// ---------------------------------------------------------------------
exports.updateParentEmail = async (req, res) => {
    const { studentId } = req.params;
    const { parentEmail } = req.body;

    try {
        // Email formatını kontrol et
        if (parentEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(parentEmail)) {
            return res.status(400).json({
                success: false,
                message: 'Geçerli bir e-posta adresi giriniz.'
            });
        }

        // Öğrenciyi bul ve güncelle
        const student = await User.findById(studentId);
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        student.parentEmail = parentEmail ? parentEmail.toLowerCase().trim() : null;
        await student.save();

        logger.info('Veli email güncellendi', {
            studentId: studentId,
            parentEmail: student.parentEmail
        });

        res.status(200).json({
            success: true,
            message: 'Veli e-posta adresi güncellendi.',
            student: {
                id: student._id,
                firstName: student.firstName,
                lastName: student.lastName,
                parentEmail: student.parentEmail
            }
        });
    } catch (error) {
        logger.error('Veli email güncelleme hatası', {
            studentId: studentId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Veli e-posta adresi güncellenemedi.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 5. İstatistikleri Veliye Email Olarak Gönderme
// POST /api/statistics/student/:studentId/send-email
// ---------------------------------------------------------------------
exports.sendStatisticsEmail = async (req, res) => {
    const { studentId } = req.params;
    const { parentEmail } = req.body; // Opsiyonel: body'den email alınabilir

    try {
        // Giriş yapan kullanıcının bilgilerini al (öğretmen veya admin - her ikisi de email gönderebilir)
        const senderUser = req.user;
        if (!senderUser || !senderUser.email) {
            return res.status(400).json({
                success: false,
                message: 'Giriş yapılan kullanıcının email adresi bulunamadı.'
            });
        }
        
        // Email gönderim bilgileri:
        // - senderName: From Name olarak görünecek (veli "Ahmet Öğretmen" veya "Mehmet Admin" görür)
        // - replyToEmail: Reply-To olarak ayarlanacak (yanıtlar giriş yapan kullanıcının email'ine gider)
        // Not: Hem öğretmenler hem adminler email gönderebilir ve isimleri görünür
        const senderName = `${senderUser.firstName} ${senderUser.lastName}`;
        const replyToEmail = senderUser.email; // Giriş yapan kullanıcının gerçek email'i (Reply-To için)
        
        logger.info('Email gönderim isteği', {
            senderId: senderUser._id,
            senderName: senderName,
            senderEmail: replyToEmail,
            senderRole: senderUser.role
        });
        

        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('firstName lastName role parentEmail').lean();
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        // Email adresini belirle (body'den veya öğrenci kaydından)
        const emailToSend = parentEmail || student.parentEmail;

        if (!emailToSend) {
            return res.status(400).json({
                success: false,
                message: 'Veli e-posta adresi bulunamadı. Lütfen önce veli e-posta adresini giriniz.'
            });
        }

        // Email formatını kontrol et
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(emailToSend)) {
            return res.status(400).json({
                success: false,
                message: 'Geçerli bir e-posta adresi giriniz.'
            });
        }

        // Bugünkü istatistikleri getir
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        let dailyStats = await DailyStatistics.findOne({
            student: studentId,
            date: today
        })
        .populate({
            path: 'activities.activityId',
            select: 'title',
            populate: {
                path: 'lesson',
                select: 'title',
                populate: {
                    path: 'group',
                    select: 'name',
                    populate: {
                        path: 'category',
                        select: 'name'
                    }
                }
            }
        })
        .lean();

        // Bugünkü istatistik yoksa veya aktivite yoksa, "bugün aktivite yok" mesajıyla email gönder
        const hasNoActivityToday = !dailyStats || dailyStats.completedActivities === 0 || !dailyStats.activities || dailyStats.activities.length === 0;

        // Bugünkü aktivite yoksa, "bugün aktivite yok" mesajıyla email gönder
        if (hasNoActivityToday) {
            logger.info('Bugünkü aktivite yok, bilgilendirme emaili gönderiliyor', { studentId });
            
            await sendStatisticsEmail({
                to: emailToSend,
                studentName: `${student.firstName} ${student.lastName}`,
                totalTimeSpent: 0,
                totalReadingTime: 0,
                totalWordsRead: 0,
                averageReadingSpeed: 0,
                completedActivities: 0,
                completedLessons: {},
                dateLabel: 'Bugün',
                noActivityToday: true, // Bugün aktivite yok flag'i
                senderName: senderName, // From Name: Giriş yapan kullanıcının adı (veli "Ahmet Öğretmen" görür)
                replyToEmail: replyToEmail // Reply-To: Öğretmenin gerçek email'i (yanıtlar öğretmene gider)
            });

            res.status(200).json({
                success: true,
                message: 'Email başarıyla gönderildi. (Bugün aktivite tamamlanmamış)',
                email: emailToSend
            });
            return;
        }

        // İstatistiklerin tarihini belirle
        const statsDate = dailyStats.date || today;
        
        // Okuma oturumlarını getir (aktivite bazlı) - istatistiklerin tarihine göre
        const readingSessions = await ReadingSession.find({
            student: studentId,
            date: statsDate,
            isActive: false
        })
        .populate('activity', 'title')
        .lean();

        // Aktivite bazlı okuma sürelerini map'le
        const readingTimeByActivity = {};
        readingSessions.forEach(session => {
            if (session.activity && session.duration > 0) {
                readingTimeByActivity[session.activity._id.toString()] = {
                    duration: session.duration,
                    wordCount: session.wordCount || 0,
                    readingSpeed: session.readingSpeed || 0
                };
            }
        });

        // Ders bazlı gruplama (tamamlanan derslerin adlarını göster)
        const completedLessons = {};
        if (dailyStats.activities) {
            dailyStats.activities.forEach(act => {
                // Ders bilgisini al
                const lesson = act.activityId?.lesson;
                if (!lesson) return;
                
                const lessonId = lesson._id?.toString() || lesson.toString();
                const lessonTitle = lesson.title || 'Bilinmeyen Ders';
                
                if (!completedLessons[lessonId]) {
                    completedLessons[lessonId] = {
                        title: lessonTitle,
                        activities: [],
                        totalScore: 0,
                        activityCount: 0
                    };
                }
                
                const activityId = act.activityId?._id?.toString() || act.activityId?.toString();
                const readingInfo = readingTimeByActivity[activityId];
                
                completedLessons[lessonId].activities.push({
                    title: act.activityTitle || act.activityId?.title || 'Bilinmeyen Aktivite',
                    score: act.score || 0,
                    readingTime: readingInfo ? readingInfo.duration : null,
                    readingSpeed: readingInfo ? readingInfo.readingSpeed : null,
                    wordCount: readingInfo ? readingInfo.wordCount : null
                });
                completedLessons[lessonId].totalScore += act.score || 0;
                completedLessons[lessonId].activityCount += 1;
            });
        }

        // İstatistiklerin tarihini formatla
        const statsDateFormatted = statsDate instanceof Date 
            ? statsDate.toLocaleDateString('tr-TR', { year: 'numeric', month: 'long', day: 'numeric' })
            : new Date(statsDate).toLocaleDateString('tr-TR', { year: 'numeric', month: 'long', day: 'numeric' });
        
        const isToday = statsDate.getTime() === today.getTime();
        const dateLabel = isToday ? 'Bugün' : statsDateFormatted;

        // Email gönder (ders bazlı)
        await sendStatisticsEmail({
            to: emailToSend,
            studentName: `${student.firstName} ${student.lastName}`,
            totalTimeSpent: dailyStats.totalTimeSpent || 0,
            totalReadingTime: dailyStats.totalReadingTime || 0,
            totalWordsRead: dailyStats.totalWordsRead || 0,
            averageReadingSpeed: dailyStats.averageReadingSpeed || 0,
            completedActivities: dailyStats.completedActivities || 0,
            completedLessons: completedLessons,
            dateLabel: dateLabel, // Email'de gösterilecek tarih etiketi
            noActivityToday: false,
            senderName: senderName, // From Name: Giriş yapan kullanıcının adı (veli "Ahmet Öğretmen" görür)
            replyToEmail: replyToEmail // Reply-To: Öğretmenin gerçek email'i (yanıtlar öğretmene gider)
        });

        // Email gönderildi olarak işaretle
        await DailyStatistics.updateOne(
            { _id: dailyStats._id },
            {
                $set: {
                    emailSent: true,
                    emailSentAt: new Date()
                }
            }
        );

        logger.info('İstatistik email gönderildi', {
            studentId: studentId,
            parentEmail: emailToSend
        });

        res.status(200).json({
            success: true,
            message: 'İstatistikler başarıyla veliye gönderildi.',
            email: emailToSend
        });
    } catch (error) {
        logger.error('Email gönderme hatası', {
            studentId: studentId,
            error: error.message,
            stack: error.stack,
            parentEmail: req.body.parentEmail
        });
        
        // Daha açıklayıcı hata mesajı
        let errorMessage = 'Email gönderilemedi.';
        let statusCode = 500;
        
        if (error.message && error.message.includes('Email yapılandırması eksik')) {
            errorMessage = 'Email yapılandırması eksik: EMAIL_USER ve EMAIL_PASS .env dosyasında tanımlanmalıdır.';
            statusCode = 500;
        } else if (error.message && error.message.includes('kimlik doğrulama')) {
            errorMessage = 'Email kimlik doğrulama hatası. Gmail için App Password kullanılmalıdır.';
            statusCode = 500;
        } else if (error.message && error.message.includes('Geçerli bir e-posta')) {
            errorMessage = error.message;
            statusCode = 400;
        } else if (error.message && error.message.includes('istatistik bulunamadı')) {
            errorMessage = error.message;
            statusCode = 400;
        } else {
            errorMessage = error.message || 'Email gönderilemedi.';
            statusCode = 500;
        }
        
        res.status(statusCode).json({
            success: false,
            message: errorMessage,
            error: process.env.NODE_ENV === 'development' ? error.message : 'Email gönderme hatası'
        });
    }
};

// ---------------------------------------------------------------------
// 6. Oturum Bazlı İstatistikleri Veliye Email Olarak Gönderme
// POST /api/statistics/student/:studentId/send-session-email
// ---------------------------------------------------------------------
exports.sendSessionStatisticsEmail = async (req, res) => {
    const { studentId } = req.params;
    const { parentEmail, sessionActivities, totalDurationSeconds } = req.body;

    try {
        // Giriş yapan kullanıcının bilgilerini al
        const senderUser = req.user;
        if (!senderUser || !senderUser.email) {
            return res.status(400).json({
                success: false,
                message: 'Giriş yapılan kullanıcının email adresi bulunamadı.'
            });
        }
        
        const senderName = `${senderUser.firstName} ${senderUser.lastName}`;
        const replyToEmail = senderUser.email;
        
        logger.info('Oturum bazlı email gönderim isteği', {
            senderId: senderUser._id,
            senderName: senderName,
            senderEmail: replyToEmail,
            studentId: studentId,
            activityCount: sessionActivities?.length || 0
        });

        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('firstName lastName role parentEmail').lean();
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        // Email adresini belirle
        const emailToSend = parentEmail || student.parentEmail;

        if (!emailToSend) {
            return res.status(400).json({
                success: false,
                message: 'Veli e-posta adresi bulunamadı. Lütfen önce veli e-posta adresini giriniz.'
            });
        }

        // Email formatını kontrol et
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(emailToSend)) {
            return res.status(400).json({
                success: false,
                message: 'Geçerli bir e-posta adresi giriniz.'
            });
        }

        // Oturum aktiviteleri kontrolü - SADECE tamamlanmış aktiviteleri filtrele
        const allActivities = sessionActivities || [];
        const completedActivities = allActivities.filter(activity => {
            // isCompleted === true olan aktiviteleri al (varsayılan olarak true kabul et)
            return activity.isCompleted !== false; // undefined veya true ise dahil et
        });
        
        // Toplam süreyi aktivitelerin sürelerinden hesapla (aktivite sürelerinin toplamı)
        const calculatedTotalDuration = completedActivities.reduce((sum, activity) => {
            return sum + (activity.durationSeconds || 0);
        }, 0);
        
        // Frontend'den gelen totalDurationSeconds'i kullan, ama eğer aktivitelerin toplamı daha büyükse onu kullan
        const totalDuration = Math.max(calculatedTotalDuration, totalDurationSeconds || 0);

        if (completedActivities.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Bu oturumda henüz tamamlanmış aktivite bulunamadı.'
            });
        }

        // Süreyi formatla
        const formatTime = (seconds) => {
            const hours = Math.floor(seconds / 3600);
            const minutes = Math.floor((seconds % 3600) / 60);
            const secs = seconds % 60;
            
            if (hours > 0) {
                return `${hours} saat ${minutes} dakika ${secs} saniye`;
            } else if (minutes > 0) {
                return `${minutes} dakika ${secs} saniye`;
            } else {
                return `${secs} saniye`;
            }
        };

        // Aktivite listesini formatla (SADECE tamamlanmış aktiviteler)
        const activitiesListHtml = completedActivities.map((activity, index) => {
            const activityTitle = activity.activityTitle || 'Bilinmeyen Aktivite';
            const duration = activity.durationSeconds || 0;
            const successStatus = activity.successStatus || '';
            
            return `
                <tr>
                    <td style="border: 1px solid #ddd; padding: 10px;">${index + 1}</td>
                    <td style="border: 1px solid #ddd; padding: 10px;"><strong>${activityTitle}</strong></td>
                    <td style="border: 1px solid #ddd; padding: 10px;">${formatTime(duration)}</td>
                    ${successStatus ? `<td style="border: 1px solid #ddd; padding: 10px;">${successStatus}</td>` : '<td style="border: 1px solid #ddd; padding: 10px;">-</td>'}
                </tr>
            `;
        }).join('');

        const activitiesListText = completedActivities.map((activity, index) => {
            const activityTitle = activity.activityTitle || 'Bilinmeyen Aktivite';
            const duration = activity.durationSeconds || 0;
            const successStatus = activity.successStatus || '';
            
            return `${index + 1}. ${activityTitle}: ${formatTime(duration)}${successStatus ? ` (${successStatus})` : ''}`;
        }).join('\n');

        const htmlContent = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                    .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
                    .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
                    .stat-box { background-color: white; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #4CAF50; }
                    .stat-label { font-weight: bold; color: #666; }
                    .stat-value { font-size: 24px; color: #4CAF50; margin-top: 5px; }
                    table { width: 100%; border-collapse: collapse; margin-top: 15px; }
                    th { background-color: #4CAF50; color: white; padding: 10px; text-align: left; }
                    td { border: 1px solid #ddd; padding: 10px; }
                    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>📊 Oturum Raporu</h1>
                    </div>
                    <div class="content">
                        <p>Sayın Veli,</p>
                        <p><strong>${student.firstName} ${student.lastName}</strong> isimli öğrencinin son çalışma oturumu detayları aşağıda yer almaktadır:</p>
                        
                        <div class="stat-box">
                            <div class="stat-label">Toplam Süre</div>
                            <div class="stat-value">${formatTime(totalDuration)}</div>
                        </div>
                        
                        <h3 style="color: #4CAF50; margin-top: 20px;">Tamamlanan Aktiviteler</h3>
                        <table>
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>Aktivite</th>
                                    <th>Süre</th>
                                    <th>Durum</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${activitiesListHtml}
                            </tbody>
                        </table>
                        
                        <p style="margin-top: 20px;">İyi çalışmalar dileriz.</p>
                    </div>
                    <div class="footer">
                        <p>Bu e-posta otomatik olarak gönderilmiştir.</p>
                    </div>
                </div>
            </body>
            </html>
        `;

        const textContent = `
Oturum Raporu

Sayın Veli,

${student.firstName} ${student.lastName} isimli öğrencinin son çalışma oturumu detayları:

Toplam Süre: ${formatTime(totalDuration)}

Tamamlanan Aktiviteler:
${activitiesListText}

İyi çalışmalar dileriz.
        `;

        // Email gönder
        const { sendStatisticsEmail } = require('../utils/emailService');
        await sendStatisticsEmail({
            to: emailToSend,
            studentName: `${student.firstName} ${student.lastName}`,
            totalTimeSpent: totalDuration,
            totalReadingTime: 0,
            totalWordsRead: 0,
            averageReadingSpeed: 0,
            completedActivities: completedActivities.length,
            activities: completedActivities.map((act, idx) => ({
                activityId: { title: act.activityTitle },
                title: act.activityTitle,
                score: 0,
                finalScore: 0,
            })),
            completedLessons: {},
            dateLabel: 'Bu Oturum',
            noActivityToday: false,
            senderName: senderName,
            replyToEmail: replyToEmail,
            customHtmlContent: htmlContent,
            customTextContent: textContent,
        });

        // 💡 VERİTABANI OPTİMİZASYONU: Son oturum istatistiklerini User modeline kaydet (OVERWRITE)
        // Frontend'den gelen oturum verilerini kullanarak lastSessionStats'ı güncelle
        // SADECE tamamlanmış aktiviteleri kaydet
        const lastSessionActivities = completedActivities.map(activity => ({
            activityId: activity.activityId,
            activityTitle: activity.activityTitle || 'Bilinmeyen Aktivite',
            durationSeconds: activity.durationSeconds || 0,
            completedAt: activity.completedAt ? new Date(activity.completedAt) : new Date(),
            successStatus: activity.successStatus || null,
            isCompleted: activity.isCompleted !== false, // Tamamlanma durumu
            correctAnswerCount: activity.correctAnswerCount || 0 // Doğru cevap sayısı
        }));

        // User modelindeki lastSessionStats'ı güncelle (OVERWRITE - append değil)
        await User.findByIdAndUpdate(studentId, {
            'lastSessionStats.totalDurationSeconds': totalDuration,
            'lastSessionStats.activities': lastSessionActivities,
            'lastSessionStats.sessionStartTime': lastSessionActivities.length > 0 
                ? new Date(lastSessionActivities[0].completedAt) 
                : new Date(),
            'lastSessionStats.lastUpdated': new Date()
        }, { new: true });

        logger.info('Oturum bazlı istatistik email gönderildi ve lastSessionStats güncellendi', {
            studentId: studentId,
            parentEmail: emailToSend,
            activityCount: completedActivities.length,
            totalDuration: totalDuration
        });

        res.status(200).json({
            success: true,
            message: 'Oturum raporu başarıyla veliye gönderildi.',
            email: emailToSend
        });
    } catch (error) {
        logger.error('Oturum bazlı email gönderme hatası', {
            studentId: studentId,
            error: error.message,
            stack: error.stack,
            errorCode: error.code,
            errorResponse: error.response,
            requestBody: {
                parentEmail: req.body.parentEmail,
                sessionActivitiesCount: req.body.sessionActivities?.length || 0,
                totalDurationSeconds: req.body.totalDurationSeconds
            }
        });
        
        let errorMessage = 'Email gönderilemedi.';
        let statusCode = 500;
        
        if (error.message && error.message.includes('Email yapılandırması eksik')) {
            errorMessage = 'Email yapılandırması eksik: EMAIL_USER ve EMAIL_PASS .env dosyasında tanımlanmalıdır.';
            statusCode = 500;
        } else if (error.message && error.message.includes('kimlik doğrulama')) {
            errorMessage = 'Email kimlik doğrulama hatası. Gmail için App Password kullanılmalıdır.';
            statusCode = 500;
        } else if (error.code === 'EAUTH') {
            errorMessage = 'Email kimlik doğrulama hatası. EMAIL_USER ve EMAIL_PASS bilgilerini kontrol edin.';
            statusCode = 500;
        } else if (error.code === 'ECONNECTION') {
            errorMessage = 'Email sunucusuna bağlanılamadı. İnternet bağlantınızı kontrol edin.';
            statusCode = 500;
        } else {
            errorMessage = error.message || 'Email gönderilemedi.';
            statusCode = 500;
        }
        
        res.status(statusCode).json({
            success: false,
            message: errorMessage,
            error: process.env.NODE_ENV === 'development' ? error.message : 'Email gönderme hatası',
            errorCode: error.code || 'UNKNOWN_ERROR'
        });
    }
};

// ---------------------------------------------------------------------
// 7. Okuma Süresi Başlatma (Öğretmen Tarafından)
// POST /api/statistics/start-reading
// ---------------------------------------------------------------------
exports.startReading = async (req, res) => {
    const { studentId, activityId } = req.body;
    const jwt = require('jsonwebtoken');

    try {
        // Token'dan öğretmen ID'sini al (öğretmen kontrolü için)
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Token bulunamadı.'
            });
        }

        const token = authHeader.substring(7);
        let decoded;
        try {
            // 🔒 SECURITY: JWT_SECRET environment variable zorunlu
            if (!process.env.JWT_SECRET) {
                return res.status(500).json({
                    success: false,
                    message: 'Sunucu yapılandırma hatası. Lütfen sistem yöneticisine başvurun.'
                });
            }
            decoded = jwt.verify(token, process.env.JWT_SECRET);
        } catch (error) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Geçersiz token.'
            });
        }

        const teacherId = decoded.userId;

        // Öğretmeni kontrol et
        const teacher = await User.findById(teacherId).select('role').lean();
        if (!teacher || (teacher.role !== 'Teacher' && teacher.role !== 'Admin' && teacher.role !== 'SuperAdmin')) {
            return res.status(403).json({
                success: false,
                message: 'Bu işlem için öğretmen yetkisi gereklidir.'
            });
        }

        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('firstName lastName role').lean();
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        // Aktiviteyi kontrol et
        const activity = await Activity.findById(activityId).lean();
        if (!activity) {
            return res.status(404).json({
                success: false,
                message: 'Aktivite bulunamadı.'
            });
        }

        // Aktif okuma oturumu var mı kontrol et
        const activeReading = await ReadingSession.findOne({
            student: studentId,
            activity: activityId,
            isActive: true
        });

        if (activeReading) {
            return res.status(200).json({
                success: true,
                message: 'Zaten aktif bir okuma oturumu var.',
                reading: {
                    id: activeReading._id,
                    startTime: activeReading.startTime,
                    isActive: true
                }
            });
        }

        // Yeni okuma oturumu oluştur
        const newReading = new ReadingSession({
            student: studentId,
            activity: activityId,
            startTime: new Date(),
            date: new Date(),
            isActive: true
        });

        await newReading.save();

        logger.info('Okuma oturumu başlatıldı', {
            studentId: studentId,
            activityId: activityId,
            readingId: newReading._id
        });

        res.status(201).json({
            success: true,
            message: 'Okuma oturumu başlatıldı.',
            reading: {
                id: newReading._id,
                startTime: newReading.startTime,
                isActive: true
            }
        });
    } catch (error) {
        logger.error('Okuma başlatma hatası', {
            studentId: studentId,
            activityId: activityId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Okuma oturumu başlatılamadı.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 7. Okuma Süresi Bitirme
// POST /api/statistics/end-reading
// ---------------------------------------------------------------------
exports.endReading = async (req, res) => {
    const { studentId, activityId, wordCount } = req.body;

    try {
        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('firstName lastName role').lean();
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        // Aktif okuma oturumunu bul
        const activeReading = await ReadingSession.findOne({
            student: studentId,
            activity: activityId,
            isActive: true
        });

        if (!activeReading) {
            return res.status(404).json({
                success: false,
                message: 'Aktif okuma oturumu bulunamadı.'
            });
        }

        // Okuma oturumunu bitir
        activeReading.endReading(wordCount || 0);
        await activeReading.save();

        // Bugünkü tarihi al
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Günlük istatistikleri bul veya oluştur
        let dailyStats = await DailyStatistics.findOne({
            student: studentId,
            date: today
        });

        if (!dailyStats) {
            dailyStats = new DailyStatistics({
                student: studentId,
                date: today,
                totalReadingTime: activeReading.duration,
                totalWordsRead: activeReading.wordCount,
                averageReadingSpeed: activeReading.readingSpeed
            });
        } else {
            // Mevcut istatistikleri güncelle
            dailyStats.totalReadingTime += activeReading.duration;
            dailyStats.totalWordsRead += activeReading.wordCount;
            
            // Ortalama okuma hızını hesapla
            if (dailyStats.totalReadingTime > 0) {
                const totalMinutes = dailyStats.totalReadingTime / 60;
                dailyStats.averageReadingSpeed = Math.round((dailyStats.totalWordsRead / totalMinutes) * 100) / 100;
            }
        }

        await dailyStats.save();

        logger.info('Okuma oturumu bitirildi', {
            studentId: studentId,
            activityId: activityId,
            duration: activeReading.duration,
            wordCount: activeReading.wordCount,
            readingSpeed: activeReading.readingSpeed
        });

        res.status(200).json({
            success: true,
            message: 'Okuma oturumu bitirildi.',
            reading: {
                id: activeReading._id,
                startTime: activeReading.startTime,
                endTime: activeReading.endTime,
                duration: activeReading.duration,
                wordCount: activeReading.wordCount,
                readingSpeed: activeReading.readingSpeed
            }
        });
    } catch (error) {
        logger.error('Okuma bitirme hatası', {
            studentId: studentId,
            activityId: activityId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Okuma oturumu bitirilemedi.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 8. Öğretmenin Öğrencilerini Getirme (Classroom'dan)
// GET /api/statistics/teacher/students
// ---------------------------------------------------------------------
exports.getTeacherStudents = async (req, res) => {
    const jwt = require('jsonwebtoken');

    try {
        // Token'dan öğretmen ID'sini al
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Token bulunamadı.'
            });
        }

        const token = authHeader.substring(7);
        let decoded;
        try {
            // 🔒 SECURITY: JWT_SECRET environment variable zorunlu
            if (!process.env.JWT_SECRET) {
                return res.status(500).json({
                    success: false,
                    message: 'Sunucu yapılandırma hatası. Lütfen sistem yöneticisine başvurun.'
                });
            }
            decoded = jwt.verify(token, process.env.JWT_SECRET);
        } catch (error) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Geçersiz token.'
            });
        }

        const teacherId = decoded.userId;

        // Öğretmeni kontrol et
        const teacher = await User.findById(teacherId).select('role firstName lastName').lean();
        if (!teacher || (teacher.role !== 'Teacher' && teacher.role !== 'Admin' && teacher.role !== 'SuperAdmin')) {
            return res.status(403).json({
                success: false,
                message: 'Bu işlem için öğretmen yetkisi gereklidir.'
            });
        }

        // Öğretmenin sınıflarını bul
        const Classroom = require('../models/classroom');
        const classrooms = await Classroom.find({ teacher: teacherId })
            .populate('students', 'firstName lastName role')
            .lean();

        // Tüm öğrencileri topla (Classroom'dan)
        const allStudents = [];
        classrooms.forEach(classroom => {
            if (classroom.students && classroom.students.length > 0) {
                classroom.students.forEach(student => {
                    if (student && student.role === 'Student') {
                        // Duplicate kontrolü
                        if (!allStudents.find(s => s.id.toString() === student._id.toString())) {
                            allStudents.push({
                                id: student._id,
                                firstName: student.firstName,
                                lastName: student.lastName,
                                classroomName: classroom.name,
                                classroomId: classroom._id
                            });
                        }
                    }
                });
            }
        });

        logger.info('Öğretmen öğrencileri getirildi', {
            teacherId: teacherId,
            studentCount: allStudents.length
        });

        res.status(200).json({
            success: true,
            teacher: {
                id: teacher._id,
                firstName: teacher.firstName,
                lastName: teacher.lastName
            },
            students: allStudents
        });
    } catch (error) {
        logger.error('Öğrenci listesi getirme hatası', {
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Öğrenci listesi yüklenemedi.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 9. Öğretmenin Öğrenci İstatistiklerini Görüntüleme (Email Göndermek İçin)
// GET /api/statistics/teacher/student/:studentId
// ---------------------------------------------------------------------
exports.getStudentStatisticsForTeacher = async (req, res) => {
    const { studentId } = req.params;
    const { date, period, teacherId: queryTeacherId } = req.query; // date: belirli bir tarih, period: 'daily' veya 'weekly', teacherId: query'den öğretmen ID'si (admin panel için)
    const jwt = require('jsonwebtoken');

    try {
        // Token'dan kullanıcı ID'sini al
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Token bulunamadı.'
            });
        }

        const token = authHeader.substring(7);
        let decoded;
        try {
            // 🔒 SECURITY: JWT_SECRET environment variable zorunlu
            if (!process.env.JWT_SECRET) {
                return res.status(500).json({
                    success: false,
                    message: 'Sunucu yapılandırma hatası. Lütfen sistem yöneticisine başvurun.'
                });
            }
            decoded = jwt.verify(token, process.env.JWT_SECRET);
        } catch (error) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Geçersiz token.'
            });
        }

        const userId = decoded.userId;

        // Kullanıcıyı kontrol et
        const user = await User.findById(userId).select('role').lean();
        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Kullanıcı bulunamadı.'
            });
        }

        const isAdmin = user.role === 'Admin' || user.role === 'SuperAdmin';
        const isTeacher = user.role === 'Teacher';

        // Admin değilse ve öğretmen de değilse hata
        if (!isAdmin && !isTeacher) {
            return res.status(403).json({
                success: false,
                message: 'Bu işlem için öğretmen veya admin yetkisi gereklidir.'
            });
        }

        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('firstName lastName role parentEmail').lean();
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        // Öğretmen ID'sini belirle: Admin ise query'den, değilse token'dan
        let teacherId = isAdmin && queryTeacherId ? queryTeacherId : (isTeacher ? userId : null);
        
        // Öğretmenin bu öğrenciye erişimi var mı kontrol et (Admin ise kontrol etme)
        if (!isAdmin && teacherId) {
            const Classroom = require('../models/classroom');
            const classroom = await Classroom.findOne({
                teacher: teacherId,
                students: studentId
            }).lean();

            if (!classroom) {
                return res.status(403).json({
                    success: false,
                    message: 'Bu öğrenciye erişim yetkiniz yok.'
                });
            }
        }

        // Period kontrolü: 'weekly' ise son 7 gün, yoksa günlük
        const isWeekly = period === 'weekly';
        
        let targetDate, startDate, endDate;
        
        if (isWeekly) {
            // Son 7 günün verilerini getir
            endDate = date ? new Date(date) : new Date();
            endDate.setHours(23, 59, 59, 999);
            startDate = new Date(endDate);
            startDate.setDate(startDate.getDate() - 6); // Son 7 gün (bugün dahil)
            startDate.setHours(0, 0, 0, 0);
            targetDate = endDate; // Bugünkü tarih
        } else {
            // Günlük veri
            targetDate = date ? new Date(date) : new Date();
            targetDate.setHours(0, 0, 0, 0);
            startDate = targetDate;
            endDate = new Date(targetDate);
            endDate.setHours(23, 59, 59, 999);
        }

        // İstatistikleri getir (günlük veya haftalık)
        let dailyStats;
        let weeklyStats = [];
        
        if (isWeekly) {
            // Son 7 günün tüm istatistiklerini getir
            weeklyStats = await DailyStatistics.find({
                student: studentId,
                date: { $gte: startDate, $lte: endDate }
            })
            .populate({
                path: 'activities.activityId',
                select: 'title',
                populate: {
                    path: 'lesson',
                    select: 'title',
                    populate: {
                        path: 'group',
                        select: 'name',
                        populate: {
                            path: 'category',
                            select: 'name'
                        }
                    }
                }
            })
            .sort({ date: -1 }) // En yeni tarih önce
            .lean();
            
            // Bugünkü istatistikleri al (email için)
            dailyStats = weeklyStats.find(stat => {
                const statDate = new Date(stat.date);
                statDate.setHours(0, 0, 0, 0);
                return statDate.getTime() === targetDate.getTime();
            });
        } else {
            // Günlük istatistikleri getir
            dailyStats = await DailyStatistics.findOne({
                student: studentId,
                date: targetDate
            })
            .populate({
                path: 'activities.activityId',
                select: 'title',
                populate: {
                    path: 'lesson',
                    select: 'title',
                    populate: {
                        path: 'group',
                        select: 'name',
                        populate: {
                            path: 'category',
                            select: 'name'
                        }
                    }
                }
            })
            .lean();
        }

        // Okuma oturumlarını getir (tarih aralığına göre)
        const readingSessions = await ReadingSession.find({
            student: studentId,
            date: { $gte: startDate, $lte: endDate },
            isActive: false
        })
        .populate('activity', 'title')
        .lean();

        // Aktivite bazlı okuma sürelerini map'le
        const readingTimeByActivity = {};
        readingSessions.forEach(session => {
            if (session.activity && session.duration > 0) {
                readingTimeByActivity[session.activity._id.toString()] = {
                    duration: session.duration,
                    wordCount: session.wordCount || 0,
                    readingSpeed: session.readingSpeed || 0
                };
            }
        });

        // Ders bazlı gruplama (tamamlanan derslerin adlarını göster) - Bugünkü veriler için
        const completedLessons = {};
        if (dailyStats && dailyStats.activities) {
            dailyStats.activities.forEach(act => {
                // Ders bilgisini al
                const lesson = act.activityId?.lesson;
                if (!lesson) return;
                
                const lessonId = lesson._id?.toString() || lesson.toString();
                const lessonTitle = lesson.title || 'Bilinmeyen Ders';
                
                if (!completedLessons[lessonId]) {
                    completedLessons[lessonId] = {
                        title: lessonTitle,
                        activities: [],
                        totalScore: 0,
                        activityCount: 0
                    };
                }
                
                const activityId = act.activityId?._id?.toString() || act.activityId?.toString();
                const readingInfo = readingTimeByActivity[activityId];
                
                completedLessons[lessonId].activities.push({
                    title: act.activityTitle || act.activityId?.title || 'Bilinmeyen Aktivite',
                    score: act.score || 0,
                    readingTime: readingInfo ? readingInfo.duration : null,
                    readingSpeed: readingInfo ? readingInfo.readingSpeed : null,
                    wordCount: readingInfo ? readingInfo.wordCount : null
                });
                completedLessons[lessonId].totalScore += act.score || 0;
                completedLessons[lessonId].activityCount += 1;
            });
        }

        // Haftalık özet istatistikler hesapla
        let weeklySummary = null;
        if (isWeekly && weeklyStats.length > 0) {
            const totalTimeSpent = weeklyStats.reduce((sum, stat) => sum + (stat.totalTimeSpent || 0), 0);
            const totalReadingTime = weeklyStats.reduce((sum, stat) => sum + (stat.totalReadingTime || 0), 0);
            const totalWordsRead = weeklyStats.reduce((sum, stat) => sum + (stat.totalWordsRead || 0), 0);
            const totalCompletedActivities = weeklyStats.reduce((sum, stat) => sum + (stat.completedActivities || 0), 0);
            
            // Ortalama okuma hızını hesapla
            let averageReadingSpeed = 0;
            if (totalReadingTime > 0 && totalWordsRead > 0) {
                const totalMinutes = totalReadingTime / 60;
                averageReadingSpeed = Math.round((totalWordsRead / totalMinutes) * 100) / 100;
            }
            
            weeklySummary = {
                totalTimeSpent,
                totalReadingTime,
                totalWordsRead,
                averageReadingSpeed,
                totalCompletedActivities,
                daysWithActivity: weeklyStats.length,
                dailyBreakdown: weeklyStats.map(stat => ({
                    date: stat.date,
                    totalTimeSpent: stat.totalTimeSpent || 0,
                    totalReadingTime: stat.totalReadingTime || 0,
                    completedActivities: stat.completedActivities || 0
                }))
            };
        }

        logger.info('Öğretmen öğrenci istatistiklerini görüntüledi', {
            teacherId: teacherId,
            studentId: studentId,
            date: targetDate,
            period: isWeekly ? 'weekly' : 'daily'
        });

        res.status(200).json({
            success: true,
            student: {
                id: student._id,
                firstName: student.firstName,
                lastName: student.lastName,
                parentEmail: student.parentEmail || null
            },
            period: isWeekly ? 'weekly' : 'daily',
            date: targetDate,
            dateRange: isWeekly ? {
                startDate: startDate,
                endDate: endDate
            } : null,
            // Günlük istatistikler (bugün için)
            dailyStatistics: dailyStats ? {
                totalTimeSpent: dailyStats.totalTimeSpent || 0,
                totalReadingTime: dailyStats.totalReadingTime || 0,
                totalWordsRead: dailyStats.totalWordsRead || 0,
                averageReadingSpeed: dailyStats.averageReadingSpeed || 0,
                completedActivities: dailyStats.completedActivities || 0,
                completedLessons: completedLessons,
                emailSent: dailyStats.emailSent || false,
                emailSentAt: dailyStats.emailSentAt || null
            } : {
                totalTimeSpent: 0,
                totalReadingTime: 0,
                totalWordsRead: 0,
                averageReadingSpeed: 0,
                completedActivities: 0,
                completedLessons: {},
                emailSent: false,
                emailSentAt: null
            },
            // Haftalık özet (sadece period=weekly ise)
            weeklySummary: weeklySummary
        });
    } catch (error) {
        logger.error('Öğretmen istatistik görüntüleme hatası', {
            studentId: studentId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'İstatistikler yüklenemedi.',
            error: error.message
        });
    }
};
