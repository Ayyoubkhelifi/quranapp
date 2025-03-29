import 'package:quranapp/models/qari.dart';

class AudioFileFormat {
  final int size;
  final int bitRate;
  final double duration;
  final int nbStreams;
  final double startTime;
  final String formatName;
  final int nbPrograms;
  final int probeScore;
  final String formatLongName;

  AudioFileFormat({
    required this.size,
    required this.bitRate,
    required this.duration,
    required this.nbStreams,
    required this.startTime,
    required this.formatName,
    required this.nbPrograms,
    required this.probeScore,
    required this.formatLongName,
  });

  factory AudioFileFormat.fromJson(Map<String, dynamic> json) {
    return AudioFileFormat(
      size: json['size'] ?? 0,
      bitRate: json['bit_rate'] ?? 0,
      duration: _parseDouble(json['duration']),
      nbStreams: json['nb_streams'] ?? 0,
      startTime: _parseDouble(json['start_time']),
      formatName: json['format_name'] ?? '',
      nbPrograms: json['nb_programs'] ?? 0,
      probeScore: json['probe_score'] ?? 0,
      formatLongName: json['format_long_name'] ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }
}

class AudioFileMetadata {
  final String album;
  final String genre;
  final String title;
  final String track;
  final String artist;

  AudioFileMetadata({
    required this.album,
    required this.genre,
    required this.title,
    required this.track,
    required this.artist,
  });

  factory AudioFileMetadata.fromJson(Map<String, dynamic> json) {
    return AudioFileMetadata(
      album: json['album'] ?? '',
      genre: json['genre'] ?? '',
      title: json['title'] ?? '',
      track: json['track'] ?? '',
      artist: json['artist'] ?? '',
    );
  }
}

class AudioFile {
  final int qariId;
  final int surahId;
  final int mainId;
  final int recitationId;
  final String? filenum;
  final String fileName;
  final String extension;
  final int streamCount;
  final int downloadCount;
  final AudioFileFormat format;
  final AudioFileMetadata metadata;
  final Qari qari;

  AudioFile({
    required this.qariId,
    required this.surahId,
    required this.mainId,
    required this.recitationId,
    this.filenum,
    required this.fileName,
    required this.extension,
    required this.streamCount,
    required this.downloadCount,
    required this.format,
    required this.metadata,
    required this.qari,
  });

  factory AudioFile.fromJson(Map<String, dynamic> json) {
    try {
      return AudioFile(
        qariId: json['qari_id'] ?? 0,
        surahId: json['surah_id'] ?? 0,
        mainId: json['main_id'] ?? 0,
        recitationId: json['recitation_id'] ?? 0,
        filenum: json['filenum'],
        fileName: json['file_name'] ?? '',
        extension: json['extension'] ?? 'mp3',
        streamCount: json['stream_count'] ?? 0,
        downloadCount: json['download_count'] ?? 0,
        format:
            json['format'] != null
                ? AudioFileFormat.fromJson(json['format'])
                : AudioFileFormat.fromJson({}),
        metadata:
            json['metadata'] != null
                ? AudioFileMetadata.fromJson(json['metadata'])
                : AudioFileMetadata.fromJson({}),
        qari:
            json['qari'] != null
                ? Qari.fromJson(json['qari'])
                : Qari(
                  id: 0,
                  name: '',
                  relativePath: '',
                  fileFormats: 'mp3',
                  sectionId: 1,
                  home: false,
                ),
      );
    } catch (e) {
      print('Error parsing AudioFile: $e');
      rethrow;
    }
  }
}
