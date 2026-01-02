/// Metin yerleşim tipi enum
enum ReadingTextLayoutType {
  diamond,   // Baklava deseni: Satırlar uzayıp sonra kısalacak
  pyramid,   // Piramit: Satırlar sürekli uzayacak, ortalı
  standard,  // Düz metin: Soldan hizalı
}

/// Okuma metni modeli - Kademeli okuma için
class ReadingText {
  final String id;
  final String title;
  final String description; // Açıklama metni
  final List<String> lines; // Metin satırları
  final int textNumber; // Metin numarası (1, 2, 3, ...)
  final ReadingTextLayoutType layoutType; // Metin yerleşim tipi

  ReadingText({
    required this.id,
    required this.title,
    required this.lines,
    required this.textNumber,
    this.description = '',
    this.layoutType = ReadingTextLayoutType.pyramid,
  });

  /// JSON'dan model oluştur
  factory ReadingText.fromJson(Map<String, dynamic> json) {
    // layoutType string'den enum'a çevir
    ReadingTextLayoutType layout = ReadingTextLayoutType.pyramid;
    final layoutStr = json['layoutType']?.toString().toLowerCase() ?? 'pyramid';
    if (layoutStr == 'diamond') {
      layout = ReadingTextLayoutType.diamond;
    } else if (layoutStr == 'standard') {
      layout = ReadingTextLayoutType.standard;
    } else {
      layout = ReadingTextLayoutType.pyramid;
    }

    return ReadingText(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      lines: json['lines'] != null
          ? (json['lines'] as List).map((e) => e.toString()).toList()
          : [],
      textNumber: json['textNumber'] ?? 0,
      layoutType: layout,
    );
  }

  /// Model'den JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'lines': lines,
      'textNumber': textNumber,
      'layoutType': layoutType.name,
    };
  }

  /// Örnek veri oluştur
  factory ReadingText.example(int number) {
    final examples = [
      ReadingText(
        id: '1',
        title: 'Kırmızı Top',
        description: 'Kırmızı Top\'un hikayesi - Piramit deseni',
        lines: [
          'Oynadı.',
          'Mert oynadı.',
          'Mert parkta oynadı.',
          'Mert parkta kırmızı topla oynadı.',
          'Mert arkadaşlarıyla parkta kırmızı topla oynadı.',
        ],
        textNumber: 1,
        layoutType: ReadingTextLayoutType.pyramid,
      ),
      ReadingText(
        id: '2',
        title: 'Kitap ve Ece',
        description: 'Kitap ve Ece\'nin hikayesi - Baklava deseni',
        lines: [
          'Sundu.',
          'Ece sundu.',
          'Ece arkadaşına sundu.',
          'Ece arkadaşına kitabı sundu.',
          'Ece arkadaşına kitabı nazikçe sundu.',
        ],
        textNumber: 2,
        layoutType: ReadingTextLayoutType.diamond,
      ),
      ReadingText(
        id: '3',
        title: 'Kelebek',
        description: 'Kelebek\'in hikayesi - Baklava deseni',
        lines: [
          'Uçtu.',
          'Kelebek uçtu.',
          'Kelebek bahçede uçtu.',
          'Kelebek bahçede çiçeklerin üzerinde uçtu.',
          'Kelebek bahçede çiçeklerin üzerinde güzelce uçtu.',
        ],
        textNumber: 3,
        layoutType: ReadingTextLayoutType.diamond,
      ),
      ReadingText(
        id: '4',
        title: 'Masal',
        description: 'Masal hikayesi - Düz metin',
        lines: [
          'Bir varmış bir yokmuş.',
          'Evvel zaman içinde kalbur saman içinde.',
          'Develer tellal iken pireler berber iken.',
          'Ben anamın beşiğini tıngır mıngır sallar iken.',
        ],
        textNumber: 4,
        layoutType: ReadingTextLayoutType.standard,
      ),
    ];

    if (number > 0 && number <= examples.length) {
      return examples[number - 1].copyWith(textNumber: number);
    }

    return examples[0].copyWith(textNumber: number);
  }

  /// Tüm örnek metinleri getir (seçim ekranı için)
  static List<ReadingText> getAllExamples() {
    final examples = [
      ReadingText(
        id: '1',
        title: 'Kırmızı Top',
        description: 'Kırmızı Top\'un hikayesi - Piramit deseni',
        lines: [
          'Oynadı.',
          'Mert oynadı.',
          'Mert parkta oynadı.',
          'Mert parkta kırmızı topla oynadı.',
          'Mert arkadaşlarıyla parkta kırmızı topla oynadı.',
        ],
        textNumber: 1,
        layoutType: ReadingTextLayoutType.pyramid,
      ),
      ReadingText(
        id: '2',
        title: 'Kitap ve Ece',
        description: 'Kitap ve Ece\'nin hikayesi - Baklava deseni',
        lines: [
          'Sundu.',
          'Ece sundu.',
          'Ece arkadaşına sundu.',
          'Ece arkadaşına kitabı sundu.',
          'Ece arkadaşına kitabı nazikçe sundu.',
        ],
        textNumber: 2,
        layoutType: ReadingTextLayoutType.diamond,
      ),
      ReadingText(
        id: '3',
        title: 'Kelebek',
        description: 'Kelebek\'in hikayesi - Baklava deseni',
        lines: [
          'Uçtu.',
          'Kelebek uçtu.',
          'Kelebek bahçede uçtu.',
          'Kelebek bahçede çiçeklerin üzerinde uçtu.',
          'Kelebek bahçede çiçeklerin üzerinde güzelce uçtu.',
        ],
        textNumber: 3,
        layoutType: ReadingTextLayoutType.diamond,
      ),
      ReadingText(
        id: '4',
        title: 'Masal',
        description: 'Masal hikayesi - Düz metin',
        lines: [
          'Bir varmış bir yokmuş.',
          'Evvel zaman içinde kalbur saman içinde.',
          'Develer tellal iken pireler berber iken.',
          'Ben anamın beşiğini tıngır mıngır sallar iken.',
        ],
        textNumber: 4,
        layoutType: ReadingTextLayoutType.standard,
      ),
    ];

    // 34 metin oluştur (eksik olanlar için varsayılan veri)
    return List.generate(34, (index) {
      final textNumber = index + 1;
      if (textNumber <= examples.length) {
        return examples[textNumber - 1];
      }
      // Eksik metinler için varsayılan veri (layoutType döngüsel olarak değişir)
      final layoutTypes = [
        ReadingTextLayoutType.pyramid,
        ReadingTextLayoutType.diamond,
        ReadingTextLayoutType.standard,
      ];
      return ReadingText(
        id: textNumber.toString(),
        title: 'Metin $textNumber',
        description: 'Okuma metni $textNumber - ${layoutTypes[textNumber % 3].name} deseni',
        lines: [
          'Cümle 1.',
          'Cümle 1 ve 2.',
          'Cümle 1, 2 ve 3.',
          'Cümle 1, 2, 3 ve 4.',
          'Cümle 1, 2, 3, 4 ve 5.',
        ],
        textNumber: textNumber,
        layoutType: layoutTypes[textNumber % 3],
      );
    });
  }

  /// Kopya oluştur (immutability için)
  ReadingText copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? lines,
    int? textNumber,
    ReadingTextLayoutType? layoutType,
  }) {
    return ReadingText(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      lines: lines ?? this.lines,
      textNumber: textNumber ?? this.textNumber,
      layoutType: layoutType ?? this.layoutType,
    );
  }
}

