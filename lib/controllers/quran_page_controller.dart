import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart';
import 'package:quran/quran_text_normal.dart';
import 'package:quran/quran_text.dart'; // Add this import
import 'package:string_validator/string_validator.dart';
import 'package:quranapp/models/sura.dart';
import 'package:quranapp/models/search_type.dart';
import 'dart:async'; // Add this import
import 'dart:isolate';
import 'dart:developer' as dev;

class QuranPageController extends GetxController {
  TextEditingController textEditingController = TextEditingController();
  var suraJsonData;
  var isLoading = true.obs;
  var searchQuery = "".obs;
  var filteredData;
  var ayatFiltered;
  var pageNumbers = <int>[].obs;
  var searchType = SearchType.all.obs;
  var verseSearchResults = <Map<String, dynamic>>[].obs;
  Timer? _debounce;
  var isSearching = false.obs;

  static const int pageSize = 20;
  var allVerseResults = <Map<String, dynamic>>[].obs;
  var currentPage = 0.obs;

  @override
  void onInit() {
    super.onInit();
    dev.log('Initializing QuranPageController');
    initializeData();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    textEditingController.dispose();
    super.onClose();
  }

  Future<List<dynamic>> loadJsonAsset() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/json/surahs.json',
      );
      final data = jsonDecode(jsonString);
      return data is List ? data : [];
    } catch (e) {
      print('Error loading JSON asset: $e');
      return [];
    }
  }

  void initializeWithData(dynamic data) {
    suraJsonData = data;
    filteredData = List.from(data);
    isLoading.value = false;
    update();
  }

  addFilteredData() async {
    try {
      isLoading.value = true;
      // Only load if not already initialized
      if (suraJsonData == null) {
        suraJsonData = await loadJsonAsset();
        filteredData = List.from(suraJsonData);
      }
    } catch (e) {
      dev.log('Error loading data: $e');
      filteredData = [];
    } finally {
      isLoading.value = false;
      update();
    }
  }

  void initializeData() async {
    await addFilteredData();
  }

  void clearSearch() {
    isSearching.value = false;
    textEditingController.clear();
    searchQuery.value = "";
    filteredData = suraJsonData;
    pageNumbers.clear();
    verseSearchResults.clear();
    currentPage.value = 0;
    allVerseResults.clear();
    update();
  }

  void setSearchType(SearchType type) {
    searchType.value = type;
    clearSearch();
  }

  void onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    isSearching.value = true; // Start loading immediately when typing

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      searchQuery.value = value;

      if (value.isEmpty) {
        clearSearch();
        isSearching.value = false;
        return;
      }

      try {
        switch (searchType.value) {
          case SearchType.page:
            if (isInt(value) && toInt(value) < 605 && toInt(value) > 0) {
              pageNumbers.clear();
              pageNumbers.add(toInt(value).toInt());
            }
            break;

          case SearchType.ayah:
            ayatFiltered = searchWords(value);
            break;

          case SearchType.surah:
            filteredData =
                suraJsonData.where((sura) {
                  final suraName = sura['englishName'].toLowerCase();
                  final suraNameTranslated = getSurahNameArabic(sura["number"]);
                  return suraName.contains(value.toLowerCase()) ||
                      suraNameTranslated.contains(value.toLowerCase());
                }).toList();
            break;

          case SearchType.juz:
            if (isInt(value) && toInt(value) <= 30 && toInt(value) > 0) {
              final juzData = getSurahAndVersesFromJuz(toInt(value).toInt());
              filteredData =
                  suraJsonData
                      .where((sura) => juzData.containsKey(sura['number']))
                      .toList();
            }
            break;

          case SearchType.all:
          default:
            if (isInt(value) && toInt(value) < 605 && toInt(value) > 0) {
              pageNumbers.clear();
              pageNumbers.add(toInt(value).toInt());
            }
            filteredData =
                suraJsonData.where((sura) {
                  final suraName = sura['englishName'].toLowerCase();
                  final suraNameTranslated = getSurahNameArabic(sura["number"]);
                  return suraName.contains(value.toLowerCase()) ||
                      suraNameTranslated.contains(value.toLowerCase());
                }).toList();

            // Search verses directly without length check
            searchWords(value);
        }
      } finally {
        isSearching.value = false;
        update();
      }
    });
  }

  void loadMoreResults() {
    final start = currentPage.value * pageSize;
    final end = start + pageSize;

    if (start < allVerseResults.length) {
      verseSearchResults.addAll(
        allVerseResults.sublist(
          start,
          end > allVerseResults.length ? allVerseResults.length : end,
        ),
      );
      currentPage.value++;
    }
  }

  Map<String, dynamic> searchWords(String query) {
    try {
      List<Map<String, dynamic>> result = [];

      if (query.length < 2) return {"result": [], "occurences": 0};

      // First find matches in normal text
      for (var verse in quran_text_normal) {
        if (verse['content'].toString().contains(query)) {
          // Get the corresponding verse from quranText with full diacritics
          var fullVerse = quranText.firstWhere(
            (v) =>
                v['surah_number'] == verse['surah_number'] &&
                v['verse_number'] == verse['verse_number'],
          );

          result.add({
            "surah": verse["surah_number"] as int,
            "verse": verse["verse_number"] as int,
            "text": fullVerse["content"] as String,
            "text_normal": verse["content"] as String,
          });
        }
      }

      allVerseResults.value = result;
      currentPage.value = 0;
      verseSearchResults.value = result.take(pageSize).toList();

      return {"result": result, "occurences": result.length};
    } catch (e) {
      print("Error searching words: $e");
      return {"result": [], "occurences": 0};
    }
  }
}
