# Okutopia - Eğitim Platformu

Okutopia, öğrenciler için interaktif okuma ve öğrenme platformudur. Flutter ile geliştirilmiş mobil uygulama ve Node.js/Express ile geliştirilmiş backend API'sinden oluşmaktadır.

## 📋 İçindekiler

- [Özellikler](#özellikler)
- [Teknolojiler](#teknolojiler)
- [Kurulum](#kurulum)
- [Çalıştırma](#çalıştırma)
- [Proje Yapısı](#proje-yapısı)
- [Katkıda Bulunma](#katkıda-bulunma)
- [Lisans](#lisans)

## ✨ Özellikler

- 📚 Kategori, Grup, Ders ve Aktivite yönetimi
- ❓ Dinamik soru ekleme sistemi (Metin, Ses, Resim, Sürükle-Bırak)
- 👥 Öğrenci ve Öğretmen yönetimi
- 📊 İstatistik takibi ve raporlama
- 🔐 JWT tabanlı kimlik doğrulama
- 📱 Flutter ile cross-platform mobil uygulama
- 🌐 Admin paneli (HTML/JavaScript)

## 🛠 Teknolojiler

### Backend
- **Node.js** - Runtime environment
- **Express.js** - Web framework
- **MongoDB** - Veritabanı
- **Mongoose** - ODM
- **JWT** - Authentication
- **GridFS** - Dosya depolama
- **Winston** - Logging

### Frontend
- **Flutter** - Cross-platform framework
- **Dart** - Programming language
- **Provider** - State management
- **Dio** - HTTP client

## 🚀 Kurulum

### Gereksinimler

- Node.js (v18 veya üzeri)
- MongoDB (v5 veya üzeri)
- Flutter SDK (v3.8 veya üzeri)
- Git

### Backend Kurulumu

1. Repository'yi klonlayın:
```bash
git clone https://github.com/BilalDariyeri/Okutopia.git
cd Okutopia
```

2. Backend klasörüne gidin:
```bash
cd noje.jsproject
```

3. Bağımlılıkları yükleyin:
```bash
npm install
```

4. `.env` dosyası oluşturun:
```bash
cp .env.example .env
```

5. `.env` dosyasını düzenleyin ve gerekli değerleri girin:
```env
MONGO_URI=mongodb://localhost:27017/okutopia
JWT_SECRET=your-secret-key-here
JWT_EXPIRE=30d
NODE_ENV=development
PORT=3000
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
EMAIL_SERVICE=gmail
```

### Frontend Kurulumu

1. Flutter klasörüne gidin:
```bash
cd flutterproject
```

2. Bağımlılıkları yükleyin:
```bash
flutter pub get
```

## ▶️ Çalıştırma

### Backend

```bash
cd noje.jsproject
npm start
```

Backend `http://localhost:3000` adresinde çalışacaktır.

### Frontend

```bash
cd flutterproject
flutter run
```

### Admin Paneli

Backend çalıştıktan sonra tarayıcıda şu adresi açın:
```
http://localhost:3000/admin
```

## 📁 Proje Yapısı

```
Okutopia/
├── noje.jsproject/          # Backend (Node.js/Express)
│   ├── admin/               # Admin panel (HTML)
│   ├── config/              # Yapılandırma dosyaları
│   ├── controllers/         # İş mantığı
│   ├── models/              # Veritabanı modelleri
│   ├── routes/              # API rotaları
│   ├── middleware/          # Middleware'ler
│   ├── utils/               # Yardımcı fonksiyonlar
│   ├── scripts/              # Yardımcı scriptler
│   └── app.js               # Ana dosya
│
└── flutterproject/          # Frontend (Flutter)
    ├── lib/
    │   ├── config/          # API yapılandırması
    │   ├── models/          # Veri modelleri
    │   ├── providers/       # State management
    │   ├── screens/         # Ekranlar
    │   └── services/        # API servisleri
    ├── android/              # Android platform dosyaları
    ├── ios/                  # iOS platform dosyaları
    └── pubspec.yaml         # Flutter bağımlılıkları
```

## 🤝 Katkıda Bulunma

Bu projeye katkıda bulunmak için lütfen [CONTRIBUTING.md](CONTRIBUTING.md) dosyasını okuyun.

### Genel Kurallar

1. Yeni bir özellik eklemeden önce issue açın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add amazing feature'`)
4. Branch'inizi push edin (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun

## 📝 Scripts

### Backend Scripts

```bash
npm start                    # Sunucuyu başlat
npm run logs                 # Logları görüntüle
npm run logs:watch           # Logları izle
npm run logs:error           # Sadece hata logları
npm run create-admin         # Admin kullanıcı oluştur
npm run make-admin           # Kullanıcıyı admin yap
npm run make-superadmin      # Kullanıcıyı superadmin yap
```

## 🔒 Güvenlik

- `.env` dosyasını asla commit etmeyin
- JWT_SECRET'i güçlü ve rastgele bir değer yapın
- Production'da `NODE_ENV=production` kullanın
- MongoDB bağlantı string'inizi güvende tutun

## 📄 Lisans

Bu proje ISC lisansı altında lisanslanmıştır.

## 👥 Geliştiriciler

- Bilal Dariyeri - [GitHub](https://github.com/BilalDariyeri)

## 📞 İletişim

Sorularınız için issue açabilir veya doğrudan iletişime geçebilirsiniz.

