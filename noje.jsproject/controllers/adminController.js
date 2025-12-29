// controllers/adminController.js - Admin Panel Controller

const mongoose = require('mongoose');
const User = require('../models/user');
const Classroom = require('../models/classroom');
const Category = require('../models/category');
const Group = require('../models/group');
const Lesson = require('../models/lesson');
const Activity = require('../models/activity');
const MiniQuestion = require('../models/miniQuestion');
const Progress = require('../models/Progress');
const jwt = require('jsonwebtoken');
const { QuestionStrategyFactory } = require('../utils/questionStrategies');
const logger = require('../config/logger');

// Soru tiplerini ve form alanlarını döndür
exports.getQuestionTypes = async (req, res) => {
    try {
        const availableTypes = QuestionStrategyFactory.getAvailableTypes();
        const formFieldsMap = {};
        
        // Her tip için form alanlarını al
        availableTypes.forEach(type => {
            try {
                formFieldsMap[type] = QuestionStrategyFactory.getFormFields(type);
            } catch (error) {
                logger.error(`Form fields alınamadı ${type}:`, error.message);
            }
        });

        res.status(200).json({
            success: true,
            data: {
                types: availableTypes,
                formFields: formFieldsMap
            }
        });
    } catch (error) {
        logger.error('getQuestionTypes hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Soru tipleri alınamadı',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// JWT token oluşturma yardımcı fonksiyonu
const generateToken = (userId) => {
    // 🔒 SECURITY: JWT_SECRET environment variable zorunlu
    if (!process.env.JWT_SECRET) {
        throw new Error('JWT_SECRET environment variable tanımlı değil!');
    }
    return jwt.sign(
        { userId },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRE || '30d' }
    );
};

// Admin girişi
exports.adminLogin = async (req, res) => {
    try {
        const { email, password } = req.body;

        // Input validation
        if (!email || !password) {
            return res.status(400).json({
                success: false,
                message: 'E-posta ve şifre gereklidir.'
            });
        }

        // Email format kontrolü
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({
                success: false,
                message: 'Geçerli bir e-posta adresi giriniz.'
            });
        }

        // Kullanıcıyı bul
        const user = await User.findOne({ email: email.trim().toLowerCase() }).select('+password');

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Geçersiz e-posta veya şifre.'
            });
        }

        // Şifre kontrolü
        if (!user.password) {
            return res.status(401).json({
                success: false,
                message: 'Geçersiz e-posta veya şifre.'
            });
        }

        // Şifre karşılaştırması (comparePassword metodu kullanılıyor)
        let passwordMatch = false;
        try {
            passwordMatch = await user.comparePassword(password);
        } catch (matchError) {
            logger.error('Şifre karşılaştırma hatası:', matchError);
            return res.status(401).json({
                success: false,
                message: 'Geçersiz e-posta veya şifre.'
            });
        }

        if (!passwordMatch) {
            return res.status(401).json({
                success: false,
                message: 'Geçersiz e-posta veya şifre.'
            });
        }

        // Admin rol kontrolü
        logger.info('🔍 Kullanıcı rolü kontrol ediliyor:', {
            email: user.email,
            role: user.role,
            roleType: typeof user.role,
            isAdmin: user.role === 'Admin',
            isSuperAdmin: user.role === 'SuperAdmin'
        });
        
        if (user.role !== 'Admin' && user.role !== 'SuperAdmin') {
            logger.error('❌ Admin olmayan kullanıcı giriş denemesi:', user.email, 'Rol:', user.role);
            return res.status(403).json({
                success: false,
                message: `Sadece adminler giriş yapabilir. Mevcut rolünüz: ${user.role || 'tanımsız'}`
            });
        }

        logger.info('✅ Admin rolü onaylandı:', user.role);

        // Token oluştur (ObjectId'yi string'e çevir)
        const token = generateToken(user._id.toString());

        const responseData = {
            success: true,
            message: 'Giriş başarılı',
            token,
            user: {
                _id: user._id,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                role: user.role
            }
        };
        
        logger.info('✅ Login başarılı, response gönderiliyor:', {
            email: user.email,
            role: user.role,
            hasToken: !!token
        });

        res.status(200).json(responseData);
    } catch (error) {
        logger.error('Admin login hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Giriş yapılırken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// İstatistikler
exports.getStatistics = async (req, res) => {
    try {
        const totalUsers = await User.countDocuments();
        const totalTeachers = await User.countDocuments({ role: 'Teacher' });
        const totalStudents = await User.countDocuments({ role: 'Student' });
        const totalAdmins = await User.countDocuments({ role: 'Admin' });
        const totalSuperAdmins = await User.countDocuments({ role: 'SuperAdmin' });
        const totalClassrooms = await Classroom.countDocuments();
        const totalCategories = await Category.countDocuments();
        const totalGroups = await Group.countDocuments();
        const totalLessons = await Lesson.countDocuments();
        const totalActivities = await Activity.countDocuments();
        const totalQuestions = await MiniQuestion.countDocuments();

        res.status(200).json({
            success: true,
            data: {
                users: {
                    total: totalUsers,
                    teachers: totalTeachers,
                    students: totalStudents,
                    admins: totalAdmins,
                    superAdmins: totalSuperAdmins
                },
                classrooms: {
                    total: totalClassrooms
                },
                content: {
                    categories: totalCategories,
                    groups: totalGroups,
                    lessons: totalLessons,
                    activities: totalActivities,
                    questions: totalQuestions
                }
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'İstatistikler getirilirken hata oluştu',
            error: error.message
        });
    }
};

// ======================================================================
// KULLANICI YÖNETİMİ
// ======================================================================

// Tüm kullanıcıları listele
exports.getAllUsers = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const skip = (page - 1) * limit;
        const role = req.query.role;

        let filter = {};
        if (role) {
            filter.role = role;
        }

        const users = await User.find(filter)
            .select('-password')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean();

        const total = await User.countDocuments(filter);

        // 💡 Öğrenciler için öğretmen bilgisini, öğretmenler için sınıf bilgisini ekle
        const usersWithTeacher = await Promise.all(
            users.map(async (user) => {
                if (user.role === 'Student') {
                    // Öğrencinin hangi sınıfta olduğunu bul
                    const classroom = await Classroom.findOne({ students: user._id })
                        .populate('teacher', 'firstName lastName')
                        .lean();
                    
                    if (classroom && classroom.teacher) {
                        return {
                            ...user,
                            teacher: {
                                id: classroom.teacher._id,
                                firstName: classroom.teacher.firstName,
                                lastName: classroom.teacher.lastName,
                                fullName: `${classroom.teacher.firstName} ${classroom.teacher.lastName}`
                            },
                            classroom: {
                                id: classroom._id,
                                name: classroom.name
                            }
                        };
                    }
                } else if (user.role === 'Teacher') {
                    // Öğretmenin sınıflarını bul
                    const classrooms = await Classroom.find({ teacher: user._id })
                        .select('name students')
                        .lean();
                    
                    if (classrooms && classrooms.length > 0) {
                        return {
                            ...user,
                            classrooms: classrooms.map(c => ({
                                id: c._id,
                                name: c.name,
                                studentCount: c.students ? c.students.length : 0
                            }))
                        };
                    }
                }
                return user;
            })
        );

        res.status(200).json({
            success: true,
            data: usersWithTeacher,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Kullanıcılar getirilirken hata oluştu',
            error: error.message
        });
    }
};

// Kullanıcı detayı
exports.getUserById = async (req, res) => {
    try {
        const user = await User.findById(req.params.id).select('-password').lean();

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'Kullanıcı bulunamadı.'
            });
        }

        // 💡 Öğrenci ise öğretmen bilgisini de ekle
        let userWithTeacher = user;
        if (user.role === 'Student') {
            const classroom = await Classroom.findOne({ students: user._id })
                .populate('teacher', 'firstName lastName')
                .lean();
            
            if (classroom && classroom.teacher) {
                userWithTeacher = {
                    ...user,
                    teacher: {
                        id: classroom.teacher._id,
                        firstName: classroom.teacher.firstName,
                        lastName: classroom.teacher.lastName,
                        fullName: `${classroom.teacher.firstName} ${classroom.teacher.lastName}`
                    },
                    classroom: {
                        id: classroom._id,
                        name: classroom.name
                    }
                };
            }
        }

        res.status(200).json({
            success: true,
            data: userWithTeacher
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Kullanıcı getirilirken hata oluştu',
            error: error.message
        });
    }
};

// Yeni kullanıcı oluştur
exports.createUser = async (req, res) => {
    try {
        logger.info('🔄 createUser çağrıldı');
        const { firstName, lastName, email, password, role, classroomId } = req.body;
        logger.info('📥 Gelen veri:', { firstName, lastName, email, role: role, passwordLength: password ? password.length : 0, classroomId });

        if (!firstName || !lastName || !role) {
            return res.status(400).json({
                success: false,
                message: 'Ad, soyad ve rol zorunludur.'
            });
        }

        // Öğrenci için sınıf kontrolü (API'deki gibi sadece sınıf ID'sine göre)
        if (role === 'Student') {
            // Sınıf seçimi zorunlu
            if (!classroomId) {
                return res.status(400).json({
                    success: false,
                    message: 'Öğrenci eklemek için sınıf seçimi zorunludur.'
                });
            }
            
            // Sınıfın geçerli olduğunu kontrol et
            const selectedClassroom = await Classroom.findById(classroomId).populate('teacher', 'firstName lastName').lean();
            if (!selectedClassroom) {
                return res.status(404).json({
                    success: false,
                    message: 'Seçilen sınıf bulunamadı.'
                });
            }
        }

        if ((role === 'Admin' || role === 'Teacher' || role === 'SuperAdmin') && (!email || !password)) {
            return res.status(400).json({
                success: false,
                message: 'Admin ve öğretmen için e-posta ve şifre zorunludur.'
            });
        }

        // Şifre validasyonu (Admin ve Teacher için - büyük harf ve sayı zorunlu)
        if (password && (role === 'Admin' || role === 'Teacher' || role === 'SuperAdmin')) {
            if (password.length < 6) {
                return res.status(400).json({
                    success: false,
                    message: 'Şifre en az 6 karakter olmalıdır.'
                });
            }
            // Büyük harf ve sayı kontrolü (küçük harf isteğe bağlı)
            if (!/^(?=.*[A-Z])(?=.*\d)/.test(password)) {
                return res.status(400).json({
                    success: false,
                    message: 'Şifre en az bir büyük harf ve bir rakam içermelidir (küçük harf isteğe bağlıdır).'
                });
            }
        }

        const userData = {
            firstName,
            lastName,
            role
        };

        if (email) userData.email = email;
        if (password) userData.password = password;

        logger.info('👤 User oluşturuluyor:', userData);
        const user = await User.create(userData);
        logger.info('✅ User oluşturuldu:', { _id: user._id, firstName: user.firstName, lastName: user.lastName, role: user.role });

        // 💡 KRİTİK: Eğer role Teacher ise, otomatik sınıf oluştur
        if (role === 'Teacher') {
            try {
                const newClassroom = await Classroom.create({
                    name: `${firstName} ${lastName}'in Sınıfı`,
                    teacher: user._id,
                    students: []
                });
                logger.info('✅ Öğretmen için otomatik sınıf oluşturuldu:', { 
                    classroomId: newClassroom._id, 
                    classroomName: newClassroom.name,
                    teacherId: user._id 
                });
            } catch (classroomError) {
                logger.error('❌ Öğretmen için sınıf oluşturulurken hata:', classroomError);
                // Hata olsa bile devam et, sadece log'la (öğretmen zaten oluşturuldu)
            }
        }

        // 💡 KRİTİK: Eğer role Student ise, sınıfa ekle ve students koleksiyonuna da ekle
        if (role === 'Student') {
            // Öğrenciyi sınıfa ekle
            try {
                await Classroom.findByIdAndUpdate(
                    classroomId,
                    { $addToSet: { students: user._id } },
                    { new: true }
                );
                logger.info('✅ Öğrenci sınıfa eklendi:', { studentId: user._id, classroomId: classroomId });
            } catch (classroomError) {
                logger.error('❌ Öğrenci sınıfa eklenirken hata:', classroomError);
                // Hata olsa bile devam et, sadece log'la
            }
            logger.info('🎓 Role Student, students koleksiyonuna ekleniyor...');
            try {
                // MongoDB bağlantısının hazır olduğundan emin ol
                const db = mongoose.connection.db;
                if (!db) {
                    logger.error('❌ MongoDB bağlantısı hazır değil! readyState:', mongoose.connection.readyState);
                    // Bağlantı hazır değilse bekle
                    if (mongoose.connection.readyState === 0 || mongoose.connection.readyState === 3) {
                        logger.error('❌ MongoDB bağlantısı kapalı!');
                    } else {
                        logger.info('⏳ MongoDB bağlantısı bekleniyor...');
                        await new Promise((resolve) => {
                            if (mongoose.connection.readyState === 1) {
                                resolve();
                            } else {
                                mongoose.connection.once('connected', resolve);
                                setTimeout(resolve, 1000); // 1 saniye timeout
                            }
                        });
                    }
                }
                
                const finalDb = mongoose.connection.db;
                if (finalDb) {
                    const studentData = {
                        _id: user._id,
                        firstName: user.firstName,
                        lastName: user.lastName,
                        role: 'Student',
                        createdAt: user.createdAt || new Date(),
                        updatedAt: new Date()
                    };

                    logger.info('🔄 Admin panelinden öğrenci students koleksiyonuna ekleniyor:', {
                        _id: studentData._id,
                        firstName: studentData.firstName,
                        lastName: studentData.lastName,
                        role: studentData.role
                    });

                    const studentsCollection = finalDb.collection('students');
                    
                    // Önce mevcut kaydı kontrol et
                    const existing = await studentsCollection.findOne({ _id: user._id });
                    
                    if (existing) {
                        // Mevcut kaydı güncelle
                        const updateResult = await studentsCollection.updateOne(
                            { _id: user._id },
                            { 
                                $set: { 
                                    firstName: user.firstName,
                                    lastName: user.lastName,
                                    role: 'Student',
                                    updatedAt: new Date()
                                }
                            }
                        );
                        logger.info('✅ Mevcut kayıt Student olarak güncellendi:', updateResult.modifiedCount > 0 ? 'Güncellendi' : 'Değişiklik yok');
                    } else {
                        // Yeni kayıt ekle
                        const insertResult = await studentsCollection.insertOne(studentData);
                        if (insertResult.insertedId) {
                            logger.info('✅ Öğrenci students koleksiyonuna başarıyla eklendi:', insertResult.insertedId);
                        } else {
                            logger.error('❌ Students koleksiyonuna ekleme başarısız oldu - insertedId yok');
                        }
                    }
                } else {
                    logger.error('❌ MongoDB bağlantısı hala hazır değil!');
                }
            } catch (insertError) {
                // Eğer duplicate key hatası varsa (aynı _id zaten varsa), devam et
                if (insertError.code === 11000) {
                    logger.info('⚠️ Öğrenci zaten students koleksiyonunda mevcut (duplicate key), güncelleniyor...');
                    try {
                        const updateResult = await mongoose.connection.db.collection('students').updateOne(
                            { _id: user._id },
                            { $set: { role: 'Student', firstName: user.firstName, lastName: user.lastName, updatedAt: new Date() } }
                        );
                        logger.info('✅ Mevcut kayıt Student olarak güncellendi:', updateResult.modifiedCount > 0 ? 'Güncellendi' : 'Değişiklik yok');
                    } catch (updateError) {
                        logger.error('⚠️ Mevcut kayıt güncellenirken hata:', updateError);
                    }
                } else {
                    logger.error('❌ Students koleksiyonuna ekleme hatası:', insertError);
                    logger.error('❌ Hata detayı:', {
                        code: insertError.code,
                        message: insertError.message,
                        stack: insertError.stack
                    });
                    // Hata olsa bile kullanıcı oluşturuldu, sadece log'la
                }
            }
        }

        res.status(201).json({
            success: true,
            message: 'Kullanıcı başarıyla oluşturuldu.',
            data: {
                _id: user._id,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                role: user.role
            }
        });
    } catch (error) {
        if (error.code === 11000) {
            return res.status(400).json({
                success: false,
                message: 'Bu e-posta adresi zaten kullanılıyor.'
            });
        }
        res.status(500).json({
            success: false,
            message: 'Kullanıcı oluşturulurken hata oluştu',
            error: error.message
        });
    }
};

// Kullanıcı güncelle
exports.updateUser = async (req, res) => {
    try {
        const { firstName, lastName, email, password, role } = req.body;
        const user = await User.findById(req.params.id);

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'Kullanıcı bulunamadı.'
            });
        }

        const oldRole = user.role;
        const newRole = role || oldRole;

        if (firstName) user.firstName = firstName;
        if (lastName) user.lastName = lastName;
        if (email) user.email = email;
        if (role) user.role = role;

        // Şifre güncelleme validasyonu (Admin, Teacher, SuperAdmin için)
        if (password && (user.role === 'Admin' || user.role === 'Teacher' || user.role === 'SuperAdmin' || role === 'Admin' || role === 'Teacher' || role === 'SuperAdmin')) {
            if (password.length < 6) {
                return res.status(400).json({
                    success: false,
                    message: 'Şifre en az 6 karakter olmalıdır.'
                });
            }
            // Büyük harf ve sayı kontrolü (küçük harf isteğe bağlı)
            if (!/^(?=.*[A-Z])(?=.*\d)/.test(password)) {
                return res.status(400).json({
                    success: false,
                    message: 'Şifre en az bir büyük harf ve bir rakam içermelidir (küçük harf isteğe bağlıdır).'
                });
            }
            user.password = password; // Otomatik hash'lenecek
        }

        await user.save();

        // 💡 KRİTİK: Role değişikliği durumunda students koleksiyonunu güncelle
        // Eğer role Student olduysa veya zaten Student ise, students koleksiyonuna ekle/güncelle
        if (newRole === 'Student') {
            const studentData = {
                _id: user._id,
                firstName: user.firstName,
                lastName: user.lastName,
                role: 'Student',
                updatedAt: new Date()
            };

            try {
                // Önce mevcut kaydı kontrol et
                const existingStudent = await mongoose.connection.db.collection('students').findOne({ _id: user._id });
                
                if (existingStudent) {
                    // Mevcut kaydı güncelle
                    logger.info('🔄 Admin panelinden öğrenci students koleksiyonunda güncelleniyor:', studentData);
                    await mongoose.connection.db.collection('students').updateOne(
                        { _id: user._id },
                        { $set: studentData }
                    );
                    logger.info('✅ Öğrenci students koleksiyonunda güncellendi');
                } else {
                    // Yeni kayıt ekle
                    studentData.createdAt = new Date();
                    logger.info('🔄 Admin panelinden öğrenci students koleksiyonuna ekleniyor:', studentData);
                    const insertResult = await mongoose.connection.db.collection('students').insertOne(studentData);
                    if (insertResult.insertedId) {
                        logger.info('✅ Öğrenci students koleksiyonuna başarıyla eklendi:', insertResult.insertedId);
                    }
                }
            } catch (error) {
                logger.error('❌ Students koleksiyonuna ekleme/güncelleme hatası:', error);
                // Hata olsa bile kullanıcı güncellendi, sadece log'la
            }
        } else if (oldRole === 'Student' && newRole !== 'Student') {
            // Eğer role Student'dan başka bir role'e değiştiyse, students koleksiyonundan sil
            try {
                logger.info('🔄 Role Student değil, students koleksiyonundan siliniyor:', user._id);
                await mongoose.connection.db.collection('students').deleteOne({ _id: user._id });
                logger.info('✅ Kullanıcı students koleksiyonundan silindi');
            } catch (error) {
                logger.error('❌ Students koleksiyonundan silme hatası:', error);
            }
        }

        res.status(200).json({
            success: true,
            message: 'Kullanıcı başarıyla güncellendi.',
            data: {
                _id: user._id,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                role: user.role
            }
        });
    } catch (error) {
        if (error.code === 11000) {
            return res.status(400).json({
                success: false,
                message: 'Bu e-posta adresi zaten kullanılıyor.'
            });
        }
        res.status(500).json({
            success: false,
            message: 'Kullanıcı güncellenirken hata oluştu',
            error: error.message
        });
    }
};

// Kullanıcı sil
exports.deleteUser = async (req, res) => {
    try {
        // İstek yapan kullanıcının rolünü kontrol et
        const requestingUser = req.user;
        
        if (!requestingUser) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Kullanıcı bilgisi bulunamadı.'
            });
        }

        // Silinecek kullanıcıyı bul (silmeden önce rolünü kontrol etmek için)
        const userToDelete = await User.findById(req.params.id);

        if (!userToDelete) {
            return res.status(404).json({
                success: false,
                message: 'Kullanıcı bulunamadı.'
            });
        }

        // 💡 GÜVENLİK: Admin veya SuperAdmin silme yetkisi sadece SuperAdmin'de
        if (userToDelete.role === 'Admin' || userToDelete.role === 'SuperAdmin') {
            // Sadece SuperAdmin admin silebilir
            if (requestingUser.role !== 'SuperAdmin') {
                return res.status(403).json({
                    success: false,
                    message: 'Erişim reddedildi: Admin veya SuperAdmin silme yetkisi sadece SuperAdmin\'de.'
                });
            }
        }

        // Kullanıcıyı sil
        await User.findByIdAndDelete(req.params.id);

        res.status(200).json({
            success: true,
            message: 'Kullanıcı başarıyla silindi.'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Kullanıcı silinirken hata oluştu',
            error: error.message
        });
    }
};

// ======================================================================
// SINIF YÖNETİMİ
// ======================================================================

// Tüm sınıfları listele
exports.getAllClassrooms = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const skip = (page - 1) * limit;

        const classrooms = await Classroom.find()
            .populate('teacher', 'firstName lastName')
            .populate('students', 'firstName lastName')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean();

        const total = await Classroom.countDocuments();

        res.status(200).json({
            success: true,
            data: classrooms,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Sınıflar getirilirken hata oluştu',
            error: error.message
        });
    }
};

// ======================================================================
// ETKİNLİK YÖNETİMİ
// ======================================================================

// Tüm kategorileri listele
exports.getAllCategories = async (req, res) => {
    try {
        const categories = await Category.find().sort({ name: 1 }).lean();
        res.status(200).json({
            success: true,
            data: categories
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Kategoriler getirilirken hata oluştu',
            error: error.message
        });
    }
};

// Kategoriye göre grupları listele
exports.getGroupsByCategory = async (req, res) => {
    try {
        const groups = await Group.find({ category: req.params.categoryId })
            .populate('category', 'name')
            .sort({ orderIndex: 1 })
            .lean();
        res.status(200).json({
            success: true,
            data: groups
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Gruplar getirilirken hata oluştu',
            error: error.message
        });
    }
};

// Gruba göre dersleri listele
exports.getLessonsByGroup = async (req, res) => {
    try {
        const lessons = await Lesson.find({ group: req.params.groupId })
            .populate('group', 'name')
            .sort({ orderIndex: 1 })
            .lean();
        res.status(200).json({
            success: true,
            data: lessons
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Dersler getirilirken hata oluştu',
            error: error.message
        });
    }
};

// Tüm etkinlikleri listele
exports.getAllActivities = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const skip = (page - 1) * limit;

        const filter = {};
        if (req.query.lessonId) {
            filter.lesson = req.query.lessonId;
        }

        const activities = await Activity.find(filter)
            .populate({
                path: 'lesson',
                select: 'title targetContent',
                populate: {
                    path: 'group',
                    select: 'name',
                    populate: {
                        path: 'category',
                        select: 'name'
                    }
                }
            })
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean();

        const total = await Activity.countDocuments(filter);

        res.status(200).json({
            success: true,
            data: activities,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        logger.error('getAllActivities hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Etkinlikler getirilirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Etkinlik detayı (sorularıyla birlikte)
exports.getActivityById = async (req, res) => {
    try {
        const activityId = req.params.id;
        
        if (!activityId || !activityId.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(400).json({
                success: false,
                message: 'Geçersiz etkinlik ID formatı.'
            });
        }

        const activity = await Activity.findById(activityId)
            .populate({
                path: 'lesson',
                select: 'title targetContent',
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
                message: 'Etkinlik bulunamadı.'
            });
        }

        // Etkinliğe ait soruları getir
        const questions = await MiniQuestion.find({ activity: activityId })
            .sort({ createdAt: 1 })
            .lean();

        res.status(200).json({
            success: true,
            data: {
                ...activity,
                questions: questions
            }
        });
    } catch (error) {
        logger.error('getActivityById hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Etkinlik getirilirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Yeni etkinlik oluştur
exports.createActivity = async (req, res) => {
    try {
        const { title, lesson, type, durationMinutes, activityType, mediaType, mediaStorage, mediaFileId, mediaFiles, mediaUrl, textLines, readingDuration } = req.body;

        if (!title || !lesson) {
            return res.status(400).json({
                success: false,
                message: 'Başlık ve ders seçimi zorunludur.'
            });
        }

        // Ders ID formatını kontrol et
        if (!lesson.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(400).json({
                success: false,
                message: 'Geçersiz ders ID formatı.'
            });
        }

        // Ders var mı kontrol et
        const lessonExists = await Lesson.findById(lesson);
        if (!lessonExists) {
            return res.status(404).json({
                success: false,
                message: 'Seçilen ders bulunamadı.'
            });
        }

        // mediaFiles array'ini hazırla (birden fazla medya dosyası için)
        let processedMediaFiles = [];
        if (mediaFiles && Array.isArray(mediaFiles) && mediaFiles.length > 0) {
            processedMediaFiles = mediaFiles.map((file, index) => ({
                fileId: file.fileId || file._id,
                mediaType: file.mediaType || 'Image',
                order: file.order !== undefined ? file.order : index
            }));
        }

        // Geriye dönük uyumluluk: mediaFileId varsa ve mediaFiles yoksa, mediaFiles'e ekle
        if (mediaFileId && processedMediaFiles.length === 0) {
            processedMediaFiles = [{
                fileId: mediaFileId,
                mediaType: mediaType || 'Image',
                order: 0
            }];
        }

        const activity = await Activity.create({
            title: title.trim(),
            lesson,
            type: type || 'Quiz',
            durationMinutes: durationMinutes || 5,
            activityType: activityType || 'Text',
            mediaType: mediaType || 'None',
            mediaStorage: mediaStorage || 'None',
            mediaFileId: mediaFileId || null,
            mediaFiles: processedMediaFiles,
            mediaUrl: mediaUrl || null,
            // Okuma metni alanları
            textLines: textLines && Array.isArray(textLines) ? textLines.filter(line => line && line.trim()) : [],
            readingDuration: readingDuration || null
        });

        const populatedActivity = await Activity.findById(activity._id)
            .populate({
                path: 'lesson',
                select: 'title targetContent',
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

        res.status(201).json({
            success: true,
            message: 'Etkinlik başarıyla oluşturuldu.',
            data: populatedActivity
        });
    } catch (error) {
        logger.error('createActivity hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Etkinlik oluşturulurken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Etkinlik güncelle
exports.updateActivity = async (req, res) => {
    try {
        const { title, lesson, type, durationMinutes } = req.body;
        const activityId = req.params.id;

        const activity = await Activity.findById(activityId);
        if (!activity) {
            return res.status(404).json({
                success: false,
                message: 'Etkinlik bulunamadı.'
            });
        }

        if (title) activity.title = title;
        if (lesson) {
            const lessonExists = await Lesson.findById(lesson);
            if (!lessonExists) {
                return res.status(404).json({
                    success: false,
                    message: 'Seçilen ders bulunamadı.'
                });
            }
            activity.lesson = lesson;
        }
        if (type) activity.type = type;
        if (durationMinutes !== undefined) activity.durationMinutes = durationMinutes;

        await activity.save();

        const populatedActivity = await Activity.findById(activity._id)
            .populate({
                path: 'lesson',
                select: 'title targetContent',
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

        res.status(200).json({
            success: true,
            message: 'Etkinlik başarıyla güncellendi.',
            data: populatedActivity
        });
    } catch (error) {
        logger.error('updateActivity hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Etkinlik güncellenirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Etkinlik sil
exports.deleteActivity = async (req, res) => {
    try {
        const activityId = req.params.id;

        if (!activityId || !activityId.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(400).json({
                success: false,
                message: 'Geçersiz etkinlik ID formatı.'
            });
        }

        // Etkinlik var mı kontrol et
        const activity = await Activity.findById(activityId);
        if (!activity) {
            return res.status(404).json({
                success: false,
                message: 'Etkinlik bulunamadı.'
            });
        }

        // Etkinliğe ait soruları da sil
        await MiniQuestion.deleteMany({ activity: activityId });

        // Etkinliği sil
        await Activity.findByIdAndDelete(activityId);

        res.status(200).json({
            success: true,
            message: 'Etkinlik ve bağlı sorular başarıyla silindi.'
        });
    } catch (error) {
        logger.error('deleteActivity hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Etkinlik silinirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// ======================================================================
// İÇERİK YÖNETİMİ (Content Management)
// ======================================================================

// Kategori sil
exports.deleteCategory = async (req, res) => {
    try {
        const categoryId = req.params.id;

        if (!categoryId || !categoryId.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(400).json({
                success: false,
                message: 'Geçersiz kategori ID formatı.'
            });
        }

        // Kategori var mı kontrol et
        const category = await Category.findById(categoryId);
        if (!category) {
            return res.status(404).json({
                success: false,
                message: 'Kategori bulunamadı.'
            });
        }

        // Kategoriye ait grupları kontrol et
        const groupsCount = await Group.countDocuments({ category: categoryId });
        if (groupsCount > 0) {
            return res.status(400).json({
                success: false,
                message: `Bu kategoriye ait ${groupsCount} grup bulunmaktadır. Önce grupları silin veya başka bir kategoriye taşıyın.`
            });
        }

        // Kategoriyi sil
        await Category.findByIdAndDelete(categoryId);

        res.status(200).json({
            success: true,
            message: 'Kategori başarıyla silindi.'
        });
    } catch (error) {
        logger.error('deleteCategory hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Kategori silinirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Kategori oluştur
exports.createCategory = async (req, res) => {
    try {
        const { name, description, flowType, iconUrl } = req.body;

        logger.info('createCategory - Request body:', req.body);

        if (!name) {
            return res.status(400).json({
                success: false,
                message: 'Kategori adı zorunludur.'
            });
        }

        // Category model'inin yüklü olduğunu kontrol et
        if (!Category) {
            logger.error('createCategory - Category model yüklenemedi!');
            return res.status(500).json({
                success: false,
                message: 'Category model yüklenemedi. Sunucu yapılandırmasını kontrol edin.'
            });
        }

        const category = await Category.create({
            name: name.trim(),
            description: description || '',
            flowType: flowType || 'Default',
            iconUrl: iconUrl || ''
        });

        logger.info('createCategory - Kategori oluşturuldu:', category._id);

        res.status(201).json({
            success: true,
            message: 'Kategori başarıyla oluşturuldu.',
            data: category
        });
    } catch (error) {
        logger.error('createCategory hatası:', error);
        logger.error('createCategory - Error stack:', error.stack);
        logger.error('createCategory - Error name:', error.name);
        logger.error('createCategory - Error message:', error.message);
        
        if (error.code === 11000) {
            return res.status(400).json({
                success: false,
                message: 'Bu kategori adı zaten kullanılıyor.'
            });
        }
        
        // Validation hatası
        if (error.name === 'ValidationError') {
            const messages = Object.values(error.errors).map(err => err.message).join(', ');
            return res.status(400).json({
                success: false,
                message: 'Validasyon hatası: ' + messages,
                error: process.env.NODE_ENV === 'development' ? error.message : 'Validasyon hatası'
            });
        }

        res.status(500).json({
            success: false,
            message: 'Kategori oluşturulurken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası',
            details: process.env.NODE_ENV === 'development' ? error.stack : undefined
        });
    }
};

// Grup oluştur
exports.createGroup = async (req, res) => {
    try {
        const { name, category, orderIndex, groupType, mediaType, mediaStorage, mediaFileId, mediaFiles, mediaUrl } = req.body;

        if (!name || !category) {
            return res.status(400).json({
                success: false,
                message: 'Grup adı ve kategori seçimi zorunludur.'
            });
        }

        // Kategori var mı kontrol et
        const categoryExists = await Category.findById(category);
        if (!categoryExists) {
            return res.status(404).json({
                success: false,
                message: 'Seçilen kategori bulunamadı.'
            });
        }

        // mediaFiles array'ini hazırla (birden fazla medya dosyası için)
        let processedMediaFiles = [];
        if (mediaFiles && Array.isArray(mediaFiles) && mediaFiles.length > 0) {
            processedMediaFiles = mediaFiles.map((file, index) => ({
                fileId: file.fileId || file._id,
                mediaType: file.mediaType || 'Image',
                order: file.order !== undefined ? file.order : index
            }));
        }

        // Geriye dönük uyumluluk: mediaFileId varsa ve mediaFiles yoksa, mediaFiles'e ekle
        if (mediaFileId && processedMediaFiles.length === 0) {
            processedMediaFiles = [{
                fileId: mediaFileId,
                mediaType: mediaType || 'Image',
                order: 0
            }];
        }

        const group = await Group.create({
            name: name.trim(),
            category,
            orderIndex: orderIndex || 0,
            groupType: groupType || 'Text',
            mediaType: mediaType || 'None',
            mediaStorage: mediaStorage || 'None',
            mediaFileId: mediaFileId || null,
            mediaFiles: processedMediaFiles,
            mediaUrl: mediaUrl || null
        });

        const populatedGroup = await Group.findById(group._id)
            .populate('category', 'name')
            .lean();

        res.status(201).json({
            success: true,
            message: 'Grup başarıyla oluşturuldu.',
            data: populatedGroup
        });
    } catch (error) {
        logger.error('createGroup hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Grup oluşturulurken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Grup sil
exports.deleteGroup = async (req, res) => {
    try {
        const groupId = req.params.id;

        if (!groupId || !groupId.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(400).json({
                success: false,
                message: 'Geçersiz grup ID formatı.'
            });
        }

        // Grup var mı kontrol et
        const group = await Group.findById(groupId);
        if (!group) {
            return res.status(404).json({
                success: false,
                message: 'Grup bulunamadı.'
            });
        }

        // Gruba ait dersleri kontrol et
        const lessonsCount = await Lesson.countDocuments({ group: groupId });
        if (lessonsCount > 0) {
            return res.status(400).json({
                success: false,
                message: `Bu gruba ait ${lessonsCount} ders bulunmaktadır. Önce dersleri silin veya başka bir gruba taşıyın.`
            });
        }

        // Grubu sil
        await Group.findByIdAndDelete(groupId);

        res.status(200).json({
            success: true,
            message: 'Grup başarıyla silindi.'
        });
    } catch (error) {
        logger.error('deleteGroup hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Grup silinirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Ders oluştur
// Ders sil
exports.deleteLesson = async (req, res) => {
    try {
        const lessonId = req.params.id;

        if (!lessonId || !lessonId.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(400).json({
                success: false,
                message: 'Geçersiz ders ID formatı.'
            });
        }

        // Ders var mı kontrol et
        const lesson = await Lesson.findById(lessonId);
        if (!lesson) {
            return res.status(404).json({
                success: false,
                message: 'Ders bulunamadı.'
            });
        }

        // Derse ait etkinlikleri kontrol et
        const activitiesCount = await Activity.countDocuments({ lesson: lessonId });
        if (activitiesCount > 0) {
            return res.status(400).json({
                success: false,
                message: `Bu derse ait ${activitiesCount} etkinlik bulunmaktadır. Önce etkinlikleri silin veya başka bir derse taşıyın.`
            });
        }

        // Dersi sil
        await Lesson.findByIdAndDelete(lessonId);

        res.status(200).json({
            success: true,
            message: 'Ders başarıyla silindi.'
        });
    } catch (error) {
        logger.error('deleteLesson hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Ders silinirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Ders oluştur
exports.createLesson = async (req, res) => {
    try {
        const { title, group, targetContent, orderIndex, lessonType, mediaType, mediaStorage, mediaFileId, mediaFiles, mediaUrl } = req.body;

        if (!title || !group || !targetContent) {
            return res.status(400).json({
                success: false,
                message: 'Ders başlığı, grup ve hedef içerik zorunludur.'
            });
        }

        // Grup var mı kontrol et
        const groupExists = await Group.findById(group);
        if (!groupExists) {
            return res.status(404).json({
                success: false,
                message: 'Seçilen grup bulunamadı.'
            });
        }

        // mediaFiles array'ini hazırla (birden fazla medya dosyası için)
        let processedMediaFiles = [];
        if (mediaFiles && Array.isArray(mediaFiles) && mediaFiles.length > 0) {
            processedMediaFiles = mediaFiles.map((file, index) => ({
                fileId: file.fileId || file._id,
                mediaType: file.mediaType || 'Image',
                order: file.order !== undefined ? file.order : index
            }));
        }

        // Geriye dönük uyumluluk: mediaFileId varsa ve mediaFiles yoksa, mediaFiles'e ekle
        if (mediaFileId && processedMediaFiles.length === 0) {
            processedMediaFiles = [{
                fileId: mediaFileId,
                mediaType: mediaType || 'Image',
                order: 0
            }];
        }

        const lesson = await Lesson.create({
            title: title.trim(),
            group,
            targetContent: targetContent.trim(),
            orderIndex: orderIndex || 0,
            lessonType: lessonType || 'Text',
            mediaType: mediaType || 'None',
            mediaStorage: mediaStorage || 'None',
            mediaFileId: mediaFileId || null,
            mediaFiles: processedMediaFiles,
            mediaUrl: mediaUrl || null
        });

        const populatedLesson = await Lesson.findById(lesson._id)
            .populate('group', 'name')
            .populate({
                path: 'group',
                populate: {
                    path: 'category',
                    select: 'name'
                }
            })
            .lean();

        res.status(201).json({
            success: true,
            message: 'Ders başarıyla oluşturuldu.',
            data: populatedLesson
        });
    } catch (error) {
        logger.error('createLesson hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Ders oluşturulurken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Soru oluştur
exports.createQuestion = async (req, res) => {
    try {
        logger.info('createQuestion - Gelen veri:', JSON.stringify(req.body, null, 2));
        
        const { 
            activity, 
            lesson,
            group, 
            parentQuestion, 
            questionType,
            questionFormat, // Yeni: Dinamik soru formatı (ONLY_TEXT, AUDIO_TEXT, vb.)
            questionLevel, // Frontend'den gelen questionLevel
            correctAnswer, 
            data, 
            mediaFileId, 
            mediaFiles, 
            mediaUrl, 
            mediaType, 
            mediaStorage 
        } = req.body;

        // 💡 ESNEK YAPI: En az bir ilişki olmalı (activity, lesson, group veya parentQuestion)
        if (!activity && !lesson && !group && !parentQuestion) {
            logger.error('createQuestion - Validation hatası: Hiçbir ilişki yok');
            return res.status(400).json({
                success: false,
                message: 'Soru en az bir seviyeye bağlı olmalıdır (activity, lesson, group veya parentQuestion).'
            });
        }
        
        logger.info('createQuestion - Activity:', activity, 'Lesson:', lesson, 'Group:', group, 'ParentQuestion:', parentQuestion);

        // Soru tipini belirle (questionFormat varsa onu kullan, yoksa questionType)
        const finalQuestionType = questionFormat || questionType;
        if (!finalQuestionType) {
            return res.status(400).json({
                success: false,
                message: 'Soru tipi veya formatı zorunludur.'
            });
        }

        // 💡 STRATEGY PATTERN: Soru tipine göre strategy kullan
        let normalizedQuestionData;
        try {
            // Validation
            const validation = QuestionStrategyFactory.validate({
                questionType: finalQuestionType,
                questionFormat: finalQuestionType,
                data,
                mediaFileId,
                mediaFiles,
                mediaType,
                mediaStorage
            });

            if (!validation.valid) {
                return res.status(400).json({
                    success: false,
                    message: 'Soru validasyonu başarısız',
                    errors: validation.errors
                });
            }

            // Normalize
            normalizedQuestionData = QuestionStrategyFactory.normalize({
                questionType: finalQuestionType,
                questionFormat: finalQuestionType,
                activity,
                lesson,
                group,
                parentQuestion,
                correctAnswer,
                data,
                mediaFileId,
                mediaFiles,
                mediaUrl,
                mediaType,
                mediaStorage
            });
        } catch (strategyError) {
            // Eğer yeni format bulunamazsa, eski formatı kullan (backward compatibility)
            logger.warn('Strategy bulunamadı, eski format kullanılıyor:', strategyError.message);
            normalizedQuestionData = {
                activity,
                lesson,
                group,
                parentQuestion,
                questionType: finalQuestionType,
                correctAnswer,
                data: data || {},
                mediaFileId,
                mediaFiles,
                mediaUrl,
                mediaType: mediaType || 'None',
                mediaStorage: mediaStorage || 'None'
            };
        }

        // correctAnswer opsiyonel (kod yazma etkinlikleri için boş olabilir)

        // Aktivite var mı kontrol et (eğer activity varsa)
        if (activity) {
            const activityExists = await Activity.findById(activity);
            if (!activityExists) {
                return res.status(404).json({
                    success: false,
                    message: 'Seçilen aktivite bulunamadı.'
                });
            }
        }

        // Ders var mı kontrol et (eğer lesson varsa)
        if (lesson) {
            const Lesson = require('../models/lesson');
            const lessonExists = await Lesson.findById(lesson);
            if (!lessonExists) {
                return res.status(404).json({
                    success: false,
                    message: 'Seçilen ders bulunamadı.'
                });
            }
        }

        // Grup var mı kontrol et (eğer group varsa)
        if (group) {
            const groupExists = await Group.findById(group);
            if (!groupExists) {
                return res.status(404).json({
                    success: false,
                    message: 'Seçilen grup bulunamadı.'
                });
            }
        }

        // Parent soru var mı kontrol et (eğer parentQuestion varsa)
        if (parentQuestion) {
            const parentExists = await MiniQuestion.findById(parentQuestion);
            if (!parentExists) {
                return res.status(404).json({
                    success: false,
                    message: 'Seçilen ana soru bulunamadı.'
                });
            }
        }

        // Question level'ı belirle (frontend'den gelen varsa onu kullan, yoksa otomatik belirle)
        let finalQuestionLevel = questionLevel || req.body.questionLevel;
        logger.info('createQuestion - Frontend questionLevel:', questionLevel, 'req.body.questionLevel:', req.body.questionLevel);
        
        if (!finalQuestionLevel) {
            // Otomatik belirle
            logger.info('createQuestion - Normalized data:', {
                group: normalizedQuestionData.group,
                lesson: normalizedQuestionData.lesson,
                activity: normalizedQuestionData.activity,
                parentQuestion: normalizedQuestionData.parentQuestion
            });
            
            if (normalizedQuestionData.group) {
                finalQuestionLevel = 'Group';
            } else if (normalizedQuestionData.lesson) {
                finalQuestionLevel = 'Lesson';
            } else if (normalizedQuestionData.activity) {
                finalQuestionLevel = 'Activity';
            } else if (normalizedQuestionData.parentQuestion) {
                finalQuestionLevel = 'Nested';
            } else {
                finalQuestionLevel = 'Activity'; // Varsayılan
            }
        }
        
        logger.info('createQuestion - Final questionLevel:', finalQuestionLevel);
        
        // QuestionLevel enum kontrolü
        const validLevels = ['Group', 'Lesson', 'Activity', 'Nested'];
        if (!validLevels.includes(finalQuestionLevel)) {
            logger.error('createQuestion - Geçersiz questionLevel:', finalQuestionLevel);
            return res.status(400).json({
                success: false,
                message: `Geçersiz questionLevel: ${finalQuestionLevel}. Geçerli değerler: ${validLevels.join(', ')}`
            });
        }

        // mediaFiles array'ini hazırla (normalize edilmiş veriden)
        let processedMediaFiles = [];
        if (normalizedQuestionData.mediaFiles && Array.isArray(normalizedQuestionData.mediaFiles) && normalizedQuestionData.mediaFiles.length > 0) {
            processedMediaFiles = normalizedQuestionData.mediaFiles;
        } else if (normalizedQuestionData.mediaFileId) {
            // Geriye dönük uyumluluk
            processedMediaFiles = [{
                fileId: normalizedQuestionData.mediaFileId,
                mediaType: normalizedQuestionData.mediaType || 'Image',
                order: 0
            }];
        }

        const questionDataToCreate = {
            activity: normalizedQuestionData.activity || null,
            lesson: normalizedQuestionData.lesson || null,
            group: normalizedQuestionData.group || null,
            parentQuestion: normalizedQuestionData.parentQuestion || null,
            questionLevel: finalQuestionLevel,
            questionType: normalizedQuestionData.questionType,
            correctAnswer: normalizedQuestionData.correctAnswer ? 
                (typeof normalizedQuestionData.correctAnswer === 'string' ? normalizedQuestionData.correctAnswer.trim() : normalizedQuestionData.correctAnswer) : 
                null,
            data: normalizedQuestionData.data || {},
            mediaFileId: processedMediaFiles.length > 0 ? processedMediaFiles[0].fileId : (normalizedQuestionData.mediaFileId || null),
            mediaFiles: processedMediaFiles,
            mediaUrl: normalizedQuestionData.mediaUrl || null,
            mediaType: normalizedQuestionData.mediaType || 'None',
            mediaStorage: normalizedQuestionData.mediaStorage || 'None',
            createdBy: req.user ? req.user._id : null // Soruyu oluşturan kullanıcı
        };
        
        logger.info('createQuestion - Oluşturulacak soru verisi:', JSON.stringify(questionDataToCreate, null, 2));
        
        // 💡 DUPLICATE KONTROLÜ: Aynı medya dosyasına sahip soru var mı kontrol et
        const duplicateCheck = {
            $or: []
        };
        
        // Activity seviyesinde duplicate kontrolü
        if (questionDataToCreate.activity) {
            duplicateCheck.$or.push({
                activity: questionDataToCreate.activity,
                'data.questionText': questionDataToCreate.data?.questionText || '',
                mediaFileId: questionDataToCreate.mediaFileId || null
            });
        }
        
        // Lesson seviyesinde duplicate kontrolü
        if (questionDataToCreate.lesson) {
            duplicateCheck.$or.push({
                lesson: questionDataToCreate.lesson,
                'data.questionText': questionDataToCreate.data?.questionText || '',
                mediaFileId: questionDataToCreate.mediaFileId || null
            });
        }
        
        // Son 5 saniye içinde aynı soru eklenmiş mi kontrol et
        if (duplicateCheck.$or.length > 0) {
            const recentDuplicate = await MiniQuestion.findOne({
                ...duplicateCheck,
                createdAt: { $gte: new Date(Date.now() - 5000) } // Son 5 saniye
            });
            
            if (recentDuplicate) {
                logger.warn('createQuestion - Duplicate soru tespit edildi (son 5 saniye içinde):', recentDuplicate._id);
                return res.status(400).json({
                    success: false,
                    message: 'Bu soru çok kısa süre önce eklenmiş. Lütfen bekleyin veya sayfayı yenileyin.',
                    duplicateId: recentDuplicate._id
                });
            }
        }
        
        const question = await MiniQuestion.create(questionDataToCreate);
        
        logger.info('createQuestion - Soru başarıyla oluşturuldu:', question._id);

        const populatedQuestion = await MiniQuestion.findById(question._id)
            .populate('activity', 'title type')
            .populate('createdBy', 'firstName lastName email')
            .lean();

        res.status(201).json({
            success: true,
            message: 'Soru başarıyla oluşturuldu.',
            data: populatedQuestion
        });
    } catch (error) {
        logger.error('createQuestion hatası:', error);
        logger.error('Hata detayı:', error.stack);
        res.status(500).json({
            success: false,
            message: 'Soru oluşturulurken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası',
            details: process.env.NODE_ENV === 'development' ? error.stack : undefined
        });
    }
};

// Mini Question Güncelleme
exports.updateQuestion = async (req, res) => {
    try {
        const { id } = req.params;
        const { activity, lesson, questionType, correctAnswer, data, mediaFileId, mediaFiles, mediaUrl, mediaType, mediaStorage, questionLevel } = req.body;

        // Soru var mı kontrol et
        const existingQuestion = await MiniQuestion.findById(id);
        if (!existingQuestion) {
            return res.status(404).json({
                success: false,
                message: 'Soru bulunamadı.'
            });
        }

        // Aktivite var mı kontrol et (eğer değiştiriliyorsa)
        if (activity) {
            const activityExists = await Activity.findById(activity);
            if (!activityExists) {
                return res.status(404).json({
                    success: false,
                    message: 'Seçilen aktivite bulunamadı.'
                });
            }
        }

        // Ders var mı kontrol et (eğer değiştiriliyorsa)
        if (lesson) {
            const Lesson = require('../models/lesson');
            const lessonExists = await Lesson.findById(lesson);
            if (!lessonExists) {
                return res.status(404).json({
                    success: false,
                    message: 'Seçilen ders bulunamadı.'
                });
            }
        }

        // mediaFiles array'ini hazırla (birden fazla medya dosyası için)
        let processedMediaFiles = [];
        if (mediaFiles && Array.isArray(mediaFiles) && mediaFiles.length > 0) {
            processedMediaFiles = mediaFiles.map((file, index) => ({
                fileId: file.fileId || file._id,
                mediaType: file.mediaType || 'Image',
                order: file.order !== undefined ? file.order : index
            }));
        } else if (mediaFileId) {
            // Geriye dönük uyumluluk: mediaFileId varsa mediaFiles'e ekle
            processedMediaFiles = [{
                fileId: mediaFileId,
                mediaType: mediaType || 'Image',
                order: 0
            }];
        }

        // Question level'ı belirle
        let finalQuestionLevel = questionLevel;
        if (!finalQuestionLevel) {
            if (lesson) {
                finalQuestionLevel = 'Lesson';
            } else if (activity) {
                finalQuestionLevel = 'Activity';
            } else if (existingQuestion.group) {
                finalQuestionLevel = 'Group';
            } else if (existingQuestion.parentQuestion) {
                finalQuestionLevel = 'Nested';
            } else {
                finalQuestionLevel = existingQuestion.questionLevel || 'Activity';
            }
        }

        // Güncelleme verilerini hazırla
        const updateData = {};
        if (activity !== undefined) updateData.activity = activity || null;
        if (lesson !== undefined) updateData.lesson = lesson || null;
        if (questionType) updateData.questionType = questionType;
        if (finalQuestionLevel) updateData.questionLevel = finalQuestionLevel;
        // correctAnswer opsiyonel - Flutter'da kontrol edilecek
        if (correctAnswer !== undefined) updateData.correctAnswer = correctAnswer ? correctAnswer.trim() : null;
        if (data !== undefined) updateData.data = data;
        if (mediaUrl !== undefined) updateData.mediaUrl = mediaUrl;
        if (mediaType !== undefined) updateData.mediaType = mediaType;
        if (mediaStorage !== undefined) updateData.mediaStorage = mediaStorage;
        
        // mediaFiles güncellemesi
        if (processedMediaFiles.length > 0) {
            updateData.mediaFiles = processedMediaFiles;
            updateData.mediaFileId = processedMediaFiles[0].fileId; // Geriye dönük uyumluluk
        } else if (mediaFileId) {
            updateData.mediaFileId = mediaFileId;
        }

        const question = await MiniQuestion.findByIdAndUpdate(
            id,
            { $set: updateData },
            { new: true, runValidators: true }
        )
            .populate('activity', 'title type')
            .lean();

        res.status(200).json({
            success: true,
            message: 'Soru başarıyla güncellendi.',
            data: question
        });
    } catch (error) {
        logger.error('updateQuestion hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Soru güncellenirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Tüm grupları listele
exports.getAllGroups = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const skip = (page - 1) * limit;

        let filter = {};
        if (req.query.categoryId) {
            filter.category = req.query.categoryId;
        }

        const groups = await Group.find(filter)
            .populate('category', 'name')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean();

        const total = await Group.countDocuments(filter);

        res.status(200).json({
            success: true,
            data: groups,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        logger.error('getAllGroups hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Gruplar getirilirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Tüm dersleri listele
exports.getAllLessons = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const skip = (page - 1) * limit;

        let filter = {};
        if (req.query.groupId) {
            filter.group = req.query.groupId;
        }

        const lessons = await Lesson.find(filter)
            .populate('group', 'name')
            .populate({
                path: 'group',
                populate: {
                    path: 'category',
                    select: 'name'
                }
            })
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean();

        const total = await Lesson.countDocuments(filter);

        res.status(200).json({
            success: true,
            data: lessons,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        logger.error('getAllLessons hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Dersler getirilirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Tüm soruları listele
exports.getAllQuestions = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const skip = (page - 1) * limit;

        let filter = {};
        if (req.query.activityId) {
            filter.activity = req.query.activityId;
        }

        const questions = await MiniQuestion.find(filter)
            .populate('activity', 'title type')
            .populate('createdBy', 'firstName lastName email')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean();

        const total = await MiniQuestion.countDocuments(filter);

        res.status(200).json({
            success: true,
            data: questions,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        logger.error('getAllQuestions hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Sorular getirilirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// Soru Silme
exports.deleteQuestion = async (req, res) => {
    try {
        const { id } = req.params;

        // Soru var mı kontrol et
        const question = await MiniQuestion.findById(id);
        if (!question) {
            return res.status(404).json({
                success: false,
                message: 'Soru bulunamadı.'
            });
        }

        // Soruyu sil
        await MiniQuestion.findByIdAndDelete(id);

        res.status(200).json({
            success: true,
            message: 'Soru başarıyla silindi.'
        });
    } catch (error) {
        logger.error('deleteQuestion hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Soru silinirken hata oluştu',
            error: process.env.NODE_ENV === 'development' ? error.message : 'Sunucu hatası'
        });
    }
};

// ======================================================================
// ÖĞRENCİ EKLEME İÇİN YARDIMCI ENDPOINT'LER
// ======================================================================

// Sadece öğretmenleri listele (öğrenci ekleme formu için)
exports.getAllTeachers = async (req, res) => {
    try {
        const teachers = await User.find({ role: 'Teacher' })
            .select('firstName lastName email')
            .sort({ firstName: 1, lastName: 1 })
            .lean();

        res.status(200).json({
            success: true,
            data: teachers.map(teacher => ({
                id: teacher._id,
                firstName: teacher.firstName,
                lastName: teacher.lastName,
                fullName: `${teacher.firstName} ${teacher.lastName}`,
                email: teacher.email
            }))
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Öğretmenler getirilirken hata oluştu',
            error: error.message
        });
    }
};

// Öğretmen ID'sine göre o öğretmenin sınıflarını getir
exports.getTeacherClassrooms = async (req, res) => {
    try {
        const { teacherId } = req.params;

        if (!teacherId) {
            return res.status(400).json({
                success: false,
                message: 'Öğretmen ID\'si gereklidir.'
            });
        }

        // Öğretmenin varlığını kontrol et
        const teacher = await User.findById(teacherId).select('role firstName lastName').lean();
        if (!teacher) {
            return res.status(404).json({
                success: false,
                message: 'Öğretmen bulunamadı.'
            });
        }

        if (teacher.role !== 'Teacher') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğretmen değil.'
            });
        }

        // Öğretmenin sınıflarını getir
        const classrooms = await Classroom.find({ teacher: teacherId })
            .populate('students', 'firstName lastName')
            .sort({ createdAt: -1 })
            .lean();

        res.status(200).json({
            success: true,
            teacher: {
                id: teacher._id,
                firstName: teacher.firstName,
                lastName: teacher.lastName
            },
            classrooms: classrooms.map(classroom => ({
                id: classroom._id,
                name: classroom.name,
                studentCount: classroom.students ? classroom.students.length : 0,
                students: classroom.students || [],
                createdAt: classroom.createdAt,
                updatedAt: classroom.updatedAt
            }))
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Sınıflar getirilirken hata oluştu',
            error: error.message
        });
    }
};

// Sınıf ID'sine göre o sınıftaki öğrencileri getir
exports.getClassroomStudents = async (req, res) => {
    try {
        const { classroomId } = req.params;

        if (!classroomId) {
            return res.status(400).json({
                success: false,
                message: 'Sınıf ID\'si gereklidir.'
            });
        }

        // Sınıfı getir
        const classroom = await Classroom.findById(classroomId)
            .populate('teacher', 'firstName lastName')
            .populate('students', 'firstName lastName')
            .lean();

        if (!classroom) {
            return res.status(404).json({
                success: false,
                message: 'Sınıf bulunamadı.'
            });
        }

        res.status(200).json({
            success: true,
            classroom: {
                id: classroom._id,
                name: classroom.name,
                teacher: {
                    id: classroom.teacher._id,
                    firstName: classroom.teacher.firstName,
                    lastName: classroom.teacher.lastName
                },
                students: classroom.students || [],
                studentCount: classroom.students ? classroom.students.length : 0
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Öğrenciler getirilirken hata oluştu',
            error: error.message
        });
    }
};
