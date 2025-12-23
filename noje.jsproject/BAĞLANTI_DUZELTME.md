# Flutter Bağlantı Sorunu Düzeltme Rehberi

## 🔍 Sorun
Android emülatörde `10.0.2.2` adresine bağlanamıyorsunuz.

## ✅ Çözüm Adımları

### 1. Backend'in Çalıştığından Emin Olun
```bash
# Backend'in çalıştığını kontrol edin
netstat -ano | findstr :3000
```

Eğer backend çalışmıyorsa:
```bash
cd C:\Users\dariy\OneDrive\Desktop\noje.jsproject
npm start
```

### 2. API URL'ini Düzeltin

`flutter_demo/lib/config/api_config.dart` dosyasında:

**Android Emülatör için:**
```dart
return 'http://10.0.2.2:3000/api';
```

**Fiziksel Cihaz için (Bilgisayarınızın IP'si):**
```dart
return 'http://192.168.1.105:3000/api';
```

**iOS Simülatör için:**
```dart
return 'http://localhost:3000/api';
```

### 3. Bağlantı Test Ekranını Kullanın

Flutter uygulamasında:
1. Login ekranında "Bağlantıyı Test Et" butonuna tıklayın
2. Farklı URL'leri test edin
3. Hangisi çalışıyorsa onu seçin

### 4. Backend CORS Ayarları

Backend zaten development modunda tüm origin'lere izin veriyor. Eğer hala sorun varsa:

`.env` dosyasına ekleyin:
```
CORS_ORIGIN=*
```

### 5. Firewall Kontrolü

Windows Firewall'un 3000 portunu engellemediğinden emin olun:

```powershell
# Firewall kuralı ekle (yönetici olarak)
netsh advfirewall firewall add rule name="Node.js Backend" dir=in action=allow protocol=TCP localport=3000
```

### 6. Android Emülatör Ağ Ayarları

Android emülatörde:
- Settings > Network & Internet > Wi-Fi
- Ağ bağlantısının aktif olduğundan emin olun

### 7. Alternatif: Fiziksel Cihaz Kullanın

Eğer emülatör çalışmıyorsa:
1. Bilgisayarınızın IP adresini öğrenin: `ipconfig`
2. Flutter uygulamasında IP adresini kullanın
3. Telefon ve bilgisayar aynı Wi-Fi ağında olmalı

## 🧪 Test

1. Backend'i başlatın: `npm start`
2. Flutter uygulamasını çalıştırın: `flutter run`
3. Login ekranında "Bağlantıyı Test Et" butonuna tıklayın
4. Farklı URL'leri test edin

## 📱 Platform'a Göre URL'ler

| Platform | URL |
|----------|-----|
| Android Emülatör | `http://10.0.2.2:3000/api` |
| iOS Simülatör | `http://localhost:3000/api` |
| Fiziksel Cihaz | `http://192.168.1.105:3000/api` (IP'nizi kullanın) |
| Web | `http://localhost:3000/api` |

## ⚠️ Yaygın Hatalar

1. **ERR_CONNECTION_TIMED_OUT**: Backend çalışmıyor veya yanlış URL
2. **ERR_CONNECTION_REFUSED**: Firewall engelliyor veya backend farklı portta
3. **CORS Error**: Backend CORS ayarları yanlış (development'ta otomatik çözülür)

## 💡 İpucu

En kolay yöntem: **Fiziksel cihaz kullanın**
- Bilgisayarınızın IP adresini kullanın
- Telefon ve bilgisayar aynı Wi-Fi'de olmalı
- Firewall'u kontrol edin

