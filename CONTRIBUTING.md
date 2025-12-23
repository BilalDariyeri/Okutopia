# Katkıda Bulunma Rehberi

Okutopia projesine katkıda bulunmak istediğiniz için teşekkürler! Bu rehber, projeye nasıl katkıda bulunabileceğinizi açıklar.

## 📋 İçindekiler

- [Kodlama Standartları](#kodlama-standartları)
- [Git Workflow](#git-workflow)
- [Branch Stratejisi](#branch-stratejisi)
- [Commit Mesajları](#commit-mesajları)
- [Pull Request Süreci](#pull-request-süreci)
- [Kod İnceleme](#kod-inceleme)

## 💻 Kodlama Standartları

### Genel Kurallar

1. **Kod Formatı**: `.editorconfig` dosyasındaki ayarlara uyun
2. **Dil**: Kod yorumları ve commit mesajları Türkçe olabilir, ancak değişken ve fonksiyon isimleri İngilizce olmalıdır
3. **Indentation**: 2 boşluk (spaces) kullanın, tab kullanmayın
4. **Satır Uzunluğu**: Mümkün olduğunca 100 karakteri geçmeyin

### JavaScript/Node.js

- **ES6+** özelliklerini kullanın
- **Async/await** tercih edin, callback kullanmayın
- **Error handling** her zaman yapın
- **Console.log** yerine **logger** kullanın

```javascript
// ✅ İyi
try {
    const result = await someAsyncFunction();
    logger.info('İşlem başarılı', { result });
} catch (error) {
    logger.error('İşlem başarısız', { error: error.message });
    throw error;
}

// ❌ Kötü
someAsyncFunction().then(result => {
    console.log(result);
}).catch(err => {
    console.error(err);
});
```

### Dart/Flutter

- **Null safety** kullanın
- **const** constructor'ları tercih edin
- **Widget**'ları küçük parçalara bölün
- **setState** yerine **Provider** kullanın

```dart
// ✅ İyi
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Text('Hello');
  }
}

// ❌ Kötü
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}
```

## 🌿 Git Workflow

### 1. Repository'yi Güncelleyin

```bash
git checkout main
git pull origin main
```

### 2. Yeni Branch Oluşturun

```bash
git checkout -b feature/your-feature-name
# veya
git checkout -b fix/bug-description
# veya
git checkout -b refactor/component-name
```

### Branch İsimlendirme

- `feature/` - Yeni özellikler için
- `fix/` - Bug düzeltmeleri için
- `refactor/` - Kod iyileştirmeleri için
- `docs/` - Dokümantasyon için
- `test/` - Test eklemeleri için
- `style/` - Formatting değişiklikleri için

### 3. Değişikliklerinizi Yapın

- Küçük, odaklanmış commit'ler yapın
- Her commit bir mantıksal değişikliği temsil etmeli
- Test edin ve çalıştığından emin olun

### 4. Değişikliklerinizi Commit Edin

```bash
git add .
git commit -m "feat: yeni özellik açıklaması"
```

### 5. Branch'inizi Push Edin

```bash
git push origin feature/your-feature-name
```

## 📝 Commit Mesajları

### Format

```
<type>: <subject>

<body>

<footer>
```

### Type'lar

- `feat`: Yeni özellik
- `fix`: Bug düzeltmesi
- `docs`: Dokümantasyon
- `style`: Formatting (kod değişikliği yok)
- `refactor`: Kod iyileştirmesi
- `test`: Test ekleme/düzeltme
- `chore`: Build, config değişiklikleri

### Örnekler

```bash
# ✅ İyi
feat: kullanıcı profil sayfası eklendi
fix: login hatası düzeltildi
docs: API dokümantasyonu güncellendi

# ❌ Kötü
update
fix bug
changes
```

## 🔄 Pull Request Süreci

### 1. PR Oluşturma

1. GitHub'da yeni bir Pull Request oluşturun
2. Açıklayıcı bir başlık yazın
3. Değişiklikleri detaylıca açıklayın
4. İlgili issue'ları referans edin (`Closes #123`)

### 2. PR Şablonu

```markdown
## Açıklama
Bu PR ne yapıyor?

## Değişiklik Türü
- [ ] Yeni özellik
- [ ] Bug düzeltmesi
- [ ] Kod iyileştirmesi
- [ ] Dokümantasyon

## Test Edildi mi?
- [ ] Evet, test edildi
- [ ] Test gerekmiyor

## Ekran Görüntüleri (varsa)
[Görüntüleri buraya ekleyin]

## Checklist
- [ ] Kod standartlarına uygun
- [ ] Testler geçiyor
- [ ] Dokümantasyon güncellendi
- [ ] .env.example güncellendi (varsa)
```

### 3. Code Review

- En az 1 kişinin onayı gerekir
- Review'da yapılan değişiklikleri düzeltin
- Tüm yorumlar çözülene kadar PR merge edilmez

## 🔍 Kod İnceleme Kriterleri

### Kontrol Edilecekler

1. **Fonksiyonellik**: Kod doğru çalışıyor mu?
2. **Performans**: Gereksiz işlemler var mı?
3. **Güvenlik**: Güvenlik açıkları var mı?
4. **Okunabilirlik**: Kod anlaşılır mı?
5. **Test**: Testler yazılmış mı?
6. **Dokümantasyon**: Gerekli yorumlar var mı?

### Review Yorumları

- **LGTM** (Looks Good To Me) - Onaylandı
- **Request Changes** - Değişiklik gerekli
- **Comment** - Bilgilendirme amaçlı yorum

## ⚠️ Dikkat Edilmesi Gerekenler

### Yapılmaması Gerekenler

- ❌ `main` branch'e direkt push yapmayın
- ❌ Başkasının üzerinde çalıştığı dosyaları değiştirmeyin
- ❌ Büyük dosyaları commit etmeyin
- ❌ `.env` dosyasını commit etmeyin
- ❌ `node_modules` klasörünü commit etmeyin
- ❌ Çalışmayan kodu commit etmeyin

### Yapılması Gerekenler

- ✅ Her zaman `main`'den branch oluşturun
- ✅ Küçük, odaklanmış PR'lar yapın
- ✅ Test edin ve çalıştığından emin olun
- ✅ Kod standartlarına uyun
- ✅ Açıklayıcı commit mesajları yazın

## 🐛 Bug Bildirimi

1. Issue oluşturun
2. Bug'ı detaylıca açıklayın
3. Adımları listeleyin (reproduce etmek için)
4. Beklenen ve gerçek davranışı belirtin
5. Ekran görüntüleri ekleyin (varsa)

## 💡 Özellik Önerisi

1. Issue oluşturun
2. Özelliği detaylıca açıklayın
3. Neden gerekli olduğunu belirtin
4. Kullanım senaryolarını örnekleyin

## 📞 İletişim

Sorularınız için:
- Issue açabilirsiniz
- Doğrudan iletişime geçebilirsiniz

Teşekkürler! 🎉

