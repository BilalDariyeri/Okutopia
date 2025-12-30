// controllers/contentController.js
const Category = require('../models/category');
const Group = require('../models/group');
const Lesson = require('../models/lesson');
const Activity = require('../models/activity');
const MiniQuestion = require('../models/miniQuestion');
const Progress = require('../models/progress');
const logger = require('../config/logger'); 

// ======================================================================
// I. CRUD (Oluşturma) Rotasyonları
// ======================================================================

// 1. Yeni Kategori Ekleme
exports.createCategory = async (req, res) => {
    try {
        const category = await Category.create(req.body);
        res.status(201).json(category);
    } catch (error) {
        res.status(400).json({ message: 'Kategori oluşturulamadı.', error: error.message });
    }
};

// 2. Yeni Grup Ekleme
exports.createGroup = async (req, res) => {
    try {
        const group = await Group.create(req.body);
        res.status(201).json(group);
    } catch (error) {
        res.status(400).json({ message: 'Grup oluşturulamadı.', error: error.message });
    }
};

// 3. Yeni Ders (Harf/Ünite) Ekleme
exports.createLesson = async (req, res) => {
    try {
        const lesson = await Lesson.create(req.body);
        res.status(201).json(lesson);
    } catch (error) {
        res.status(400).json({ message: 'Ders oluşturulamadı.', error: error.message });
    }
};

// 4. Yeni Aktivite (Görev Tipi) Ekleme
exports.createActivity = async (req, res) => {
    try {
        const activity = await Activity.create(req.body);
        res.status(201).json(activity);
    } catch (error) {
        res.status(400).json({ message: 'Aktivite oluşturulamadı.', error: error.message });
    }
};

// 5. Yeni Mini Soru Ekleme
exports.createMiniQuestion = async (req, res) => {
    try {
        const question = await MiniQuestion.create(req.body);
        res.status(201).json(question);
    } catch (error) {
        res.status(400).json({ message: 'Soru oluşturulamadı.', error: error.message });
    }
};

// ======================================================================
// II. HİYERARŞİ VE KİLİT MANTIĞI
// ======================================================================

// 6. Tüm Kategorileri Getirme
// 💡 PERFORMANS: Pagination ve lean() ile optimize edildi
exports.getAllCategories = async (req, res) => {
    try {
        // 💡 PERFORMANS: Pagination desteği
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;
        const actualLimit = Math.min(limit, 100);
        
        // Kategorileri çek (lean() ile optimize)
        const categories = await Category.find({})
            .sort('createdAt')
            .lean() // 💡 PERFORMANS: lean() kullanarak daha hızlı
            .skip(skip)
            .limit(actualLimit);
        
        // Toplam sayı
        const total = await Category.countDocuments({});
        
        res.status(200).json({
            success: true,
            categories,
            pagination: {
                page,
                limit: actualLimit,
                total,
                pages: Math.ceil(total / actualLimit)
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Kategoriler çekilemedi.', error: error.message });
    }
};

// 7. Kategoriye Ait Tüm Hiyerarşiyi Getirme (Grupları Getir)
// 💡 PERFORMANS: Pagination ve lean() ile optimize edildi
exports.getCategoryHierarchy = async (req, res) => {
    try {
        const { categoryId } = req.params;
        
        // 💡 PERFORMANS: Pagination desteği
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;
        const actualLimit = Math.min(limit, 100);
        
        // Grupları çek (lean() ile optimize)
        const groups = await Group.find({ category: categoryId })
            .sort('orderIndex')
            .lean() // 💡 PERFORMANS: lean() kullanarak daha hızlı
            .skip(skip)
            .limit(actualLimit);
        
        // Toplam sayı
        const total = await Group.countDocuments({ category: categoryId });
        
        res.status(200).json({
            success: true,
            groups,
            pagination: {
                page,
                limit: actualLimit,
                total,
                pages: Math.ceil(total / actualLimit)
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Hiyerarşi çekilemedi.', error: error.message });
    }
};

// 8. Grup ID'sine Göre Dersleri Getirme
// 💡 PERFORMANS: Pagination ve lean() ile optimize edildi
exports.getLessonsForGroup = async (req, res) => {
    try {
        const { groupId } = req.params;
        
        // 💡 PERFORMANS: Pagination desteği
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;
        const actualLimit = Math.min(limit, 100);
        
        // Dersleri çek (lean() ile optimize)
        const lessons = await Lesson.find({ group: groupId })
            .sort('orderIndex')
            .lean() // 💡 PERFORMANS: lean() kullanarak daha hızlı
            .skip(skip)
            .limit(actualLimit);
        
        // Toplam sayı
        const total = await Lesson.countDocuments({ group: groupId });
        
        res.status(200).json({
            success: true,
            lessons,
            pagination: {
                page,
                limit: actualLimit,
                total,
                pages: Math.ceil(total / actualLimit)
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Dersler çekilemedi.', error: error.message });
    }
};

// 9. Ders ID'sine Göre Etkinlikleri Getirme
// 💡 PERFORMANS: Pagination ve lean() ile optimize edildi
exports.getActivitiesForLesson = async (req, res) => {
    try {
        const { lessonId } = req.params;
        
        // 💡 PERFORMANS: Pagination desteği
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;
        const actualLimit = Math.min(limit, 100);
        
        // Etkinlikleri çek (lean() ile optimize)
        const activities = await Activity.find({ lesson: lessonId })
            .sort('createdAt')
            .lean() // 💡 PERFORMANS: lean() kullanarak daha hızlı
            .skip(skip)
            .limit(actualLimit);
        
        // Toplam sayı
        const total = await Activity.countDocuments({ lesson: lessonId });
        
        res.status(200).json({
            success: true,
            activities,
            pagination: {
                page,
                limit: actualLimit,
                total,
                pages: Math.ceil(total / actualLimit)
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Etkinlikler çekilemedi.', error: error.message });
    }
};

// 10. Bir Aktiviteye Ait Tüm Soruları Getirme
// 💡 PERFORMANS: Pagination ve lean() ile optimize edildi
exports.getQuestionsForActivity = async (req, res) => {
    try {
        const { activityId } = req.params;
        
        // 💡 PERFORMANS: Pagination desteği
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;
        const actualLimit = Math.min(limit, 100);
        
        // Activity'ye bağlı soruları getir (questionLevel kontrolü olmadan)
        const questions = await MiniQuestion.find({ 
            activity: activityId
        })
            .lean() // 💡 PERFORMANS: lean() kullanarak daha hızlı
            .skip(skip)
            .limit(actualLimit)
            .sort({ createdAt: 1 });
        
        const total = await MiniQuestion.countDocuments({ 
            activity: activityId
        });
        
        logger.info(`📊 Activity ${activityId} için ${total} soru bulundu`);
        
        res.status(200).json({
            success: true,
            questions,
            pagination: {
                page,
                limit: actualLimit,
                total,
                pages: Math.ceil(total / actualLimit)
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Sorular çekilemedi.', error: error.message });
    }
};

// 10b. Bir Derse Ait Tüm Soruları Getirme
// 💡 YENİ: Ders seviyesinde sorular için
exports.getQuestionsForLesson = async (req, res) => {
    try {
        const { lessonId } = req.params;
        
        // 💡 PERFORMANS: Pagination desteği
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;
        const actualLimit = Math.min(limit, 100);
        
        // Lesson'a bağlı soruları getir (questionLevel kontrolü olmadan)
        const questions = await MiniQuestion.find({ 
            lesson: lessonId
        })
            .lean()
            .skip(skip)
            .limit(actualLimit)
            .sort({ createdAt: 1 });
        
        const total = await MiniQuestion.countDocuments({ 
            lesson: lessonId
        });
        
        logger.info(`📊 Lesson ${lessonId} için ${total} soru bulundu`);
        
        res.status(200).json({
            success: true,
            questions,
            pagination: {
                page,
                limit: actualLimit,
                total,
                pages: Math.ceil(total / actualLimit)
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Sorular çekilemedi.', error: error.message });
    }
};

// 10c. Bir Gruba Ait Tüm Soruları Getirme
// 💡 YENİ: Grup seviyesinde sorular için
exports.getQuestionsForGroup = async (req, res) => {
    try {
        const { groupId } = req.params;
        
        // 💡 PERFORMANS: Pagination desteği
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;
        const actualLimit = Math.min(limit, 100);
        
        const questions = await MiniQuestion.find({ 
            group: groupId,
            questionLevel: 'Group' // Sadece grup seviyesindeki sorular
        })
            .lean()
            .skip(skip)
            .limit(actualLimit)
            .sort({ createdAt: 1 });
        
        const total = await MiniQuestion.countDocuments({ 
            group: groupId,
            questionLevel: 'Group'
        });
        
        res.status(200).json({
            success: true,
            questions,
            pagination: {
                page,
                limit: actualLimit,
                total,
                pages: Math.ceil(total / actualLimit)
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Sorular çekilemedi.', error: error.message });
    }
};

// 10d. Bir Soruya Ait Nested Soruları Getirme
// 💡 YENİ: İç içe sorular için
exports.getNestedQuestions = async (req, res) => {
    try {
        const { questionId } = req.params;
        
        // 💡 PERFORMANS: Pagination desteği
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;
        const actualLimit = Math.min(limit, 100);
        
        const questions = await MiniQuestion.find({ 
            parentQuestion: questionId,
            questionLevel: 'Nested' // Sadece nested sorular
        })
            .lean()
            .skip(skip)
            .limit(actualLimit)
            .sort({ createdAt: 1 });
        
        const total = await MiniQuestion.countDocuments({ 
            parentQuestion: questionId,
            questionLevel: 'Nested'
        });
        
        res.status(200).json({
            success: true,
            questions,
            pagination: {
                page,
                limit: actualLimit,
                total,
                pages: Math.ceil(total / actualLimit)
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Nested sorular çekilemedi.', error: error.message });
    }
};

// 11. Grup Kilidi Kontrolü
// 💡 PERFORMANS: Aggregation pipeline ile 6 query yerine 1 aggregation
exports.checkLockStatus = async (req, res) => {
    const { studentId, groupId } = req.params;

    try {
        // 💡 PERFORMANS: Tek aggregation pipeline ile tüm veriyi çek
        const mongoose = require('mongoose');
        const result = await Group.aggregate([
            // 1. Mevcut grubu bul
            { $match: { _id: new mongoose.Types.ObjectId(groupId) } },
            
            // 2. Kategori bilgisini join et
            {
                $lookup: {
                    from: 'categories',
                    localField: 'category',
                    foreignField: '_id',
                    as: 'categoryInfo'
                }
            },
            { $unwind: { path: '$categoryInfo', preserveNullAndEmptyArrays: true } },
            
            // 3. İlk grup kontrolü
            {
                $addFields: {
                    isFirstGroup: { $eq: ['$orderIndex', 1] }
                }
            },
            
            // 4. Önceki grubu bul
            {
                $lookup: {
                    from: 'groups',
                    let: { categoryId: '$category', currentIndex: '$orderIndex' },
                    pipeline: [
                        {
                            $match: {
                                $expr: {
                                    $and: [
                                        { $eq: ['$category', '$$categoryId'] },
                                        { $eq: ['$orderIndex', { $subtract: ['$$currentIndex', 1] }] }
                                    ]
                                }
                            }
                        }
                    ],
                    as: 'previousGroup'
                }
            },
            { $unwind: { path: '$previousGroup', preserveNullAndEmptyArrays: true } },
            
            // 5. Önceki gruba ait dersleri bul
            {
                $lookup: {
                    from: 'lessons',
                    localField: 'previousGroup._id',
                    foreignField: 'group',
                    as: 'previousLessons'
                }
            },
            
            // 6. Önceki gruba ait aktiviteleri bul
            {
                $lookup: {
                    from: 'activities',
                    localField: 'previousLessons._id',
                    foreignField: 'lesson',
                    as: 'previousActivities'
                }
            },
            
            // 7. Öğrenci ilerlemesini bul
            {
                $lookup: {
                    from: 'progresses',
                    let: { studentId: new mongoose.Types.ObjectId(studentId) },
                    pipeline: [
                        {
                            $match: {
                                $expr: { $eq: ['$student', '$$studentId'] }
                            }
                        }
                    ],
                    as: 'studentProgress'
                }
            },
            { $unwind: { path: '$studentProgress', preserveNullAndEmptyArrays: true } },
            
            // 8. Tamamlanan aktiviteleri say
            {
                $addFields: {
                    totalActivities: { $size: '$previousActivities' },
                    completedActivities: {
                        $size: {
                            $filter: {
                                input: '$studentProgress.activityRecords',
                                as: 'record',
                                cond: {
                                    $in: ['$$record.activityId', '$previousActivities._id']
                                }
                            }
                        }
                    }
                }
            },
            
            // 9. Kilit durumunu hesapla
            {
                $addFields: {
                    completionRate: {
                        $cond: {
                            if: { $gt: ['$totalActivities', 0] },
                            then: { $divide: ['$completedActivities', '$totalActivities'] },
                            else: 1
                        }
                    }
                }
            },
            {
                $addFields: {
                    isLocked: {
                        $cond: {
                            if: '$isFirstGroup',
                            then: false,
                            else: { $lt: ['$completionRate', 0.90] }
                        }
                    }
                }
            },
            
            // 10. Sadece gerekli alanları döndür
            {
                $project: {
                    isLocked: 1,
                    completionRate: 1,
                    totalActivities: 1,
                    completedActivities: 1,
                    isFirstGroup: 1,
                    message: {
                        $cond: {
                            if: '$isFirstGroup',
                            then: 'İlk grup her zaman açıktır.',
                            else: {
                                $cond: {
                                    if: { $eq: ['$totalActivities', 0] },
                                    then: 'Önceki grupta aktivite yok.',
                                    else: {
                                        $cond: {
                                            if: '$isLocked',
                                            then: 'Grup kilitli. Önceki grubu tamamlayın.',
                                            else: 'Grup açık.'
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        ]);

        if (!result || result.length === 0) {
            return res.status(404).json({ message: 'Grup bulunamadı.' });
        }

        const lockStatus = result[0];
        res.status(200).json(lockStatus);

    } catch (error) {
        res.status(500).json({ message: 'Kilit durumu kontrol edilemedi.', error: error.message });
    }
};

// 12. Aktiviteyi Tamamlandı Olarak Kaydetme
// 💡 PERFORMANS: lean() ve select() ile optimize edildi
exports.completeActivity = async (req, res) => {
    const { studentId, activityId, finalScore } = req.body;

    try {
        // Aktivite bilgilerini al (kategori bilgisi için)
        const Activity = require('../models/activity');
        const activity = await Activity.findById(activityId)
            .populate({
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
            })
            .lean();

        if (!activity) {
            return res.status(404).json({
                success: false,
                message: 'Aktivite bulunamadı.'
            });
        }

        const completionDate = new Date();
        
        // Progress'i güncelle
        const progress = await Progress.findOneAndUpdate(
            { student: studentId },
            { 
                $addToSet: { // $addToSet, aktiviteyi sadece bir kez ekler
                    activityRecords: {
                        activityId: activityId,
                        finalScore: finalScore || 0,
                        completionDate: completionDate
                    }
                },
                // 💡 PERFORMANS: overallScore'u güncelle (aggregation ile hesaplanabilir ama basit tutuyoruz)
                $inc: { overallScore: finalScore || 0 }
            },
            { 
                new: true, 
                upsert: true, // Bulamazsa yeni bir progress kaydı oluştur
                lean: true // 💡 PERFORMANS: lean() kullanarak daha hızlı
            }
        );

        // 💡 İSTATİSTİK: Günlük istatistikleri güncelle
        const DailyStatistics = require('../models/dailyStatistics');
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Bugünkü aktiviteyi kontrol et (duplicate olmaması için)
        const todayStats = await DailyStatistics.findOne({
            student: studentId,
            date: today
        }).lean();

        const categoryName = activity.lesson?.group?.category?.name || 'Genel';
        const activityTitle = activity.title || '';

        if (todayStats) {
            // Mevcut istatistikleri güncelle
            const existingActivityIds = (todayStats.activities || []).map(a => 
                a.activityId?.toString() || a.activityId?.toString()
            );

            // Eğer bu aktivite bugün daha önce eklenmemişse ekle
            if (!existingActivityIds.includes(activityId.toString())) {
                await DailyStatistics.updateOne(
                    { _id: todayStats._id },
                    {
                        $inc: { completedActivities: 1 },
                        $push: {
                            activities: {
                                activityId: activityId,
                                completionTime: completionDate,
                                score: finalScore || 0,
                                categoryName: categoryName,
                                activityTitle: activityTitle
                            }
                        },
                        $set: {
                            lastActivityId: activityId
                        }
                    }
                );
            }
        } else {
            // Yeni günlük istatistik oluştur
            await DailyStatistics.create({
                student: studentId,
                date: today,
                completedActivities: 1,
                activities: [{
                    activityId: activityId,
                    completionTime: completionDate,
                    score: finalScore || 0,
                    categoryName: categoryName,
                    activityTitle: activityTitle
                }],
                lastActivityId: activityId,
                totalTimeSpent: 0, // Oturum bitince güncellenecek
                totalReadingTime: 0,
                totalWordsRead: 0,
                averageReadingSpeed: 0
            });
        }

        res.status(200).json({
            success: true,
            progress
        });
    } catch (error) {
        logger.error('Aktivite tamamlama hatası:', error);
        res.status(400).json({ 
            success: false,
            message: 'İlerleme kaydedilemedi.', 
            error: error.message 
        });
    }
};