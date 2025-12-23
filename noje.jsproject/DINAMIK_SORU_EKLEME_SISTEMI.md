# Dinamik Soru Ekleme Sistemi Dokümantasyonu

## 📋 Genel Bakış

Bu sistem, farklı formatlardaki soruları eklemek için esnek ve ölçeklenebilir bir yapı sunar. Strategy Pattern kullanılarak her soru tipi için ayrı validasyon, normalizasyon ve form alanları tanımlanmıştır.

## 🎯 Desteklenen Soru Tipleri

### 1. **ONLY_TEXT** - Sadece Metin
- **Gerekli Alanlar:** Soru Metni
- **Opsiyonel Alanlar:** Açıklama, Doğru Cevap
- **Kullanım:** Basit metin soruları için

### 2. **AUDIO_TEXT** - Ses + Metin
- **Gerekli Alanlar:** Soru Metni, Ses Dosyası
- **Opsiyonel Alanlar:** Açıklama, Doğru Cevap
- **Kullanım:** Sesli sorular için

### 3. **IMAGE_TEXT** - Resim + Metin
- **Gerekli Alanlar:** Soru Metni, Resim Dosyası
- **Opsiyonel Alanlar:** Açıklama, Doğru Cevap
- **Kullanım:** Görsel sorular için

### 4. **AUDIO_IMAGE_TEXT** - Ses + Resim + Metin
- **Gerekli Alanlar:** Soru Metni, Resim Dosyası, Ses Dosyası
- **Opsiyonel Alanlar:** Açıklama, Doğru Cevap
- **Kullanım:** Çoklu medya soruları için

### 5. **DRAG_DROP** - Sürükle-Bırak
- **Gerekli Alanlar:** Soru Metni, İçerik Objesi (JSON)
- **Opsiyonel Alanlar:** Açıklama
- **Kullanım:** Etkileşimli sürükle-bırak etkinlikleri için

## 🏗️ Mimari Yapı

### Backend (Node.js)

#### 1. Strategy Pattern (`utils/questionStrategies.js`)
```javascript
// Her soru tipi için strategy
- BaseQuestionStrategy (Interface)
- OnlyTextStrategy
- AudioTextStrategy
- ImageTextStrategy
- AudioImageTextStrategy
- DragDropStrategy
- QuestionStrategyFactory (Factory Pattern)
```

#### 2. Controller Entegrasyonu (`controllers/adminController.js`)
- `createQuestion`: Strategy pattern kullanarak soru oluşturur
- `getQuestionTypes`: Mevcut soru tiplerini ve form alanlarını döndürür
- Otomatik validasyon ve normalizasyon

#### 3. Model (`models/miniQuestion.js`)
- Yeni soru formatları için enum genişletildi
- `questionFormat` alanı eklendi (opsiyonel, geriye uyumluluk için)

### Frontend (Admin Panel)

#### 1. Dinamik Form Builder
- Soru formatı seçildiğinde form alanları otomatik güncellenir
- Her soru tipi için farklı alanlar gösterilir
- Validasyon kuralları otomatik uygulanır

#### 2. JavaScript Fonksiyonları
- `handleQuestionFormatChange()`: Soru formatı değiştiğinde çağrılır
- `createQuestionField()`: Form alanı oluşturur
- `questionFormatStrategies`: Soru tipi mapping'i

### Flutter (Mobile App)

#### 1. BaseQuestion Interface (`models/base_question.dart`)
```dart
abstract class BaseQuestion {
  // Tüm soru tipleri için ortak interface
}

// Implementasyonlar:
- OnlyTextQuestion
- AudioTextQuestion
- ImageTextQuestion
- AudioImageTextQuestion
- DragDropQuestion
```

## 📝 Kullanım Örnekleri

### Admin Panelden Soru Ekleme

1. **Sadece Metin Sorusu:**
   - Format: `ONLY_TEXT`
   - Soru Metni: "Bu kelimede 'a' harfi var mı?"
   - Doğru Cevap: Evet/Hayır

2. **Sesli Soru:**
   - Format: `AUDIO_TEXT`
   - Soru Metni: "Sesi dinle ve cevapla"
   - Ses Dosyası: [Dosya seç]
   - Doğru Cevap: Evet/Hayır

3. **Görsel Soru:**
   - Format: `IMAGE_TEXT`
   - Soru Metni: "Resme bak ve cevapla"
   - Resim Dosyası: [Dosya seç]
   - Doğru Cevap: Evet/Hayır

4. **Sürükle-Bırak:**
   - Format: `DRAG_DROP`
   - Soru Metni: "Kelimeleri doğru sıraya koy"
   - İçerik Objesi (JSON):
     ```json
     {
       "items": ["kelime1", "kelime2"],
       "targets": ["hedef1", "hedef2"]
     }
     ```

## 🔧 Yeni Soru Tipi Ekleme

### Adım 1: Backend Strategy Oluştur

`utils/questionStrategies.js` dosyasına yeni strategy ekleyin:

```javascript
class YeniSoruStrategy extends BaseQuestionStrategy {
    getType() {
        return 'YENI_TIP';
    }
    
    getRequiredFields() {
        return ['questionText', 'yeniAlan'];
    }
    
    validate(questionData) {
        // Validasyon kuralları
    }
    
    normalize(questionData) {
        // Veri normalizasyonu
    }
    
    getFormFields() {
        // Form alanları tanımı
    }
}
```

### Adım 2: Factory'ye Ekle

```javascript
static strategies = {
    // ...
    'YENI_TIP': new YeniSoruStrategy(),
};
```

### Adım 3: Model Enum'ına Ekle

`models/miniQuestion.js`:
```javascript
questionType: {
    enum: [..., 'YENI_TIP'],
}
```

### Adım 4: Admin Panel'e Ekle

`admin/index.html`:
```javascript
const questionFormatStrategies = {
    'YENI_TIP': {
        fields: ['questionText', 'yeniAlan'],
        requiredFields: ['questionText', 'yeniAlan'],
        showImage: false,
        showAudio: false
    }
};
```

### Adım 5: Flutter Model Ekle

`models/base_question.dart`:
```dart
class YeniSoruQuestion implements BaseQuestion {
    // Implementasyon
}
```

## 🎨 Form Alanları

Her soru tipi için dinamik olarak şu alanlar oluşturulur:

- **questionText**: Textarea (zorunlu)
- **instruction**: Textarea (opsiyonel)
- **correctAnswer**: Select (opsiyonel)
- **imageFile**: Dosya seçici (bazı tiplerde zorunlu)
- **audioFile**: Dosya seçici (bazı tiplerde zorunlu)
- **contentObject**: JSON textarea (DRAG_DROP için)

## ✅ Validasyon

Her soru tipi kendi validasyon kurallarını uygular:

- **ONLY_TEXT**: Soru metni zorunlu
- **AUDIO_TEXT**: Soru metni + ses dosyası zorunlu
- **IMAGE_TEXT**: Soru metni + resim dosyası zorunlu
- **AUDIO_IMAGE_TEXT**: Soru metni + resim + ses zorunlu
- **DRAG_DROP**: Soru metni + içerik objesi zorunlu

## 🔄 Geriye Uyumluluk

Eski soru tipleri (Text, Audio, Image, Video, Drawing) hala desteklenmektedir:

- Eski tipler otomatik olarak yeni formatlara map edilir
- Mevcut sorular etkilenmez
- Yeni ve eski formatlar birlikte kullanılabilir

## 📚 API Endpoints

### Soru Tiplerini Getir
```
GET /api/admin/content/question-types
Authorization: Bearer {token}
```

Response:
```json
{
  "success": true,
  "data": {
    "types": ["ONLY_TEXT", "AUDIO_TEXT", ...],
    "formFields": {
      "ONLY_TEXT": [...],
      "AUDIO_TEXT": [...]
    }
  }
}
```

### Soru Oluştur
```
POST /api/admin/content/question
Authorization: Bearer {token}
Content-Type: application/json

{
  "activity": "activityId",
  "questionFormat": "AUDIO_TEXT",
  "data": {
    "questionText": "Soru metni",
    "instruction": "Açıklama"
  },
  "mediaFileId": "audioFileId"
}
```

## 🚀 Özellikler

✅ **Dinamik Form Alanları**: Soru tipine göre otomatik form oluşturma
✅ **Otomatik Validasyon**: Her tip için özel validasyon kuralları
✅ **Strategy Pattern**: Kolay genişletilebilir yapı
✅ **Geriye Uyumluluk**: Eski soru tipleri desteklenir
✅ **Type Safety**: Flutter tarafında tip güvenliği
✅ **Ölçeklenebilir**: Yeni soru tipleri kolayca eklenebilir

## 📖 Örnek Kullanım Senaryoları

### Senaryo 1: Basit Metin Sorusu
```javascript
{
  questionFormat: "ONLY_TEXT",
  data: {
    questionText: "Bu kelimede 'a' harfi var mı?",
    instruction: "Dikkatli bak"
  },
  correctAnswer: "Evet"
}
```

### Senaryo 2: Sesli Görsel Soru
```javascript
{
  questionFormat: "AUDIO_IMAGE_TEXT",
  data: {
    questionText: "Resme bak ve sesi dinle",
    instruction: "Önce sesi dinle"
  },
  mediaFiles: [
    { fileId: "imageId", mediaType: "Image", order: 0 },
    { fileId: "audioId", mediaType: "Audio", order: 1 }
  ]
}
```

### Senaryo 3: Sürükle-Bırak
```javascript
{
  questionFormat: "DRAG_DROP",
  data: {
    questionText: "Kelimeleri doğru sıraya koy",
    contentObject: {
      items: ["elma", "armut"],
      targets: ["meyve", "sebze"]
    }
  }
}
```

## 🔍 Debugging

Sorun yaşarsanız:

1. **Backend Konsolunu Kontrol Edin:**
   - Strategy seçimi log'ları
   - Validasyon hataları
   - Normalizasyon işlemleri

2. **Admin Panel Konsolunu Kontrol Edin:**
   - Form alanı oluşturma log'ları
   - API çağrıları
   - Hata mesajları

3. **Network Tab'ını Kontrol Edin:**
   - API request/response'ları
   - Status kodları
   - Error mesajları

## 📝 Notlar

- Yeni soru tipleri eklerken tüm katmanları (Backend, Admin Panel, Flutter) güncellemeyi unutmayın
- Validasyon kuralları hem frontend hem backend'de uygulanmalı
- Geriye uyumluluk için eski formatlar korunmuştur
- Strategy Pattern sayesinde kod tekrarı minimumdur

