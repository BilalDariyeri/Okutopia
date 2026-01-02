# MongoDB Compass - Connection String Nasıl Bulunur?

## Yöntem 1: Yeni Bağlantı Oluştururken

1. MongoDB Compass'ı açın
2. Sol üst köşede **"New Connection"** butonuna tıklayın
3. Bağlantı ekranında iki seçenek görürsünüz:
   - **"Fill in connection fields individually"** (alanları tek tek doldur)
   - **Connection String** (direkt string ile bağlan)

4. Eğer "Fill in connection fields individually" kullanıyorsanız:
   - Host: localhost
   - Port: 27017
   - Authentication: gerekirse kullanıcı adı/şifre
   
5. Eğer Connection String kullanıyorsanız:
   - Input kutusunda connection string'i görürsünüz
   - Örnek: `mongodb://localhost:27017` veya `mongodb+srv://user:pass@cluster.mongodb.net`

## Yöntem 2: Mevcut Bağlantıdan

1. MongoDB Compass'ı açın
2. Sol tarafta zaten bağlı olduğunuz bir connection görüyorsanız:
   - Connection'ın üzerine tıklayın
   - Veya connection'a sağ tıklayın
   - Bağlantı ayarlarını görmek için "Edit" veya "Connection Details" seçeneğini bulun

## Yöntem 3: Connection History'den

1. Sol üst köşede **hamburger menü** (☰) ikonuna tıklayın
2. **"Connection History"** veya **"Saved Connections"** seçeneğine tıklayın
3. Kayıtlı bağlantılarınızı göreceksiniz
4. Her bir connection'ın yanında connection string'i görebilirsiniz

## Yöntem 4: Settings/Preferences'ten

1. MongoDB Compass'ta **Settings** (⚙️) veya **Preferences** menüsüne gidin
2. **Connections** veya **Saved Connections** bölümünü bulun
3. Kayıtlı connection'larınızı ve connection string'lerini görebilirsiniz

## Connection String Formatları

### Yerel MongoDB (Local):
```
mongodb://localhost:27017
```
veya veritabanı adıyla:
```
mongodb://localhost:27017/okutopia
```

### MongoDB Atlas (Cloud):
```
mongodb+srv://kullanici:sifre@cluster.mongodb.net/okutopia?retryWrites=true&w=majority
```

## Önemli Notlar

- Connection string genellikle şifre içerir, dikkatli olun
- MongoDB Atlas kullanıyorsanız, connection string'de `mongodb+srv://` ile başlar
- Yerel MongoDB kullanıyorsanız, `mongodb://` ile başlar
- Port numarası genellikle `27017` (varsayılan MongoDB portu)

