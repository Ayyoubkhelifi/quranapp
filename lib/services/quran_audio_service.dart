import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:quranapp/models/qari.dart';
import 'package:quranapp/models/section.dart';
import 'package:quranapp/models/audio_file.dart';

class QuranAudioService {
  static const String baseUrl = 'https://quranicaudio.com/api';
  static const String downloadBaseUrl =
      'https://download.quranicaudio.com/quran/';

  // Helper to log and return formatted error messages
  String _formatError(String method, dynamic error) {
    final errorMsg = 'Error in $method: $error';
    developer.log(errorMsg, name: 'QuranAudioService');
    return errorMsg;
  }

  // Get all reciters
  Future<List<Qari>> getAllReciters() async {
    try {
      developer.log(
        'Fetching all reciters from $baseUrl/qaris',
        name: 'QuranAudioService',
      );
      final response = await http
          .get(Uri.parse('$baseUrl/qaris'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final List<dynamic> jsonData = jsonDecode(response.body);
          developer.log(
            'Successfully fetched ${jsonData.length} reciters',
            name: 'QuranAudioService',
          );

          final reciters =
              jsonData
                  .map((json) {
                    try {
                      return Qari.fromJson(json);
                    } catch (e) {
                      developer.log(
                        'Error parsing reciter: $e\nJSON: $json',
                        name: 'QuranAudioService',
                      );
                      // Skip invalid entries by returning null and filtering later
                      return null;
                    }
                  })
                  .whereType<Qari>()
                  .toList(); // Filter out null values

          return reciters;
        } catch (e) {
          throw _formatError('getAllReciters (parsing)', e);
        }
      } else {
        throw 'Failed to load reciters: HTTP ${response.statusCode}';
      }
    } catch (e) {
      throw _formatError('getAllReciters', e);
    }
  }

  // Get reciter by ID
  Future<Qari> getReciterById(int id) async {
    try {
      developer.log('Fetching reciter with ID $id', name: 'QuranAudioService');
      final response = await http
          .get(Uri.parse('$baseUrl/qaris/$id'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final dynamic jsonData = jsonDecode(response.body);
          return Qari.fromJson(jsonData);
        } catch (e) {
          throw _formatError('getReciterById (parsing)', e);
        }
      } else {
        throw 'Failed to load reciter: HTTP ${response.statusCode}';
      }
    } catch (e) {
      throw _formatError('getReciterById', e);
    }
  }

  // Get all sections
  Future<List<Section>> getAllSections() async {
    try {
      developer.log('Fetching all sections', name: 'QuranAudioService');
      final response = await http
          .get(Uri.parse('$baseUrl/sections'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final List<dynamic> jsonData = jsonDecode(response.body);
          developer.log(
            'Successfully fetched ${jsonData.length} sections',
            name: 'QuranAudioService',
          );

          final sections =
              jsonData
                  .map((json) {
                    try {
                      return Section.fromJson(json);
                    } catch (e) {
                      developer.log(
                        'Error parsing section: $e\nJSON: $json',
                        name: 'QuranAudioService',
                      );
                      return null;
                    }
                  })
                  .whereType<Section>()
                  .toList(); // Filter out null values

          return sections;
        } catch (e) {
          throw _formatError('getAllSections (parsing)', e);
        }
      } else {
        throw 'Failed to load sections: HTTP ${response.statusCode}';
      }
    } catch (e) {
      throw _formatError('getAllSections', e);
    }
  }

  // Get all audio files for a specific reciter
  Future<List<AudioFile>> getAudioFilesByReciterId(int reciterId) async {
    try {
      developer.log(
        'Fetching audio files for reciter ID $reciterId',
        name: 'QuranAudioService',
      );
      final response = await http
          .get(Uri.parse('$baseUrl/audio_files/$reciterId'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final List<dynamic> jsonData = jsonDecode(response.body);
          developer.log(
            'Successfully fetched ${jsonData.length} audio files for reciter $reciterId',
            name: 'QuranAudioService',
          );

          final audioFiles =
              jsonData
                  .map((json) {
                    try {
                      return AudioFile.fromJson(json);
                    } catch (e) {
                      developer.log(
                        'Error parsing audio file: $e\nJSON: $json',
                        name: 'QuranAudioService',
                      );
                      return null;
                    }
                  })
                  .whereType<AudioFile>()
                  .toList(); // Filter out null values

          return audioFiles;
        } catch (e) {
          throw _formatError('getAudioFilesByReciterId (parsing)', e);
        }
      } else {
        throw 'Failed to load audio files: HTTP ${response.statusCode}';
      }
    } catch (e) {
      throw _formatError('getAudioFilesByReciterId', e);
    }
  }

  // Get all audio files
  Future<List<AudioFile>> getAllAudioFiles() async {
    try {
      developer.log(
        'Fetching all audio files - this might be a large request',
        name: 'QuranAudioService',
      );
      final response = await http
          .get(Uri.parse('$baseUrl/audio_files'))
          .timeout(
            const Duration(seconds: 30),
          ); // Longer timeout for this large request

      if (response.statusCode == 200) {
        try {
          final List<dynamic> jsonData = jsonDecode(response.body);
          developer.log(
            'Successfully fetched ${jsonData.length} audio files',
            name: 'QuranAudioService',
          );

          final audioFiles =
              jsonData
                  .map((json) {
                    try {
                      return AudioFile.fromJson(json);
                    } catch (e) {
                      developer.log(
                        'Error parsing audio file: $e\nJSON: $json',
                        name: 'QuranAudioService',
                      );
                      return null;
                    }
                  })
                  .whereType<AudioFile>()
                  .toList(); // Filter out null values

          return audioFiles;
        } catch (e) {
          throw _formatError('getAllAudioFiles (parsing)', e);
        }
      } else {
        throw 'Failed to load audio files: HTTP ${response.statusCode}';
      }
    } catch (e) {
      throw _formatError('getAllAudioFiles', e);
    }
  }

  // Get MP3 download URL for a specific surah from a reciter
  String getMp3Url(String relativePath, int surahNumber) {
    final paddedSurahNumber = surahNumber.toString().padLeft(3, '0');
    return '$downloadBaseUrl$relativePath$paddedSurahNumber.mp3';
  }

  // Helper method to create HTTP client with proper headers
  http.Client createClient() {
    return http.Client();
  }

  // Helper method to check if a URL exists/is valid
  Future<bool> checkUrlExists(String url) async {
    try {
      developer.log('Checking if URL exists: $url', name: 'QuranAudioService');
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      final exists = response.statusCode >= 200 && response.statusCode < 300;
      developer.log(
        'URL $url exists: $exists (status: ${response.statusCode})',
        name: 'QuranAudioService',
      );
      return exists;
    } catch (e) {
      developer.log('Error checking URL $url: $e', name: 'QuranAudioService');
      return false;
    }
  }
}
