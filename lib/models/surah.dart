class Surah {
  final int id;
  final List<int> page;
  final bool bismillahPre;
  final int ayat;
  final SurahName name;
  final Revelation revelation;

  Surah({
    required this.id,
    required this.page,
    required this.bismillahPre,
    required this.ayat,
    required this.name,
    required this.revelation,
  });

  // Create a Surah object from JSON
  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      id: json['id'] ?? 0,
      page: (json['page'] as List?)?.map((p) => p as int).toList() ?? [0, 0],
      bismillahPre: json['bismillah_pre'] == true,
      ayat: json['ayat'] ?? 0,
      name: SurahName.fromJson(json['name'] ?? {}),
      revelation: Revelation.fromJson(json['revelation'] ?? {}),
    );
  }

  // Convert Surah object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'page': page,
      'bismillah_pre': bismillahPre,
      'ayat': ayat,
      'name': name.toJson(),
      'revelation': revelation.toJson(),
    };
  }
}

class SurahName {
  final String complex;
  final String simple;
  final String english;
  final String arabic;

  SurahName({
    required this.complex,
    required this.simple,
    required this.english,
    required this.arabic,
  });

  // Create a SurahName object from JSON
  factory SurahName.fromJson(Map<String, dynamic> json) {
    return SurahName(
      complex: json['complex'] ?? '',
      simple: json['simple'] ?? '',
      english: json['english'] ?? '',
      arabic: json['arabic'] ?? '',
    );
  }

  // Convert SurahName object to JSON
  Map<String, dynamic> toJson() {
    return {
      'complex': complex,
      'simple': simple,
      'english': english,
      'arabic': arabic,
    };
  }
}

class Revelation {
  final String place;
  final int order;

  Revelation({required this.place, required this.order});

  // Create a Revelation object from JSON
  factory Revelation.fromJson(Map<String, dynamic> json) {
    return Revelation(place: json['place'] ?? '', order: json['order'] ?? 0);
  }

  // Convert Revelation object to JSON
  Map<String, dynamic> toJson() {
    return {'place': place, 'order': order};
  }
}
