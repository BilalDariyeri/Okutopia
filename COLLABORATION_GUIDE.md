# Ortak Geliştirme Rehberi

Bu rehber, 4 kişilik ekibin sorunsuz bir şekilde birlikte çalışması için hazırlanmıştır.

## 🚀 Hızlı Başlangıç

### İlk Kurulum

1. Repository'yi klonlayın:
```bash
git clone https://github.com/BilalDariyeri/Okutopia.git
cd Okutopia
```

2. Backend kurulumu:
```bash
cd noje.jsproject
npm install
cp env.example .env
# .env dosyasını düzenleyin
```

3. Frontend kurulumu:
```bash
cd ../flutterproject
flutter pub get
```

## 🔄 Günlük Çalışma Akışı

### Sabah Rutini

```bash
# 1. Main branch'e geçin
git checkout main

# 2. Son değişiklikleri çekin
git pull origin main

# 3. Yeni branch oluşturun
git checkout -b feature/your-feature-name
```

### Gün Sonu

```bash
# 1. Değişikliklerinizi commit edin
git add .
git commit -m "feat: özellik açıklaması"

# 2. Branch'inizi push edin
git push origin feature/your-feature-name

# 3. GitHub'da Pull Request oluşturun
```

## 🌿 Branch Stratejisi

### Ana Branch'ler

- **`main`**: Production-ready kod (sadece merge, direkt push yok)
- **`develop`**: Geliştirme branch'i (isteğe bağlı, şimdilik main kullanıyoruz)

### Feature Branch'ler

Her özellik için ayrı branch:
```bash
feature/kullanici-profil
feature/soru-ekleme
feature/istatistik-grafik
```

### Branch İsimlendirme

- `feature/` - Yeni özellikler
- `fix/` - Bug düzeltmeleri
- `refactor/` - Kod iyileştirmeleri
- `docs/` - Dokümantasyon
- `test/` - Test eklemeleri

## ⚠️ Çakışma (Conflict) Önleme

### 1. Sık Sık Pull Yapın

```bash
# Her gün başında ve önemli değişikliklerden önce
git checkout main
git pull origin main
```

### 2. Küçük PR'lar Yapın

- Büyük değişiklikleri küçük parçalara bölün
- Her PR tek bir özelliği hedeflesin
- 200-300 satırı geçmeyen PR'lar tercih edilir

### 3. Aynı Dosyada Çalışmayın

Eğer aynı dosyada çalışmanız gerekiyorsa:
1. Önce konuşun ve koordine olun
2. Farklı fonksiyonlara odaklanın
3. Birbirinizi bilgilendirin

### 4. Conflict Çözme

Eğer conflict oluşursa:

```bash
# 1. Main'i güncelleyin
git checkout main
git pull origin main

# 2. Branch'inize geri dönün
git checkout feature/your-branch

# 3. Main'i merge edin
git merge main

# 4. Conflict'leri çözün
# Dosyaları düzenleyin, <<<<<<< ve >>>>>>> işaretlerini kaldırın

# 5. Çözülen dosyaları ekleyin
git add .

# 6. Merge'i tamamlayın
git commit -m "merge: main branch ile birleştirildi"
```

## 📋 Görev Dağılımı

### Önerilen Yapı

1. **Backend Geliştirici**: API endpoint'leri, modeller, middleware
2. **Frontend Geliştirici**: Flutter ekranları, UI/UX
3. **Full-Stack Geliştirici**: Her iki tarafta da çalışabilir
4. **Test/Dokümantasyon**: Test yazma, dokümantasyon güncelleme

### Dosya Sahipliği

Her geliştirici belirli dosyalara odaklanabilir:
- `controllers/` - Backend iş mantığı
- `screens/` - Flutter UI
- `models/` - Veri modelleri
- `routes/` - API rotaları

## 🔍 Code Review Süreci

### Review Yaparken

1. **Kodun çalıştığından emin olun**
2. **Güvenlik açıkları kontrol edin**
3. **Performans sorunları arayın**
4. **Kod standartlarına uygunluğu kontrol edin**
5. **Yapıcı geri bildirim verin**

### Review Alırken

1. **Yorumları dikkatlice okuyun**
2. **Değişiklikleri yapın**
3. **"Resolve conversation" ile yorumları kapatın**
4. **Yeni commit'ler ekleyin (force push yapmayın)**

## 🚫 Yapılmaması Gerekenler

- ❌ `main` branch'e direkt push
- ❌ Başkasının branch'ine push
- ❌ Force push (mümkünse)
- ❌ Büyük dosyaları commit etme
- ❌ `.env` dosyasını commit etme
- ❌ Çalışmayan kodu commit etme
- ❌ Commit mesajı olmadan commit

## ✅ Best Practices

### Commit Mesajları

```bash
# ✅ İyi
feat: kullanıcı profil sayfası eklendi
fix: login hatası düzeltildi
docs: API dokümantasyonu güncellendi

# ❌ Kötü
update
fix
changes
```

### Kod Yazarken

- Küçük fonksiyonlar yazın
- Açıklayıcı değişken isimleri kullanın
- Gereksiz yorumlar eklemeyin
- Gerekli yerlerde yorum ekleyin
- Error handling yapın

### Test Etme

- Her değişiklikten sonra test edin
- Backend değişikliklerinde API'yi test edin
- Frontend değişikliklerinde UI'ı test edin
- Cross-platform test yapın (Android/iOS)

## 📞 İletişim

### Sorunlar İçin

1. Önce issue açın
2. Ekip üyelerini etiketleyin
3. Detaylı açıklama yapın

### Acil Durumlar

- Direkt iletişime geçin
- Hızlıca düzeltme yapın
- Sonra dokümante edin

## 🎯 Haftalık Toplantı

- Haftalık ilerleme paylaşımı
- Blocker'ları konuşma
- Sonraki hafta planlaması

## 📚 Faydalı Komutlar

```bash
# Hangi branch'te olduğunuzu görmek
git branch

# Tüm branch'leri görmek
git branch -a

# Son commit'leri görmek
git log --oneline -10

# Değişiklikleri görmek
git status

# Belirli bir dosyadaki değişiklikleri görmek
git diff path/to/file

# Remote branch'leri görmek
git branch -r

# Branch silmek (local)
git branch -d branch-name

# Branch silmek (remote)
git push origin --delete branch-name
```

## 🎉 Başarılı Ortak Geliştirme İçin

1. **İletişim**: Açık ve sık iletişim kurun
2. **Saygı**: Birbirinizin koduna saygı gösterin
3. **Esneklik**: Farklı yaklaşımlara açık olun
4. **Öğrenme**: Birbirinizden öğrenin
5. **Eğlence**: Eğlenerek kodlayın! 🚀

