# Flutter Projesini Workspace'e Taşıma Rehberi

## 🎯 Amaç
Flutter projesini mevcut workspace'e taşıyarak tek bir yerde tüm kodları görmek.

## 📋 Adımlar

### 1. Flutter Uygulamasını ve IDE'yi Kapatın
- Flutter uygulaması çalışıyorsa durdurun
- Cursor/VS Code'u kapatın (opsiyonel ama önerilir)

### 2. Flutter Klasörünü Taşıyın

**Windows Explorer'da:**
1. `C:\Users\dariy\OneDrive\Desktop\flutter_demo` klasörüne gidin
2. Klasöre sağ tıklayın → "Kes" (Cut)
3. `C:\Users\dariy\OneDrive\Desktop\noje.jsproject` klasörüne gidin
4. Sağ tıklayın → "Yapıştır" (Paste)
5. Klasör adını `flutter_app` olarak değiştirin

**PowerShell ile:**
```powershell
# Flutter uygulamasını ve IDE'yi kapatın önce!
Move-Item -Path "C:\Users\dariy\OneDrive\Desktop\flutter_demo" -Destination "C:\Users\dariy\OneDrive\Desktop\noje.jsproject\flutter_app"
```

### 3. Workspace'i Yeniden Açın
1. Cursor'u açın
2. `C:\Users\dariy\OneDrive\Desktop\noje.jsproject` klasörünü workspace olarak açın
3. Artık hem backend hem Flutter kodlarını görebilirsiniz!

## 📁 Son Yapı

```
noje.jsproject/
├── admin/               # Backend admin panel
├── config/              # Backend config
├── controllers/         # Backend controllers
├── models/              # Backend models
├── routes/              # Backend routes
├── flutter_app/         # Flutter projesi (YENİ)
│   ├── lib/
│   │   ├── config/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   └── main.dart
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── .gitignore           # Güncellenmiş (Flutter için)
└── ...
```

## ✅ Kontrol

Taşıma işleminden sonra:

1. **Flutter projesini test edin:**
   ```bash
   cd flutter_app
   flutter pub get
   flutter run
   ```

2. **API config'i kontrol edin:**
   - `flutter_app/lib/config/api_config.dart` dosyasında URL'ler doğru mu?

3. **Workspace'te görünüyor mu?**
   - Cursor'da sol panelde `flutter_app` klasörünü görebiliyor musunuz?

## 🔧 Sorun Giderme

### "Flutter projesi bulunamadı" hatası
- `flutter_app` klasöründe `pubspec.yaml` dosyası var mı kontrol edin
- Flutter SDK'nın kurulu olduğundan emin olun

### "Bağlantı hatası" devam ediyorsa
- Backend'in çalıştığından emin olun
- `flutter_app/lib/config/api_config.dart` dosyasındaki URL'leri kontrol edin

## 📝 Notlar

- Flutter dosyaları backend ile karışmaz (ayrı klasörde)
- `.gitignore` her iki proje için yapılandırılmıştır
- Her proje kendi bağımsız çalışır

