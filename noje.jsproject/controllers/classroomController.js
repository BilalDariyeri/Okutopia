// controllers/classroomController.js
const path = require('path');
const jwt = require('jsonwebtoken');

// Gerekli Mongoose Modellerini içeri aktar (path normalize ile case-sensitivity sorunu çözüldü)
const Classroom = require(path.resolve(__dirname, '../models/classroom'));
const User = require(path.resolve(__dirname, '../models/user')); 
const Progress = require(path.resolve(__dirname, '../models/progress')); 

// ---------------------------------------------------------------------
// 1. Öğretmene Ait Sınıfları Listeleme Rotası
// GET /api/classrooms/teacher/:teacherId
// ---------------------------------------------------------------------
exports.getTeacherClassrooms = async (req, res) => {
    const { teacherId } = req.params;
    
    // 💡 PERFORMANS: Pagination desteği
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50; // Varsayılan 50, maksimum 100
    const skip = (page - 1) * limit;
    const actualLimit = Math.min(limit, 100); // Maksimum 100 kayıt

    try {
        // Öğretmen ID'sine göre sınıfları bul (lean() ile daha hızlı)
        const classrooms = await Classroom.find({ teacher: teacherId })
            .populate('students', 'firstName lastName')
            .lean() // 💡 PERFORMANS: lean() kullanarak Mongoose overhead'ini azalt
            .skip(skip)
            .limit(actualLimit)
            .sort({ createdAt: -1 }); // En yeni sınıflar önce
        
        // 💡 PERFORMANS: Toplam sayıyı al (pagination için)
        const total = await Classroom.countDocuments({ teacher: teacherId });
        
        // 💡 KRİTİK DÜZELTME: Populate sonrası oluşan null değerleri temizliyoruz.
        const sanitizedClassrooms = classrooms
            .map(classroom => {
                if (!classroom) return null; 
                
                // students dizisi içindeki null (silinmiş referans) değerleri temizle
                if (classroom.students) {
                    classroom.students = classroom.students.filter(student => student !== null);
                }
                
                return classroom;
            })
            .filter(classroom => classroom !== null);

        res.status(200).json({
            success: true,
            classrooms: sanitizedClassrooms,
            pagination: {
                page,
                limit: actualLimit,
                total,
                pages: Math.ceil(total / actualLimit)
            }
        });
    } catch (error) {
        // Hata durumunda 500 kodu döndür
        res.status(500).json({ message: 'Sınıflar yüklenemedi veya geçersiz referans hatası.', error: error.message });
    }
};

// ---------------------------------------------------------------------
// 2. Sınıfa Yeni Öğrenci Ekleme Rotası
// POST /api/classrooms/:classId/add-student
// 💡 PERFORMANS: Transaction kullanarak 4 query yerine 1 transaction
// ---------------------------------------------------------------------
exports.addStudentToClass = async (req, res) => {
    const classId = req.params.classId; 
    const { firstName, lastName } = req.body; 
    const mongoose = require('mongoose');
    const session = await mongoose.startSession();
    session.startTransaction();

    try {
        // 💡 KRİTİK: Token'dan öğretmen ID'sini çıkar
        const authHeader = req.headers.authorization;
        
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            await session.abortTransaction();
            session.endSession();
            return res.status(401).json({ 
                success: false,
                message: 'Yetkilendirme hatası: Token bulunamadı. Lütfen giriş yapın.' 
            });
        }

        // "Bearer " kısmını çıkar ve token'ı doğrula
        const token = authHeader.substring(7);
        let decoded;
        
        try {
            decoded = jwt.verify(token, process.env.JWT_SECRET || 'fallback-secret-key-change-in-production');
        } catch (error) {
            await session.abortTransaction();
            session.endSession();
            return res.status(401).json({ 
                success: false,
                message: 'Yetkilendirme hatası: Geçersiz veya süresi dolmuş token.' 
            });
        }

        // Öğretmeni bul ve rol kontrolü yap
        const teacher = await User.findById(decoded.userId).select('-password');
        
        if (!teacher) {
            await session.abortTransaction();
            session.endSession();
            return res.status(401).json({ 
                success: false,
                message: 'Yetkilendirme hatası: Kullanıcı bulunamadı.' 
            });
        }

        if (teacher.role !== 'Teacher') {
            await session.abortTransaction();
            session.endSession();
            return res.status(403).json({ 
                success: false,
                message: 'Erişim reddedildi: Bu işlem için öğretmen yetkisi gereklidir.' 
            });
        }

        const teacherId = teacher._id;

        // Sınıfın varlığını ve öğretmen sahipliğini kontrol et (transaction dışında, hızlı kontrol)
        const classroomExists = await Classroom.findById(classId).lean();
        if (!classroomExists) {
            await session.abortTransaction();
            session.endSession();
            return res.status(404).json({ 
                success: false,
                message: 'Öğrenci eklenemedi: Belirtilen sınıf bulunamadı.' 
            });
        }

        // 💡 GÜVENLİK: Sınıfın bu öğretmene ait olduğunu kontrol et
        const classroomTeacherId = classroomExists.teacher.toString();
        const providedTeacherId = teacherId.toString();
        
        if (classroomTeacherId !== providedTeacherId) {
            await session.abortTransaction();
            session.endSession();
            return res.status(403).json({ 
                success: false,
                message: 'Yetkisiz işlem: Bu sınıf size ait değil. Sadece sınıfın sahibi öğrenci ekleyebilir.' 
            });
        }

        // 1. Yeni Öğrenciyi Kaydetme (Transaction içinde) - USERS KOLEKSİYONUNA EKLE
        const [newStudent] = await User.create([{ 
            firstName, 
            lastName, 
            role: 'Student',
            courses: [classId] // Öğrencinin courses dizisine sınıf ID'sini ekle
        }], { session });
        const studentId = newStudent._id;
        
        // 💡 KRİTİK: AYRI STUDENTS KOLEKSİYONUNA DA EKLE (USERS İLE AYNI ŞEMA - courses hariç)
        // SADECE ÖĞRENCİLER students koleksiyonuna eklenir, öğretmenler eklenmez
        const studentData = {
            _id: studentId,
            firstName: newStudent.firstName,
            lastName: newStudent.lastName,
            role: 'Student', // 💡 ÖNEMLİ: Role Student olarak kaydediliyor
            createdAt: new Date(),
            updatedAt: new Date()
        };
        
        // MongoDB'ye direkt students koleksiyonuna ekle (transaction içinde)
        try {
            console.log('🔄 Öğrenci students koleksiyonuna ekleniyor:', studentData);
            const insertResult = await mongoose.connection.db.collection('students').insertOne(studentData, { session });
            if (!insertResult.insertedId) {
                throw new Error('Students koleksiyonuna ekleme başarısız oldu');
            }
            // 💡 LOG: Başarılı ekleme
            console.log('✅ Öğrenci students koleksiyonuna başarıyla eklendi:', insertResult.insertedId);
        } catch (insertError) {
            // Eğer duplicate key hatası varsa (aynı _id zaten varsa), devam et
            if (insertError.code === 11000) {
                console.log('⚠️ Öğrenci zaten students koleksiyonunda mevcut (duplicate key), devam ediliyor...');
                // Mevcut kaydın role'ünü kontrol et ve güncelle
                try {
                    const existingStudent = await mongoose.connection.db.collection('students').findOne({ _id: studentId }, { session });
                    if (existingStudent && existingStudent.role !== 'Student') {
                        console.log('⚠️ Mevcut kayıt Student değil, role güncelleniyor...');
                        await mongoose.connection.db.collection('students').updateOne(
                            { _id: studentId },
                            { $set: { role: 'Student', firstName: newStudent.firstName, lastName: newStudent.lastName, updatedAt: new Date() } },
                            { session }
                        );
                        console.log('✅ Mevcut kayıt Student olarak güncellendi');
                    }
                } catch (updateError) {
                    console.error('⚠️ Mevcut kayıt güncellenirken hata:', updateError);
                }
            } else {
                // Diğer hatalar için transaction'ı iptal et
                console.error('❌ Students koleksiyonuna ekleme hatası:', insertError);
                await session.abortTransaction();
                session.endSession();
                return res.status(500).json({ 
                    success: false,
                    message: 'Öğrenci users koleksiyonuna eklendi ama students koleksiyonuna eklenemedi.', 
                    error: insertError.message,
                    errorCode: insertError.code
                });
            }
        } 
        
        // 2. Öğrenciyi Sınıfa Ekleme (Transaction içinde) - CLASSROOM.STUDENTS DİZİSİNE EKLE
        // 💡 KRİTİK: MongoDB'nin native $addToSet operatörü ile direkt ekleme (daha güvenilir)
        const updateResult = await Classroom.updateOne(
            { _id: classId },
            { $addToSet: { students: studentId } },
            { session }
        );
        
        if (updateResult.matchedCount === 0) {
            await session.abortTransaction();
            session.endSession();
            return res.status(404).json({ 
                success: false,
                message: 'Öğrenci eklenemedi: Belirtilen sınıf bulunamadı.' 
            });
        }
        
        // 💡 DOĞRULAMA: Öğrencinin gerçekten eklendiğini kontrol et
        const verifyClassroom = await Classroom.findById(classId).session(session);
        const isStudentAdded = verifyClassroom.students.some(id => id.toString() === studentId.toString());
        
        if (!isStudentAdded) {
            await session.abortTransaction();
            session.endSession();
            return res.status(500).json({ 
                success: false,
                message: 'Öğrenci users ve students koleksiyonuna eklendi ama classroom.students dizisine eklenemedi.' 
            });
        }
        
        // 3. İlerleme Takip Dokümanını Oluşturma (Transaction içinde)
        const [newProgress] = await Progress.create([{
            student: studentId,
            classroom: classId,
        }], { session });

        // Transaction'ı commit et
        await session.commitTransaction();
        session.endSession();

        // 💡 KRİTİK: Transaction commit edildikten sonra populate ile güncellenmiş classroom'ı çek
        const populatedClassroom = await Classroom.findById(classId)
            .populate('teacher', 'firstName lastName email')
            .populate('students', 'firstName lastName')
            .lean();

        // Başarılı yanıt - classroom bilgisini de döndür
        res.status(201).json({
            success: true,
            message: 'Öğrenci başarıyla kaydedildi ve sınıfa eklendi.',
            student: { 
                firstName: newStudent.firstName, 
                lastName: newStudent.lastName
            },
            classroom: populatedClassroom,
            progress: {
                id: newProgress._id,
                student: newProgress.student,
                classroom: newProgress.classroom
            }
        });

    } catch (error) {
        // Hata durumunda transaction'ı geri al
        await session.abortTransaction();
        session.endSession();
        res.status(400).json({ message: 'Öğrenci ekleme işlemi sırasında hata oluştu.', error: error.message });
    }
};

// ---------------------------------------------------------------------
// 3. Sınıftaki Tüm Öğrencileri Listeleme
// GET /api/classrooms/:classId/students
// 💡 PERFORMANS: Tek query ile optimize edildi
// ---------------------------------------------------------------------
exports.getClassroomStudents = async (req, res) => {
    const { classId } = req.params;
    const { teacherId } = req.query; // Query parametresi olarak öğretmen ID'si

    console.log('🔍 getClassroomStudents çağrıldı:', { classId, teacherId });

    try {
        // Sınıfı bul ve öğretmen kontrolü yap
        console.log('📋 Sınıf aranıyor:', classId);
        const classroom = await Classroom.findById(classId).lean();
        if (!classroom) {
            console.log('❌ Sınıf bulunamadı:', classId);
            return res.status(404).json({
                success: false,
                message: 'Sınıf bulunamadı.'
            });
        }
        console.log('✅ Sınıf bulundu:', classroom.name);

        // 💡 GÜVENLİK: Öğretmen kontrolü (opsiyonel ama önerilir)
        if (teacherId) {
            const classroomTeacherId = classroom.teacher.toString();
            if (classroomTeacherId !== teacherId.toString()) {
                return res.status(403).json({
                    success: false,
                    message: 'Yetkisiz işlem: Bu sınıf size ait değil.'
                });
            }
        }

        // 💡 PERFORMANS: Tek query ile öğrencileri ve ilerlemelerini çek
        console.log('👥 Öğrenciler populate ediliyor...');
        const populatedClassroom = await Classroom.findById(classId)
            .populate('students', 'firstName lastName role')
            .lean();

        if (!populatedClassroom || !populatedClassroom.students || populatedClassroom.students.length === 0) {
            console.log('ℹ️ Sınıfta öğrenci yok');
            return res.status(200).json({
                success: true,
                classroom: {
                    id: classroom._id,
                    name: classroom.name,
                    teacher: classroom.teacher
                },
                students: [],
                totalStudents: 0
            });
        }

        console.log(`📊 ${populatedClassroom.students.length} öğrenci bulundu`);

        // 💡 PERFORMANS: Tüm ilerlemeleri tek query ile çek (N+1 problemi çözüldü)
        const studentIds = populatedClassroom.students
            .filter(s => s !== null)
            .map(s => s._id);

        console.log('📈 Progress kayıtları aranıyor...', { studentCount: studentIds.length });
        const allProgress = await Progress.find({ 
            student: { $in: studentIds },
            classroom: classId 
        })
        .select('student overallScore activityRecords')
        .lean();
        
        console.log(`✅ ${allProgress.length} progress kaydı bulundu`);

        // Progress'leri student ID'ye göre map'le (hızlı erişim için)
        const progressMap = new Map();
        allProgress.forEach(p => {
            if (p.student) {
                progressMap.set(p.student.toString(), p);
            }
        });

        // Öğrencileri ilerleme bilgileri ile birleştir
        console.log('🔄 Öğrenciler progress bilgileri ile birleştiriliyor...');
        const studentsWithProgress = populatedClassroom.students
            .filter(student => student !== null)
            .map((student, index) => {
                try {
                    console.log(`  📝 Öğrenci ${index + 1}/${populatedClassroom.students.length}: ${student.firstName} ${student.lastName}`);
                    const progress = progressMap.get(student._id.toString());
                    
                    // En son aktivite tarihini bul
                    let lastActivity = null;
                    try {
                        if (progress && progress.activityRecords && Array.isArray(progress.activityRecords) && progress.activityRecords.length > 0) {
                            console.log(`    📅 ${progress.activityRecords.length} aktivite kaydı bulundu`);
                            // completionDate'e göre sırala ve en son olanı al
                            const sortedRecords = progress.activityRecords
                                .filter(record => {
                                    if (!record || !record.completionDate) {
                                        console.log(`    ⚠️ Geçersiz kayıt atlandı:`, record);
                                        return false;
                                    }
                                    return true;
                                })
                                .map(record => {
                                    try {
                                        const dateObj = new Date(record.completionDate);
                                        return {
                                            ...record,
                                            completionDate: dateObj
                                        };
                                    } catch (dateError) {
                                        console.log(`    ⚠️ Tarih parse hatası:`, record.completionDate, dateError.message);
                                        return null;
                                    }
                                })
                                .filter(record => record !== null && !isNaN(record.completionDate.getTime())) // Geçerli tarih kontrolü
                                .sort((a, b) => {
                                    return b.completionDate - a.completionDate; // En yeni önce
                                });
                            
                            if (sortedRecords.length > 0) {
                                // Date objesini ISO string'e çevir (JSON serialization için)
                                const dateObj = sortedRecords[0].completionDate;
                                if (dateObj && dateObj instanceof Date && !isNaN(dateObj.getTime())) {
                                    lastActivity = dateObj.toISOString();
                                    console.log(`    ✅ Son aktivite: ${lastActivity}`);
                                } else {
                                    console.log(`    ⚠️ Geçersiz tarih objesi:`, dateObj);
                                }
                            } else {
                                console.log(`    ℹ️ Geçerli tarihli kayıt bulunamadı`);
                            }
                        } else {
                            console.log(`    ℹ️ Aktivite kaydı yok`);
                        }
                    } catch (dateError) {
                        // Tarih işleme hatası durumunda lastActivity null kalır
                        console.error(`    ❌ Tarih işleme hatası (öğrenci: ${student.firstName}):`, dateError.message, dateError.stack);
                    }
                
                    return {
                        id: student._id,
                        firstName: student.firstName,
                        lastName: student.lastName,
                        role: student.role,
                        progress: progress ? {
                            overallScore: progress.overallScore || 0,
                            completedActivities: progress.activityRecords?.length || 0
                        } : {
                            overallScore: 0,
                            completedActivities: 0
                        },
                        lastActivity: lastActivity
                    };
                } catch (studentError) {
                    console.error(`    ❌ Öğrenci işleme hatası (${student.firstName} ${student.lastName}):`, studentError.message, studentError.stack);
                    // Hata durumunda minimal bilgi döndür
                    return {
                        id: student._id,
                        firstName: student.firstName || '',
                        lastName: student.lastName || '',
                        role: student.role || 'Student',
                        progress: {
                            overallScore: 0,
                            completedActivities: 0
                        },
                        lastActivity: null
                    };
                }
            });

        console.log(`✅ ${studentsWithProgress.length} öğrenci başarıyla işlendi`);
        res.status(200).json({
            success: true,
            classroom: {
                id: populatedClassroom._id,
                name: populatedClassroom.name,
                teacher: populatedClassroom.teacher
            },
            students: studentsWithProgress,
            totalStudents: studentsWithProgress.length
        });
    } catch (error) {
        console.error('❌ getClassroomStudents HATASI:');
        console.error('  📍 Hata mesajı:', error.message);
        console.error('  📍 Hata tipi:', error.name);
        console.error('  📍 Stack trace:', error.stack);
        console.error('  📍 Request bilgileri:', { classId, teacherId });
        res.status(500).json({
            success: false,
            message: 'Öğrenciler yüklenemedi.',
            error: error.message,
            stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
        });
    }
};
