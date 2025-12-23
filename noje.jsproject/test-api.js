// API Test Scripti (Node.js)
// Kullanım: node test-api.js

const http = require('http');

const baseUrl = 'http://localhost:3000';

// Renkli console çıktısı için
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function makeRequest(options, data = null) {
    return new Promise((resolve, reject) => {
        const req = http.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => { body += chunk; });
            res.on('end', () => {
                try {
                    const json = JSON.parse(body);
                    resolve({ status: res.statusCode, data: json, raw: body });
                } catch (e) {
                    resolve({ status: res.statusCode, data: null, raw: body });
                }
            });
        });

        req.on('error', (error) => {
            reject(error);
        });

        if (data) {
            req.write(JSON.stringify(data));
        }
        req.end();
    });
}

async function testHealthCheck() {
    log('\n1️⃣ Health Check Testi...', 'yellow');
    try {
        const result = await makeRequest({
            hostname: 'localhost',
            port: 3000,
            path: '/api/health',
            method: 'GET'
        });

        if (result.status === 200) {
            log('   ✅ Health Check BAŞARILI!', 'green');
            log(`   📊 Status: ${result.data.status}`, 'green');
            return true;
        } else {
            log(`   ❌ Beklenmeyen Status: ${result.status}`, 'red');
            return false;
        }
    } catch (error) {
        log('   ❌ Health Check BAŞARISIZ!', 'red');
        log(`   Hata: ${error.message}`, 'red');
        log('\n⚠️  API çalışmıyor! Önce "npm start" ile başlatın.', 'yellow');
        return false;
    }
}

async function testTeacherRegistration() {
    log('\n2️⃣ Öğretmen Kaydı Testi...', 'yellow');
    const randomEmail = `test_${Math.random().toString(36).substring(7)}@example.com`;
    const teacherData = {
        firstName: 'Test',
        lastName: 'Öğretmen',
        email: randomEmail,
        password: 'Test123456'
    };

    try {
        const result = await makeRequest({
            hostname: 'localhost',
            port: 3000,
            path: '/api/users/register/teacher',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        }, teacherData);

        if (result.status === 201) {
            log('   ✅ Öğretmen Kaydı BAŞARILI!', 'green');
            log(`   📝 Teacher ID: ${result.data.teacher.id}`, 'cyan');
            log(`   📝 Classroom ID: ${result.data.classroom.id}`, 'cyan');
            return {
                teacherId: result.data.teacher.id,
                classroomId: result.data.classroom.id
            };
        } else {
            log(`   ❌ Beklenmeyen Status: ${result.status}`, 'red');
            if (result.data && result.data.message) {
                log(`   Mesaj: ${result.data.message}`, 'red');
            }
            return null;
        }
    } catch (error) {
        log('   ❌ Öğretmen Kaydı BAŞARISIZ!', 'red');
        log(`   Hata: ${error.message}`, 'red');
        return null;
    }
}

async function testGetClassrooms(teacherId) {
    log('\n3️⃣ Sınıf Listeleme Testi...', 'yellow');
    try {
        const result = await makeRequest({
            hostname: 'localhost',
            port: 3000,
            path: `/api/classrooms/teacher/${teacherId}`,
            method: 'GET'
        });

        if (result.status === 200) {
            log('   ✅ Sınıf Listeleme BAŞARILI!', 'green');
            const count = result.data.classrooms ? result.data.classrooms.length : 0;
            log(`   📊 Sınıf Sayısı: ${count}`, 'cyan');
            return true;
        } else {
            log(`   ❌ Beklenmeyen Status: ${result.status}`, 'red');
            return false;
        }
    } catch (error) {
        log('   ❌ Sınıf Listeleme BAŞARISIZ!', 'red');
        log(`   Hata: ${error.message}`, 'red');
        return false;
    }
}

async function testAddStudent(classroomId) {
    log('\n4️⃣ Öğrenci Ekleme Testi...', 'yellow');
    const studentData = {
        firstName: 'Test',
        lastName: 'Öğrenci',
        role: 'Student'
    };

    try {
        const result = await makeRequest({
            hostname: 'localhost',
            port: 3000,
            path: `/api/classrooms/${classroomId}/add-student`,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        }, studentData);

        if (result.status === 201) {
            log('   ✅ Öğrenci Ekleme BAŞARILI!', 'green');
            if (result.data.student && result.data.student.id) {
                log(`   📝 Student ID: ${result.data.student.id}`, 'cyan');
            }
            return true;
        } else {
            log(`   ❌ Beklenmeyen Status: ${result.status}`, 'red');
            if (result.data && result.data.message) {
                log(`   Mesaj: ${result.data.message}`, 'red');
            }
            return false;
        }
    } catch (error) {
        log('   ❌ Öğrenci Ekleme BAŞARISIZ!', 'red');
        log(`   Hata: ${error.message}`, 'red');
        return false;
    }
}

// Ana test fonksiyonu
async function runTests() {
    log('🧪 API TEST BAŞLATILIYOR...', 'cyan');

    // 1. Health Check
    const healthOk = await testHealthCheck();
    if (!healthOk) {
        process.exit(1);
    }

    // 2. Öğretmen Kaydı
    const ids = await testTeacherRegistration();
    if (!ids) {
        log('\n⚠️  Öğretmen kaydı başarısız, diğer testler atlanıyor.', 'yellow');
        log('\n🎉 TEST TAMAMLANDI!', 'green');
        log('\n📚 Swagger UI: http://localhost:3000/api-docs', 'cyan');
        log('🏥 Health Check: http://localhost:3000/api/health', 'cyan');
        return;
    }

    // 3. Sınıf Listeleme
    await testGetClassrooms(ids.teacherId);

    // 4. Öğrenci Ekleme
    await testAddStudent(ids.classroomId);

    log('\n🎉 TEST TAMAMLANDI!', 'green');
    log('\n📚 Swagger UI: http://localhost:3000/api-docs', 'cyan');
    log('🏥 Health Check: http://localhost:3000/api/health', 'cyan');
}

// Testleri çalıştır
runTests().catch((error) => {
    log(`\n❌ Test sırasında hata oluştu: ${error.message}`, 'red');
    process.exit(1);
});

