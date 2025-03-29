class ReciterModel {
  final int id;
  final String name;
  final String englishName;
  final String? arabicName;
  final String relativePath;
  final String style;
  final bool home;

  ReciterModel({
    required this.id,
    required this.name,
    required this.englishName,
    this.arabicName,
    required this.relativePath,
    required this.style,
    this.home = false,
  });

  factory ReciterModel.fromJson(Map<String, dynamic> json) {
    return ReciterModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      englishName: json['english_name'] ?? json['name'] ?? '',
      arabicName: json['arabic_name'],
      relativePath: json['relative_path'] ?? '',
      style: json['style'] ?? 'Murattal',
      home: json['home'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'english_name': englishName,
      'arabic_name': arabicName,
      'relative_path': relativePath,
      'style': style,
      'home': home,
    };
  }
}
