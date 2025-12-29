# 🔄 Student Selection Migration Guide

## ✅ Tamamlanan İşlemler

### 1. Yeni Provider Oluşturuldu
- ✅ `lib/providers/student_selection_provider.dart` oluşturuldu
- ✅ `StudentSelectionProvider` sınıfı `ChangeNotifier` ile implement edildi
- ✅ Öğrenci seçimi mantığı AuthProvider'dan ayrıldı

### 2. AuthProvider'dan Taşınan Kodlar
- ✅ `_selectedStudent` field'ı kaldırıldı
- ✅ `selectedStudent` getter'ı kaldırıldı
- ✅ `setSelectedStudent(Student student)` metodu kaldırıldı
- ✅ `clearSelectedStudent()` metodu kaldırıldı
- ✅ `_loadUserFromStorage()` içindeki öğrenci yükleme kodu kaldırıldı
- ✅ `_clearStoredUserData()` içindeki öğrenci temizleme kodu kaldırıldı
- ✅ `logout()` içindeki öğrenci temizleme kodu kaldırıldı

### 3. main.dart Güncellemesi
- ✅ `StudentSelectionProvider` `MultiProvider` listesine eklendi
- ✅ SharedPreferences instance'ı StudentSelectionProvider'a geçirildi

### 4. UI Güncellemeleri
- ✅ `student_selection_screen.dart`: `setSelectedStudent` çağrısı güncellendi
- ✅ `teacher_profile_screen.dart`: Logout'ta `StudentSelectionProvider.clearAll()` eklendi
- ✅ `student_selection_screen.dart`: Logout'ta `StudentSelectionProvider.clearAll()` eklendi

---

## 📋 Yapılması Gereken UI Güncellemeleri

Aşağıdaki dosyalarda `authProvider.selectedStudent` kullanımları `studentSelectionProvider.selectedStudent` olarak değiştirilmelidir:

### 1. `lib/screens/categories_screen.dart`
**Değiştirilecek yerler:**
```dart
// ❌ ESKİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final selectedStudent = authProvider.selectedStudent;

// ✅ YENİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
final selectedStudent = studentSelectionProvider.selectedStudent;
```

**Satırlar:** 97, 133, 202

### 2. `lib/screens/statistics_screen.dart`
**Değiştirilecek yerler:**
```dart
// ❌ ESKİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final selectedStudent = authProvider.selectedStudent;

// ✅ YENİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
final selectedStudent = studentSelectionProvider.selectedStudent;
```

**Satırlar:** 50, 98, 244, 264

### 3. `lib/screens/letter_visual_finding_screen.dart`
**Değiştirilecek yerler:**
```dart
// ❌ ESKİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final selectedStudent = authProvider.selectedStudent;

// ✅ YENİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
final selectedStudent = studentSelectionProvider.selectedStudent;
```

**Satır:** 497

### 4. `lib/screens/letter_find_screen.dart`
**Değiştirilecek yerler:**
```dart
// ❌ ESKİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final selectedStudent = authProvider.selectedStudent;

// ✅ YENİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
final selectedStudent = studentSelectionProvider.selectedStudent;
```

**Satırlar:** 85, 100

### 5. `lib/screens/question_detail_screen.dart`
**Değiştirilecek yerler:**
```dart
// ❌ ESKİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final selectedStudent = authProvider.selectedStudent;

// ✅ YENİ:
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
final selectedStudent = studentSelectionProvider.selectedStudent;
```

**Satır:** 69

---

## 🔧 Import Eklenmesi Gereken Dosyalar

Aşağıdaki dosyalara `import '../providers/student_selection_provider.dart';` eklenmelidir:

1. `lib/screens/categories_screen.dart`
2. `lib/screens/statistics_screen.dart`
3. `lib/screens/letter_visual_finding_screen.dart`
4. `lib/screens/letter_find_screen.dart`
5. `lib/screens/question_detail_screen.dart`

---

## ⚠️ Önemli Notlar

1. **Logout İşlemleri:** Logout yapılan her yerde `StudentSelectionProvider.clearAll()` çağrılmalı:
   ```dart
   await authProvider.logout();
   final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
   await studentSelectionProvider.clearAll();
   ```

2. **Öğrenci Seçimi:** Öğrenci seçildiğinde:
   ```dart
   final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
   studentSelectionProvider.setSelectedStudent(student);
   ```

3. **Öğrenci Temizleme:** Öğrenci seçimi temizlenirken:
   ```dart
   final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
   studentSelectionProvider.clearSelectedStudent();
   ```

---

## ✅ Test Edilmesi Gerekenler

1. ✅ Öğrenci seçimi çalışıyor mu?
2. ✅ Seçili öğrenci SharedPreferences'a kaydediliyor mu?
3. ✅ Uygulama yeniden açıldığında seçili öğrenci yükleniyor mu?
4. ✅ Logout yapıldığında öğrenci seçimi temizleniyor mu?
5. ✅ Tüm ekranlarda `selectedStudent` doğru çalışıyor mu?

---

## 📝 Sonraki Adımlar

1. Yukarıdaki UI güncellemelerini yap
2. Tüm ekranları test et
3. Linter hatalarını kontrol et
4. Uygulamayı çalıştır ve test et

