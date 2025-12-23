// controllers/teacherNoteController.js - Öğretmen Notları Controller'ı

const TeacherNote = require('../models/teacherNote');
const User = require('../models/user');
const jwt = require('jsonwebtoken');
const logger = require('../config/logger');

// Token'dan öğretmen ID'sini çıkaran yardımcı fonksiyon
const getTeacherIdFromToken = (req) => {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return null;
    }
    
    const token = authHeader.substring(7);
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fallback-secret-key-change-in-production');
        return decoded.userId;
    } catch (error) {
        return null;
    }
};

// ---------------------------------------------------------------------
// 1. Öğrenciye Not Ekleme
// POST /api/teacher-notes/student/:studentId
// ---------------------------------------------------------------------
exports.createNote = async (req, res) => {
    const { studentId } = req.params;
    const { title, content, priority, category, teacherId: selectedTeacherId } = req.body; // Admin panelinden öğretmen ID'si gelebilir

    try {
        // Admin panelinden mi çağrıldı kontrol et
        const isAdminPanel = req.user && (req.user.role === 'Admin' || req.user.role === 'SuperAdmin');
        
        let teacherId = null;
        
        if (isAdminPanel && selectedTeacherId) {
            // Admin panelinden çağrıldı ve öğretmen seçilmiş
            teacherId = selectedTeacherId;
            
            // Seçilen öğretmenin gerçekten öğretmen olduğunu kontrol et
            const selectedTeacher = await User.findById(teacherId).select('role').lean();
            if (!selectedTeacher || selectedTeacher.role !== 'Teacher') {
                return res.status(400).json({
                    success: false,
                    message: 'Geçersiz öğretmen ID\'si.'
                });
            }
        } else {
            // Normal öğretmen akışı
            teacherId = getTeacherIdFromToken(req);
            if (!teacherId) {
                return res.status(401).json({
                    success: false,
                    message: 'Yetkilendirme hatası: Token bulunamadı veya geçersiz.'
                });
            }

            // Öğretmeni kontrol et
            const teacher = await User.findById(teacherId).select('role').lean();
            if (!teacher || (teacher.role !== 'Teacher' && teacher.role !== 'Admin' && teacher.role !== 'SuperAdmin')) {
                return res.status(403).json({
                    success: false,
                    message: 'Bu işlem için öğretmen yetkisi gereklidir.'
                });
            }
        }

        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('role').lean();
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

        // Admin değilse, öğretmenin bu öğrenciye erişimi var mı kontrol et (Classroom'dan)
        if (!isAdminPanel) {
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

        // Notu oluştur
        const note = new TeacherNote({
            student: studentId,
            teacher: teacherId,
            title: title.trim(),
            content: content.trim(),
            priority: priority || 'Normal',
            category: category ? category.trim() : 'Genel'
        });

        await note.save();

        // Populate ile öğretmen bilgilerini ekle
        await note.populate('teacher', 'firstName lastName');
        await note.populate('student', 'firstName lastName');

        logger.info('Öğretmen notu oluşturuldu', {
            noteId: note._id,
            studentId: studentId,
            teacherId: teacherId
        });

        res.status(201).json({
            success: true,
            message: 'Not başarıyla oluşturuldu.',
            note: {
                id: note._id,
                title: note.title,
                content: note.content,
                priority: note.priority,
                category: note.category,
                student: {
                    id: note.student._id,
                    firstName: note.student.firstName,
                    lastName: note.student.lastName
                },
                teacher: {
                    id: note.teacher._id,
                    firstName: note.teacher.firstName,
                    lastName: note.teacher.lastName
                },
                createdAt: note.createdAt,
                updatedAt: note.updatedAt
            }
        });
    } catch (error) {
        logger.error('Not oluşturma hatası', {
            studentId: studentId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Not oluşturulamadı.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 2. Öğretmenin Öğrencilerini Getirme (Classroom'dan)
// GET /api/teacher-notes/teacher/students
// ---------------------------------------------------------------------
exports.getTeacherStudents = async (req, res) => {
    try {
        // Token'dan öğretmen ID'sini al
        const teacherId = getTeacherIdFromToken(req);
        if (!teacherId) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Token bulunamadı veya geçersiz.'
            });
        }

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

        logger.info('Öğretmen öğrencileri getirildi (notlar için)', {
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
        logger.error('Öğrenci listesi getirme hatası (notlar için)', {
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
// 3. Öğrenciye Ait Tüm Notları Getirme
// GET /api/teacher-notes/student/:studentId
// ---------------------------------------------------------------------
exports.getStudentNotes = async (req, res) => {
    const { studentId } = req.params;

    try {
        // Admin panelinden mi çağrıldı kontrol et (req.user varsa admin panelinden)
        const isAdminPanel = req.user && (req.user.role === 'Admin' || req.user.role === 'SuperAdmin');
        
        let teacherId = null;
        let queryTeacherId = null;

        if (isAdminPanel) {
            // Admin panelinden çağrıldı - seçilen öğretmenin notlarını göster
            // Query'den öğretmen ID'sini al (admin panelinde öğretmen seçilmiş olmalı)
            const { teacherId: selectedTeacherId } = req.query;
            
            if (selectedTeacherId) {
                queryTeacherId = selectedTeacherId;
                // Seçilen öğretmenin notlarını göster
                const notes = await TeacherNote.find({
                    student: studentId,
                    teacher: selectedTeacherId
                })
                .populate('teacher', 'firstName lastName')
                .populate('student', 'firstName lastName')
                .sort({ createdAt: -1 })
                .lean();

                const student = await User.findById(studentId).select('firstName lastName role').lean();
                if (!student) {
                    return res.status(404).json({
                        success: false,
                        message: 'Öğrenci bulunamadı.'
                    });
                }

                return res.status(200).json({
                    success: true,
                    student: {
                        id: student._id,
                        firstName: student.firstName,
                        lastName: student.lastName
                    },
                    notes: notes.map(note => ({
                        id: note._id,
                        title: note.title,
                        content: note.content,
                        priority: note.priority,
                        category: note.category,
                        teacher: {
                            id: note.teacher._id,
                            firstName: note.teacher.firstName,
                            lastName: note.teacher.lastName
                        },
                        createdAt: note.createdAt,
                        updatedAt: note.updatedAt
                    }))
                });
            } else {
                // Admin panelinden ama öğretmen seçilmemiş - tüm notları göster
                const notes = await TeacherNote.find({
                    student: studentId
                })
                .populate('teacher', 'firstName lastName')
                .populate('student', 'firstName lastName')
                .sort({ createdAt: -1 })
                .lean();

                const student = await User.findById(studentId).select('firstName lastName role').lean();
                if (!student) {
                    return res.status(404).json({
                        success: false,
                        message: 'Öğrenci bulunamadı.'
                    });
                }

                return res.status(200).json({
                    success: true,
                    student: {
                        id: student._id,
                        firstName: student.firstName,
                        lastName: student.lastName
                    },
                    notes: notes.map(note => ({
                        id: note._id,
                        title: note.title,
                        content: note.content,
                        priority: note.priority,
                        category: note.category,
                        teacher: {
                            id: note.teacher._id,
                            firstName: note.teacher.firstName,
                            lastName: note.teacher.lastName
                        },
                        createdAt: note.createdAt,
                        updatedAt: note.updatedAt
                    }))
                });
            }
        } else {
            // Normal öğretmen akışı
            teacherId = getTeacherIdFromToken(req);
            if (!teacherId) {
                return res.status(401).json({
                    success: false,
                    message: 'Yetkilendirme hatası: Token bulunamadı veya geçersiz.'
                });
            }

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

            // Öğretmenin bu öğrenciye erişimi var mı kontrol et (Classroom'dan)
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

            // Notları getir (sadece bu öğretmenin yazdığı notlar)
            const notes = await TeacherNote.find({
                student: studentId,
                teacher: teacherId
            })
        .populate('teacher', 'firstName lastName')
        .populate('student', 'firstName lastName')
        .sort({ createdAt: -1 }) // En yeni notlar önce
        .lean();

        logger.info('Öğrenci notları getirildi', {
            studentId: studentId,
            teacherId: teacherId,
            noteCount: notes.length
        });

        res.status(200).json({
            success: true,
            student: {
                id: student._id,
                firstName: student.firstName,
                lastName: student.lastName
            },
            notes: notes.map(note => ({
                id: note._id,
                title: note.title,
                content: note.content,
                priority: note.priority,
                category: note.category,
                teacher: {
                    id: note.teacher._id,
                    firstName: note.teacher.firstName,
                    lastName: note.teacher.lastName
                },
                createdAt: note.createdAt,
                updatedAt: note.updatedAt
            }))
        });
        }
    } catch (error) {
        logger.error('Notları getirme hatası', {
            studentId: studentId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Notlar yüklenemedi.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 3. Notu Güncelleme
// PUT /api/teacher-notes/:noteId
// ---------------------------------------------------------------------
exports.updateNote = async (req, res) => {
    const { noteId } = req.params;
    const { title, content, priority, category } = req.body;

    try {
        // Token'dan öğretmen ID'sini al
        const teacherId = getTeacherIdFromToken(req);
        if (!teacherId) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Token bulunamadı veya geçersiz.'
            });
        }

        // Notu bul
        const note = await TeacherNote.findById(noteId)
            .populate('teacher', 'firstName lastName')
            .populate('student', 'firstName lastName');

        if (!note) {
            return res.status(404).json({
                success: false,
                message: 'Not bulunamadı.'
            });
        }

        // Sadece notu yazan öğretmen güncelleyebilir
        if (note.teacher._id.toString() !== teacherId.toString()) {
            return res.status(403).json({
                success: false,
                message: 'Bu notu sadece yazan öğretmen güncelleyebilir.'
            });
        }

        // Notu güncelle
        if (title) note.title = title.trim();
        if (content) note.content = content.trim();
        if (priority) note.priority = priority;
        if (category) note.category = category.trim();

        await note.save();

        logger.info('Not güncellendi', {
            noteId: noteId,
            teacherId: teacherId
        });

        res.status(200).json({
            success: true,
            message: 'Not başarıyla güncellendi.',
            note: {
                id: note._id,
                title: note.title,
                content: note.content,
                priority: note.priority,
                category: note.category,
                student: {
                    id: note.student._id,
                    firstName: note.student.firstName,
                    lastName: note.student.lastName
                },
                teacher: {
                    id: note.teacher._id,
                    firstName: note.teacher.firstName,
                    lastName: note.teacher.lastName
                },
                createdAt: note.createdAt,
                updatedAt: note.updatedAt
            }
        });
    } catch (error) {
        logger.error('Not güncelleme hatası', {
            noteId: noteId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Not güncellenemedi.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 4. Notu Silme
// DELETE /api/teacher-notes/:noteId
// ---------------------------------------------------------------------
exports.deleteNote = async (req, res) => {
    const { noteId } = req.params;

    try {
        // Token'dan öğretmen ID'sini al
        const teacherId = getTeacherIdFromToken(req);
        if (!teacherId) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Token bulunamadı veya geçersiz.'
            });
        }

        // Notu bul
        const note = await TeacherNote.findById(noteId);

        if (!note) {
            return res.status(404).json({
                success: false,
                message: 'Not bulunamadı.'
            });
        }

        // Sadece notu yazan öğretmen silebilir
        if (note.teacher.toString() !== teacherId.toString()) {
            return res.status(403).json({
                success: false,
                message: 'Bu notu sadece yazan öğretmen silebilir.'
            });
        }

        await TeacherNote.findByIdAndDelete(noteId);

        logger.info('Not silindi', {
            noteId: noteId,
            teacherId: teacherId
        });

        res.status(200).json({
            success: true,
            message: 'Not başarıyla silindi.'
        });
    } catch (error) {
        logger.error('Not silme hatası', {
            noteId: noteId,
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Not silinemedi.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 5. Öğretmenin Tüm Notlarını Getirme (Tüm öğrenciler için)
// GET /api/teacher-notes/teacher
// ---------------------------------------------------------------------
exports.getTeacherNotes = async (req, res) => {
    try {
        // Token'dan öğretmen ID'sini al
        const teacherId = getTeacherIdFromToken(req);
        if (!teacherId) {
            return res.status(401).json({
                success: false,
                message: 'Yetkilendirme hatası: Token bulunamadı veya geçersiz.'
            });
        }

        // Öğretmeni kontrol et
        const teacher = await User.findById(teacherId).select('role').lean();
        if (!teacher || (teacher.role !== 'Teacher' && teacher.role !== 'Admin' && teacher.role !== 'SuperAdmin')) {
            return res.status(403).json({
                success: false,
                message: 'Bu işlem için öğretmen yetkisi gereklidir.'
            });
        }

        // Tüm notları getir
        const notes = await TeacherNote.find({
            teacher: teacherId
        })
        .populate('student', 'firstName lastName')
        .sort({ createdAt: -1 })
        .lean();

        logger.info('Öğretmen notları getirildi', {
            teacherId: teacherId,
            noteCount: notes.length
        });

        res.status(200).json({
            success: true,
            notes: notes.map(note => ({
                id: note._id,
                title: note.title,
                content: note.content,
                priority: note.priority,
                category: note.category,
                student: {
                    id: note.student._id,
                    firstName: note.student.firstName,
                    lastName: note.student.lastName
                },
                createdAt: note.createdAt,
                updatedAt: note.updatedAt
            }))
        });
    } catch (error) {
        logger.error('Öğretmen notlarını getirme hatası', {
            error: error.message
        });
        
        res.status(500).json({
            success: false,
            message: 'Notlar yüklenemedi.',
            error: error.message
        });
    }
};

