import 'package:get/get.dart';

class Qari {
  final int id;
  final String name;
  final String? arabicName;
  final String relativePath;
  final String fileFormats;
  final int sectionId;
  final bool home;
  final String? description;
  final String? torrentFilename;
  final String? torrentInfoHash;
  final int? torrentSeeders;
  final int? torrentLeechers;

  Qari({
    required this.id,
    required this.name,
    this.arabicName,
    required this.relativePath,
    required this.fileFormats,
    required this.sectionId,
    required this.home,
    this.description,
    this.torrentFilename,
    this.torrentInfoHash,
    this.torrentSeeders,
    this.torrentLeechers,
  });

  factory Qari.fromJson(Map<String, dynamic> json) {
    return Qari(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      arabicName: json['arabic_name'],
      relativePath: json['relative_path'] ?? '',
      fileFormats: json['file_formats'] ?? 'mp3',
      sectionId: json['section_id'] ?? 0,
      home: json['home'] == true,
      description: json['description'],
      torrentFilename: json['torrent_filename'],
      torrentInfoHash: json['torrent_info_hash'],
      torrentSeeders: json['torrent_seeders'],
      torrentLeechers: json['torrent_leechers'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'arabic_name': arabicName,
      'relative_path': relativePath,
      'file_formats': fileFormats,
      'section_id': sectionId,
      'home': home,
      'description': description,
      'torrent_filename': torrentFilename,
      'torrent_info_hash': torrentInfoHash,
      'torrent_seeders': torrentSeeders,
      'torrent_leechers': torrentLeechers,
    };
  }

  // Get a consistent file identifier for this reciter
  String getFileIdentifier() {
    // Clean up relativePath for consistent use in filenames
    String identifier = relativePath;

    // Remove trailing slash if present
    if (identifier.endsWith('/')) {
      identifier = identifier.substring(0, identifier.length - 1);
    }

    return identifier;
  }

  // Override equals and hashCode for proper comparison in DropdownButton
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Qari && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
