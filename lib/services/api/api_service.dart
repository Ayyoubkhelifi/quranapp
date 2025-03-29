import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:quranapp/constants/constants.dart';
import 'package:quranapp/models/audio_model.dart';
import 'package:quranapp/models/surah_model.dart';

class ApiService {
  final String baseUrl = Constants.baseUrl;

  // Get list of reciters
  Future<List<ReciterModel>> getReciters() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl${Constants.reciterListEndpoint}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ReciterModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load reciters: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting reciters: $e');
      return [];
    }
  }

  // Get list of surahs
  Future<List<SurahModel>> getSurahs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl${Constants.surahListEndpoint}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        return data.map((json) => SurahModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load surahs: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting surahs: $e');
      return [];
    }
  }

  // Get audio URL for a specific reciter and surah
  String getAudioUrl(int reciterId, int surahId) {
    return '$baseUrl${Constants.audioFilesBaseUrl}/$reciterId/$surahId';
  }
}
