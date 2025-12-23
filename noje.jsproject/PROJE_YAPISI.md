# Proje Yapısı

Bu workspace'te hem backend (Node.js) hem de frontend (Flutter) projeleri bulunmaktadır.

## 📁 Klasör Yapısı

```
noje.jsproject/          # Backend (Node.js/Express)
├── admin/               # Admin panel (HTML)
├── config/              # Backend config
├── controllers/         # Backend controllers
├── models/              # Backend models
├── routes/              # Backend routes
├── middleware/          # Backend middleware
├── utils/               # Backend utilities
├── scripts/              # Backend scripts
├── logs/                # Backend logs
├── node_modules/        # Backend dependencies
├── package.json         # Backend package.json
└── app.js               # Backend entry point

flutter_demo/            # Frontend (Flutter) - AYRI KLASÖR
├── lib/                 # Flutter source code
│   ├── config/          # API configuration
│   ├── models/          # Data models
│   ├── providers/       # State management
│   ├── screens/         # UI screens
│   ├── services/        # API services
│   └── main.dart        # Flutter entry point
├── android/             # Android platform files
├── ios/                 # iOS platform files
├── pubspec.yaml         # Flutter dependencies
└── README.md            # Flutter documentation
```

## 🎯 Çalışma Mantığı

### Backend (Node.js)
- Port: 3000
- API Base URL: `http://localhost:3000/api`
- Çalıştırma: `npm start`

### Frontend (Flutter)
- Backend'e bağlanır
- API Base URL: `http://10.0.2.2:3000/api` (Android emülatör)
- Çalıştırma: `flutter run`

## 📝 Notlar

- Her iki proje de ayrı klasörlerde
- Backend ve frontend birbirinden bağımsız
- API üzerinden iletişim kurarlar
- .gitignore her iki proje için ayrı ayrı yapılandırılmıştır

