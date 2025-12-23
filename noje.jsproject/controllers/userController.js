const path = require('path');
const User = require('../models/user');
const Classroom = require(path.resolve(__dirname, '../models/classroom'));
const Progress = require(path.resolve(__dirname, '../models/Progress'));
const jwt = require('jsonwebtoken');

// JWT token oluşturma yardımcı fonksiyonu
const generateToken = (userId) => {
    return jwt.sign(
        { userId },
        process.env.JWT_SECRET || 'fallback-secret-key-change-in-production',
        { expiresIn: process.env.JWT_EXPIRE || '30d' }
    );
};

// Öğretmen kaydı ve otomatik sınıf oluşturma
// 💡 PERFORMANS: Transaction kullanarak atomicity sağlıyoruz
exports.registerTeacherAndCreateClass = async (req, res) => {
  const { firstName, lastName, email, password } = req.body;
  const mongoose = require('mongoose');
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    // E-posta kontrolü (transaction dışında, hızlı kontrol)
    const existingUser = await User.findOne({ email }).lean();
    if (existingUser) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({ 
        success: false,
        message: 'Bu e-posta adresi zaten kayıtlı.' 
      });
    }

    // Yeni öğretmeni kaydet (Transaction içinde, şifre otomatik hash'lenecek)
    const [newTeacher] = await User.create([{
      firstName,
      lastName,
      email,
      password,
      role: 'Teacher'
    }], { session });
    const teacherId = newTeacher._id;

    // 💡 NOT: Öğretmenler students koleksiyonuna eklenmez, sadece öğrenciler eklenir

    // Yeni sınıf oluştur (Transaction içinde)
    const [newClassroom] = await Classroom.create([{
      name: `${firstName} ${lastName}'in Sınıfı`,
      teacher: teacherId,
      students: []
    }], { session });

    // Sınıf bilgisini populate et (öğrenciler ve öğretmen bilgisi ile)
    const populatedClassroom = await Classroom.findById(newClassroom._id)
      .populate('teacher', 'firstName lastName email')
      .populate('students', 'firstName lastName')
      .lean()
      .session(session);

    // Transaction'ı commit et
    await session.commitTransaction();
    session.endSession();

    // Token oluştur
    const token = generateToken(newTeacher._id);

    // Şifreyi response'dan çıkar ve email'i garantile
    const teacherResponse = {
      id: newTeacher._id.toString(),
      firstName: newTeacher.firstName,
      lastName: newTeacher.lastName,
      email: newTeacher.email || email,
      role: newTeacher.role
    };

    // Response'u düzenle - Tüm gerekli bilgileri tek seferde döndür
    const response = {
      success: true,
      message: 'Öğretmen başarıyla kaydedildi ve sınıf oluşturuldu.',
      token,
      teacher: teacherResponse,
      classroom: {
        id: populatedClassroom?._id?.toString() || newClassroom._id.toString(),
        name: populatedClassroom?.name || newClassroom.name,
        teacher: {
          id: teacherResponse.id,
          firstName: teacherResponse.firstName,
          lastName: teacherResponse.lastName,
          email: teacherResponse.email
        },
        students: populatedClassroom?.students || [],
        createdAt: populatedClassroom?.createdAt || newClassroom.createdAt,
        updatedAt: populatedClassroom?.updatedAt || newClassroom.updatedAt
      }
    };

    res.status(201).json(response);

  } catch (error) {
    // Hata durumunda transaction'ı geri al
    await session.abortTransaction();
    session.endSession();
    res.status(400).json({ 
      success: false,
      message: 'Öğretmen kaydı sırasında hata oluştu', 
      error: error.message 
    });
  }
};

// Öğretmen girişi
exports.login = async (req, res) => {
  const { email, password } = req.body;

  try {
    console.log('🔍 Login denemesi:', { email: email?.trim()?.toLowerCase() });
    
    // Kullanıcıyı bul (şifre dahil)
    const user = await User.findOne({ email: email?.trim()?.toLowerCase() }).select('+password');
    
    if (!user) {
      console.error('❌ Kullanıcı bulunamadı:', email);
      return res.status(401).json({
        success: false,
        message: 'Geçersiz e-posta veya şifre.'
      });
    }

    console.log('✅ Kullanıcı bulundu:', { 
      email: user.email, 
      role: user.role, 
      hasPassword: !!user.password 
    });

    // Sadece öğretmenler, adminler ve superadminler giriş yapabilir
    if (user.role !== 'Teacher' && user.role !== 'Admin' && user.role !== 'SuperAdmin') {
      console.error('❌ Geçersiz rol:', user.role);
      return res.status(401).json({
        success: false,
        message: 'Kullanıcı adı ve şifre hatalı.'
      });
    }

    // Şifre kontrolü
    console.log('🔐 Şifre kontrol ediliyor...');
    const isPasswordMatch = await user.comparePassword(password);
    console.log('🔐 Şifre eşleşmesi:', isPasswordMatch);
    
    if (!isPasswordMatch) {
      console.error('❌ Şifre eşleşmedi');
      return res.status(401).json({
        success: false,
        message: 'Geçersiz e-posta veya şifre.'
      });
    }

    console.log('✅ Şifre doğru, token oluşturuluyor...');

    // Token oluştur (ObjectId'yi string'e çevir)
    const token = generateToken(user._id.toString());
    console.log('✅ Token oluşturuldu');

    // Öğretmenin sınıfını bul ve populate et (lean() ile optimize)
    const teacherClassroom = await Classroom.findOne({ teacher: user._id })
      .populate('teacher', 'firstName lastName email')
      .populate('students', 'firstName lastName')
      .lean(); // 💡 PERFORMANS: lean() kullanarak daha hızlı

    // Şifreyi response'dan çıkar
    const userResponse = {
      id: user._id.toString(),
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      role: user.role
    };

    res.status(200).json({
      success: true,
      message: 'Giriş başarılı.',
      token,
      user: userResponse,
      classroom: teacherClassroom || null // Sınıf varsa döndür, yoksa null
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Giriş sırasında hata oluştu',
      error: error.message
    });
  }
};

// Öğretmenin kendi sınıfına öğrenci ekleme (otomatik sınıf bulma)
// 💡 KRİTİK: Öğretmen sadece firstName, lastName gönderir, sistem token'dan öğretmen ID'sini alır ve otomatik kendi sınıfına ekler
exports.addStudentToMyClassroom = async (req, res) => {
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

    // Öğretmenin sınıfını bul (transaction dışında, hızlı kontrol)
    const teacherClassroom = await Classroom.findOne({ teacher: teacherId }).lean();
    
    if (!teacherClassroom) {
      await session.abortTransaction();
      session.endSession();
      return res.status(404).json({ 
        success: false,
        message: 'Öğrenci eklenemedi: Öğretmenin sınıfı bulunamadı. Önce sınıf oluşturulmalı.' 
      });
    }

    const classId = teacherClassroom._id;

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
        message: 'Öğrenci users koleksiyonuna eklendi ama classroom.students dizisine eklenemedi.' 
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
    res.status(400).json({ 
      success: false,
      message: 'Öğrenci ekleme işlemi sırasında hata oluştu.', 
      error: error.message 
    });
  }
};
