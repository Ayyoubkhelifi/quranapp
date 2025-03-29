class Section {
  final int id;
  final String name;

  Section({required this.id, required this.name});

  // Create a Section object from JSON
  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Section',
    );
  }

  // Convert Section object to JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
