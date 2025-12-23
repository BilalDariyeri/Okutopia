# 📚 Okuma Metni Yükleme Sistemi

## 🎯 Amaç

HTML dosyalarındaki okuma metinlerini sisteme yüklemek için bir kolaylık sağlar. **HTML dosyaları mobil uygulamada tutulmaz!**

## ✅ Nasıl Çalışır?

1. **HTML Parse**: HTML dosyasından başlık ve metin satırları çıkarılır
2. **Veritabanına Kayıt**: Veriler Activity modeline `textLines` array'i olarak kaydedilir
3. **Mobil Uygulama**: Flutter uygulaması sadece `textLines` array'ini kullanır, HTML kullanmaz

## 📊 Veri Yapısı

### HTML'den Çıkarılan:
```html
<h2 class="text-title">Kırmızı Top</h2>
<div class="centered-line">Oynadı.</div>
<div class="centered-line">Mert oynadı.</div>
```

### Veritabanına Kaydedilen:
```json
{
  "title": "Kırmızı Top",
  "activityType": "Text",
  "textLines": [
    "Oynadı.",
    "Mert oynadı.",
    "Mert parkta oynadı."
  ],
  "readingDuration": 30
}
```

### Flutter'da Kullanım:
```dart
// Activity modelinden textLines array'i alınır
if (activity.isReadingText) {
  for (String line in activity.textLines!) {
    // Her satırı göster
    Text(line)
  }
}
```

## 🚀 Kullanım

```bash
# Tek dosya
node scripts/importReadingText.js "path/to/reading-text-7.html" "LESSON_ID"

# Çoklu dosya
node scripts/importReadingText.js "path/to/folder" "LESSON_ID" --batch
```

## ⚠️ Önemli Notlar

- ✅ HTML sadece import için kullanılır
- ✅ Mobil uygulamada HTML tutulmaz
- ✅ Veriler `textLines` array'i olarak saklanır
- ✅ Flutter uygulaması sadece JSON verisini kullanır
