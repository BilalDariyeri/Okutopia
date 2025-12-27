// utils/emailService.js - Email Gönderme Servisi

const nodemailer = require('nodemailer');
const logger = require('../config/logger');

// Email transporter oluştur (sistem email'i ile - tek bir App Password yeterli)
const createTransporter = () => {
    // Gmail için örnek yapılandırma
    // Sistem email'i ve App Password'ü kullanılır (tek bir hesap yeterli)
    // ÖNEMLİ: Gmail için App Password kullanılmalı (normal şifre çalışmaz)
    
    const emailUser = process.env.EMAIL_USER;
    const emailPass = process.env.EMAIL_PASS;
    
    if (!emailUser || !emailPass) {
        logger.error('Email yapılandırma hatası: EMAIL_USER veya EMAIL_PASS .env dosyasında tanımlı değil!');
        throw new Error('Email yapılandırması eksik: EMAIL_USER ve EMAIL_PASS .env dosyasında tanımlanmalıdır.');
    }
    
    logger.info('Email transporter oluşturuluyor', { 
        service: process.env.EMAIL_SERVICE || 'gmail',
        user: emailUser 
    });
    
    return nodemailer.createTransport({
        service: process.env.EMAIL_SERVICE || 'gmail',
        auth: {
            user: emailUser,
            pass: emailPass
        }
    });
};

/**
 * Öğrenci istatistiklerini veliye email olarak gönder
 * @param {Object} options - Email seçenekleri
 * @param {String} options.to - Alıcı email adresi
 * @param {String} options.studentName - Öğrenci adı
 * @param {Number} options.totalTimeSpent - Toplam geçirilen süre (saniye)
 * @param {Number} options.totalReadingTime - Toplam okuma süresi (saniye)
 * @param {Number} options.totalWordsRead - Toplam okunan kelime sayısı
 * @param {Number} options.averageReadingSpeed - Ortalama okuma hızı (kelime/dakika)
 * @param {Number} options.completedActivities - Tamamlanan aktivite sayısı
 * @param {Array} options.activities - Tamamlanan aktiviteler listesi (eski format)
 * @param {Object} options.activitiesByCategory - Kategori bazlı aktiviteler (eski format)
 * @param {Object} options.completedLessons - Tamamlanan dersler (yeni format - ders bazlı)
 * @param {String} options.dateLabel - İstatistiklerin tarihi (örn: "Bugün" veya "15 Ocak 2024")
 * @param {Boolean} options.noActivityToday - Bugün aktivite yok mu? (true ise özel mesaj gösterilir)
 * @param {String} options.senderName - Giriş yapan kullanıcının adı (From Name olarak görünecek)
 * @param {String} options.replyToEmail - Giriş yapan kullanıcının email adresi (Reply-To olarak ayarlanacak)
 * @returns {Promise<Object>} Email gönderme sonucu
 */
const sendStatisticsEmail = async (options) => {
    const { 
        to, 
        studentName, 
        totalTimeSpent, 
        totalReadingTime = 0,
        totalWordsRead = 0,
        averageReadingSpeed = 0,
        completedActivities, 
        activities = [],
        activitiesByCategory = {},
        completedLessons = {},
        dateLabel = 'Bugün',
        noActivityToday = false,
        senderName = 'Eğitim Sistemi', // Giriş yapan kullanıcının adı (From Name)
        replyToEmail = null, // Giriş yapan kullanıcının email'i (Reply-To)
        customHtmlContent = null, // Özel HTML içeriği (varsa kullanılır)
        customTextContent = null // Özel text içeriği (varsa kullanılır)
    } = options;

    if (!to || !studentName) {
        throw new Error('Email adresi ve öğrenci adı zorunludur.');
    }

    // Süreyi formatla (saniye -> saat:dakika:saniye)
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

    // Ders bazlı tamamlanan dersler listesini formatla (yeni format - öncelikli)
    let completedLessonsHtml = '';
    if (Object.keys(completedLessons).length > 0) {
        completedLessonsHtml = Object.values(completedLessons).map((lesson, lessonIndex) => {
            const averageScore = lesson.activityCount > 0 
                ? Math.round((lesson.totalScore / lesson.activityCount) * 100) / 100 
                : 0;
            
            return `
                <div style="margin-top: 20px; background-color: white; padding: 15px; border-radius: 5px; border-left: 4px solid #4CAF50;">
                    <h3 style="color: #4CAF50; margin-bottom: 10px;">📖 ${lesson.title}</h3>
                    <p style="color: #666; margin-bottom: 10px;">
                        <strong>${lesson.activityCount}</strong> aktivite tamamlandı | 
                        Ortalama Puan: <strong>${averageScore}</strong> | 
                        Toplam Puan: <strong>${lesson.totalScore}</strong>
                    </p>
                </div>
            `;
        }).join('');
    }
    
    // Kategori bazlı aktivite listesini formatla (eski format - geriye dönük uyumluluk)
    let activitiesByCategoryHtml = '';
    if (Object.keys(completedLessons).length === 0 && Object.keys(activitiesByCategory).length > 0) {
        activitiesByCategoryHtml = Object.entries(activitiesByCategory).map(([categoryName, categoryActivities]) => {
            const activitiesList = categoryActivities.map((activity, index) => {
                const readingTimeDisplay = activity.readingTime 
                    ? formatTime(activity.readingTime) 
                    : '-';
                const readingSpeedDisplay = activity.readingSpeed && activity.readingSpeed > 0
                    ? `${activity.readingSpeed.toFixed(1)} kelime/dk`
                    : '-';
                
                return `
                    <tr>
                        <td style="border: 1px solid #ddd; padding: 8px;">${index + 1}</td>
                        <td style="border: 1px solid #ddd; padding: 8px;">${activity.title}</td>
                        <td style="border: 1px solid #ddd; padding: 8px;">${activity.score} puan</td>
                        <td style="border: 1px solid #ddd; padding: 8px;">${readingTimeDisplay}</td>
                        <td style="border: 1px solid #ddd; padding: 8px;">${readingSpeedDisplay}</td>
                    </tr>
                `;
            }).join('');
            
            return `
                <div style="margin-top: 20px;">
                    <h3 style="color: #4CAF50; margin-bottom: 10px;">📚 ${categoryName} Etkinlikleri</h3>
                    <p style="color: #666; margin-bottom: 10px;"><strong>${categoryActivities.length}</strong> aktivite tamamlandı</p>
                    <table style="width: 100%; border-collapse: collapse;">
                        <thead>
                            <tr>
                                <th style="border: 1px solid #ddd; padding: 8px; background-color: #4CAF50; color: white;">#</th>
                                <th style="border: 1px solid #ddd; padding: 8px; background-color: #4CAF50; color: white;">Aktivite</th>
                                <th style="border: 1px solid #ddd; padding: 8px; background-color: #4CAF50; color: white;">Puan</th>
                                <th style="border: 1px solid #ddd; padding: 8px; background-color: #4CAF50; color: white;">Okuma Süresi</th>
                                <th style="border: 1px solid #ddd; padding: 8px; background-color: #4CAF50; color: white;">Okuma Hızı</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${activitiesList}
                        </tbody>
                    </table>
                </div>
            `;
        }).join('');
    } else if (activities.length > 0) {
        // Eski format (geriye dönük uyumluluk)
        activitiesByCategoryHtml = activities.map((activity, index) => {
            const activityName = activity.activityId?.title || activity.title || 'Bilinmeyen Aktivite';
            const score = activity.score || activity.finalScore || 0;
            const completionTime = activity.completionTime || activity.completionDate;
            const date = completionTime ? new Date(completionTime).toLocaleString('tr-TR') : 'Bilinmiyor';
            
            return `
                <tr>
                    <td style="border: 1px solid #ddd; padding: 8px;">${index + 1}</td>
                    <td style="border: 1px solid #ddd; padding: 8px;">${activityName}</td>
                    <td style="border: 1px solid #ddd; padding: 8px;">${score} puan</td>
                    <td style="border: 1px solid #ddd; padding: 8px;">${date}</td>
                </tr>
            `;
        }).join('');
        
        activitiesByCategoryHtml = `
            <h3 style="margin-top: 20px;">Tamamlanan Aktiviteler</h3>
            <table style="width: 100%; border-collapse: collapse;">
                <thead>
                    <tr>
                        <th style="border: 1px solid #ddd; padding: 8px; background-color: #4CAF50; color: white;">#</th>
                        <th style="border: 1px solid #ddd; padding: 8px; background-color: #4CAF50; color: white;">Aktivite</th>
                        <th style="border: 1px solid #ddd; padding: 8px; background-color: #4CAF50; color: white;">Puan</th>
                        <th style="border: 1px solid #ddd; padding: 8px; background-color: #4CAF50; color: white;">Tarih</th>
                    </tr>
                </thead>
                <tbody>
                    ${activitiesByCategoryHtml}
                </tbody>
            </table>
        `;
    } else if (Object.keys(completedLessons).length === 0) {
        completedLessonsHtml = '<p style="color: #666; font-style: italic;">Henüz ders tamamlanmamış</p>';
    }

    // Özel içerik varsa onu kullan, yoksa varsayılan içeriği oluştur
    let htmlContent;
    let textContent;
    
    if (customHtmlContent && customTextContent) {
        // Özel içerik kullan
        htmlContent = customHtmlContent;
        textContent = customTextContent;
    } else {
        // Varsayılan içerik oluştur
        htmlContent = `
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
                .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>📊 Öğrenci İstatistik Raporu</h1>
                </div>
                <div class="content">
                    <p>Sayın Veli,</p>
                    ${noActivityToday ? `
                    <p><strong>${studentName}</strong> öğrencisi <strong>${dateLabel}</strong> hiç aktivite tamamlamamıştır.</p>
                    <div class="stat-box" style="background-color: #fff3cd; border-left-color: #ffc107;">
                        <div class="stat-label" style="color: #856404;">Durum</div>
                        <div class="stat-value" style="color: #856404;">Bugün aktivite tamamlanmadı</div>
                    </div>
                    <p style="margin-top: 20px; color: #666;">Öğrencinin bugün uygulamada herhangi bir aktivite tamamlamadığı kaydedilmiştir.</p>
                    ` : `
                    <p><strong>${studentName}</strong> öğrencisinin ${dateLabel} çalışma istatistikleri aşağıda yer almaktadır:</p>
                    
                    <div class="stat-box">
                        <div class="stat-label">Uygulamada Geçirilen Süre</div>
                        <div class="stat-value">${formatTime(totalTimeSpent)}</div>
                    </div>
                    
                    ${totalReadingTime > 0 ? `
                    <div class="stat-box">
                        <div class="stat-label">Okuma Süresi</div>
                        <div class="stat-value">${formatTime(totalReadingTime)}</div>
                    </div>
                    ` : ''}
                    
                    ${averageReadingSpeed > 0 ? `
                    <div class="stat-box">
                        <div class="stat-label">Okuma Hızı</div>
                        <div class="stat-value">${averageReadingSpeed.toFixed(1)} kelime/dakika</div>
                    </div>
                    ` : ''}
                    
                    <div class="stat-box">
                        <div class="stat-label">Tamamlanan Aktivite Sayısı</div>
                        <div class="stat-value">${completedActivities}</div>
                    </div>
                    
                    ${completedLessonsHtml || activitiesByCategoryHtml}
                    `}
                    
                    <p style="margin-top: 20px;">İyi çalışmalar dileriz.</p>
                </div>
                <div class="footer">
                    <p>Bu e-posta otomatik olarak gönderilmiştir.</p>
                </div>
            </div>
        </body>
        </html>
    `;

        // Text içeriği oluştur (varsayılan)
        textContent = `
Öğrenci İstatistik Raporu

Sayın Veli,

${noActivityToday ? 
`${studentName} öğrencisi ${dateLabel} hiç aktivite tamamlamamıştır.

Durum: Bugün aktivite tamamlanmadı

Öğrencinin bugün uygulamada herhangi bir aktivite tamamlamadığı kaydedilmiştir.` :
`${studentName} öğrencisinin ${dateLabel} çalışma istatistikleri:

Uygulamada Geçirilen Süre: ${formatTime(totalTimeSpent)}`}
`;

        if (!noActivityToday) {
        if (totalReadingTime > 0) {
            textContent += `Okuma Süresi: ${formatTime(totalReadingTime)}\n`;
        }
        
        if (averageReadingSpeed > 0) {
            textContent += `Okuma Hızı: ${averageReadingSpeed.toFixed(1)} kelime/dakika\n`;
        }
        
        textContent += `Tamamlanan Aktivite Sayısı: ${completedActivities}\n\n`;

        // Ders bazlı format (yeni format - öncelikli)
        if (Object.keys(completedLessons).length > 0) {
            textContent += 'Tamamlanan Dersler:\n\n';
            Object.values(completedLessons).forEach((lesson, lessonIndex) => {
                const averageScore = lesson.activityCount > 0 
                    ? Math.round((lesson.totalScore / lesson.activityCount) * 100) / 100 
                    : 0;
                textContent += `${lessonIndex + 1}. ${lesson.title}\n`;
                textContent += `   - Tamamlanan Aktivite: ${lesson.activityCount}\n`;
                textContent += `   - Ortalama Puan: ${averageScore}\n`;
                textContent += `   - Toplam Puan: ${lesson.totalScore}\n\n`;
            });
        } else if (Object.keys(activitiesByCategory).length > 0) {
            textContent += 'Tamamlanan Aktiviteler:\n\n';
            Object.entries(activitiesByCategory).forEach(([categoryName, categoryActivities]) => {
                textContent += `${categoryName} Etkinlikleri (${categoryActivities.length} aktivite):\n`;
                categoryActivities.forEach((activity, index) => {
                    const readingTimeDisplay = activity.readingTime 
                        ? formatTime(activity.readingTime) 
                        : 'Okuma yapılmadı';
                    const readingSpeedDisplay = activity.readingSpeed && activity.readingSpeed > 0
                        ? `${activity.readingSpeed.toFixed(1)} kelime/dk`
                        : '';
                    textContent += `  ${index + 1}. ${activity.title} - ${activity.score} puan`;
                    if (activity.readingTime) {
                        textContent += ` - Okuma: ${readingTimeDisplay}`;
                        if (readingSpeedDisplay) {
                            textContent += ` (${readingSpeedDisplay})`;
                        }
                    }
                    textContent += '\n';
                });
                textContent += '\n';
            });
        } else if (activities.length > 0) {
            textContent += 'Tamamlanan Aktiviteler:\n';
            activities.forEach((activity, index) => {
                const activityName = activity.activityId?.title || activity.title || 'Bilinmeyen Aktivite';
                const score = activity.score || activity.finalScore || 0;
                textContent += `${index + 1}. ${activityName} - ${score} puan\n`;
            });
        } else {
            textContent += 'Henüz ders tamamlanmamış\n';
        }
        }
        
        textContent += '\nİyi çalışmalar dileriz.';
    }

    try {
        // Email transporter oluştur (sistem email'i ile - tek bir App Password yeterli)
        const systemEmail = process.env.EMAIL_FROM || process.env.EMAIL_USER;
        
        logger.info('Email gönderme başlatılıyor', { 
            to, 
            studentName, 
            from: systemEmail,
            fromName: senderName,
            replyTo: replyToEmail || systemEmail
        });
        
        const transporter = createTransporter(); // Sistem email'i ile transporter oluştur
        
        // Transporter'ı test et
        await transporter.verify();
        logger.info('Email transporter doğrulandı');
        
        // Email seçenekleri:
        // From: Sistem email'i (teknik olarak sistemden gönderilir: okutopia.app@gmail.com)
        // From Name: Giriş yapan kullanıcının adı (veli "Ahmet Öğretmen" görür)
        // Reply-To: Giriş yapan kullanıcının email'i (yanıtlar öğretmenin email'ine gider)
        const mailOptions = {
            from: `"${senderName}" <${systemEmail}>`, // Sistem email'i ama öğretmenin adı görünür
            replyTo: replyToEmail || systemEmail, // Yanıtlar öğretmenin email'ine gider
            to: to,
            subject: customHtmlContent 
                ? `${studentName} - Oturum Raporu`
                : `${studentName} - ${dateLabel} Çalışma İstatistikleri`,
            text: textContent,
            html: htmlContent
        };

        logger.info('Email gönderiliyor', { 
            from: mailOptions.from, 
            to: mailOptions.to,
            subject: mailOptions.subject 
        });
        
        const info = await transporter.sendMail(mailOptions);
        
        logger.info('Email başarıyla gönderildi', {
            to: to,
            studentName: studentName,
            messageId: info.messageId,
            response: info.response
        });

        return {
            success: true,
            messageId: info.messageId
        };
    } catch (error) {
        logger.error('Email gönderme hatası', {
            to: to,
            studentName: studentName,
            error: error.message,
            stack: error.stack,
            code: error.code,
            command: error.command,
            response: error.response
        });
        
        // Daha açıklayıcı hata mesajı
        let errorMessage = 'Email gönderilemedi.';
        if (error.code === 'EAUTH') {
            errorMessage = 'Email kimlik doğrulama hatası. EMAIL_USER ve EMAIL_PASS bilgilerini kontrol edin. Gmail için App Password kullanılmalıdır.';
        } else if (error.code === 'ECONNECTION') {
            errorMessage = 'Email sunucusuna bağlanılamadı. İnternet bağlantınızı kontrol edin.';
        } else if (error.message) {
            errorMessage = `Email gönderme hatası: ${error.message}`;
        }
        
        throw new Error(errorMessage);
    }
};

module.exports = {
    sendStatisticsEmail
};

