import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quranapp/widgets/basmallah.dart';
import 'package:quranapp/widgets/header_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranViewController extends GetxController {
  final int initialPageNumber;
  final dynamic jsonData;
  final bool initialShouldHighlightText;
  final String initialHighlightVerse;

  QuranViewController({
    required this.initialPageNumber,
    required this.jsonData,
    required this.initialShouldHighlightText,
    required this.initialHighlightVerse,
  });

  var pageNumber = 0.obs;
  var shouldHighlightText = false.obs;
  var highlightVerse = "".obs;
  var index = 1.obs;
  var selectedSpan = "".obs;
  var showStartBoundaryFeedback = false.obs;
  var showEndBoundaryFeedback = false.obs;
  final int totalPagesCount = 604; // Total number of Quran pages

  late PageController pageController;
  List<GlobalKey> richTextKeys = List.generate(
    604, // Number of pages
    (_) => GlobalKey(),
  );

  var shouldShowSearchDialog = false.obs;
  var isSearchDialogOpen = false.obs;
  var shouldPrintPageNumbers = true.obs;
  RxBool isAtFirstPage = false.obs;
  RxBool isAtLastPage = false.obs;

  // For undo navigation history
  final List<int> _navigationHistory = [];
  final int _maxHistorySize = 20;

  @override
  void onInit() {
    super.onInit();
    pageNumber.value = initialPageNumber;
    shouldHighlightText.value = initialShouldHighlightText;
    highlightVerse.value = initialHighlightVerse;
    setIndex();

    // Calculate the correct initial page to display (handling edge cases)
    // Ensure we never start below page 1 (Fatiha)
    int actualInitialPage = initialPageNumber < 1 ? 1 : initialPageNumber;

    // Initialize PageController with optimal settings for smooth scrolling
    pageController = PageController(
      initialPage: actualInitialPage,
      keepPage: true,
      viewportFraction:
          0.999, // Slightly less than 1.0 to reduce edge resistance
    );

    // Only apply the boundary listener for the first page
    // This ensures smooth scrolling between other pages
    if (actualInitialPage <= 1) {
      pageController.addListener(_enforceFirstPageBoundary);
    }

    // Initialize first/last page indicators
    _updateBoundaryIndicators(actualInitialPage);

    // Set the observable index to match our initial page
    index.value = actualInitialPage;

    if (initialShouldHighlightText) {
      highlightVerseFunction();
    }

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
  }

  @override
  void onClose() {
    pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.onClose();
  }

  void setIndex() {
    index.value = pageNumber.value;
  }

  void showBoundaryFeedback(bool isFirstPage) {
    // Only show feedback for first page when we're actually at the first page
    if (isFirstPage) {
      if (index.value <= 1) {
        showStartBoundaryFeedback.value = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          showStartBoundaryFeedback.value = false;
        });
      }
    } else {
      // Only show feedback for last page when we're actually at the last page
      if (index.value >= totalPagesCount) {
        showEndBoundaryFeedback.value = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          showEndBoundaryFeedback.value = false;
        });
      }
    }
  }

  void highlightVerseFunction() {
    if (shouldHighlightText.value) {
      Timer.periodic(const Duration(milliseconds: 400), (timer) {
        shouldHighlightText.value = false;

        Timer(const Duration(milliseconds: 200), () {
          shouldHighlightText.value = true;

          if (timer.tick == 4) {
            highlightVerse.value = "";
            shouldHighlightText.value = false;
            timer.cancel();
          }
        });
      });
    }
  }

  void onPageChanged(int newIndex) {
    try {
      // Add the previous page to history before updating
      if (index.value != newIndex &&
          newIndex >= 1 &&
          newIndex <= totalPagesCount) {
        addToNavigationHistory(index.value);
      }

      // Update the current page index
      index.value = newIndex;

      // Update boundary status
      _updateBoundaryIndicators(newIndex);

      // Save last read page to shared preferences
      saveLastReadPage(newIndex);

      // Reset highlighted verse after page change
      shouldHighlightText.value = false;
      highlightVerse.value = "";
    } catch (e) {
      if (kDebugMode) {
        print("Error in onPageChanged: $e");
      }
    }
  }

  void addToNavigationHistory(int page) {
    if (_navigationHistory.length >= _maxHistorySize) {
      _navigationHistory.removeAt(0);
    }
    _navigationHistory.add(page);
  }

  void navigateBack() {
    try {
      // Always return to quran_sura_page instead of previous page
      Get.back();
    } catch (e) {
      if (kDebugMode) {
        print("Error navigating back: $e");
      }
      Get.back();
    }
  }

  // Get page data safely with error handling
  List<dynamic> getPageData(int page) {
    try {
      // First attempt to use the original method signature for compatibility
      final result = getPageDataList(page);
      if (result.isNotEmpty) {
        return result;
      }

      // Fallback logic if the above returns empty
      if (jsonData is! Map && jsonData is! List) {
        return [];
      }

      // If jsonData is a list (which would be the case from search results)
      if (jsonData is List) {
        // For search results, we expect the specific surah data to be passed
        // Try to find the correct page data
        if (page > 0 && page <= totalPagesCount) {
          // Use quran package to get page data
          try {
            final data = quran.getPageData(page);
            return List<dynamic>.from(data);
          } catch (e) {
            if (kDebugMode) {
              print("Error getting page data from quran package: $e");
            }
          }
        }
        return [];
      }

      // Original implementation for Map type jsonData
      final quranData = jsonData["quran"]["quran-simple"];
      if (quranData is! Map || !quranData.containsKey("$page")) {
        return [];
      }

      final pageData = quranData["$page"];
      return pageData is List ? pageData : [];
    } catch (e) {
      if (kDebugMode) {
        print("Error getting page data: $e");
      }
      return [];
    }
  }

  // Save the last read page to SharedPreferences
  Future<void> saveLastReadPage(int page) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastReadPage', page);
    } catch (e) {
      if (kDebugMode) {
        print("Error saving last read page: $e");
      }
    }
  }

  void highlightTextChange(bool value) {
    shouldHighlightText.value = value;
    if (!value) {
      highlightVerse.value = "";
    }
  }

  void updateHighlightVerse(String verse) {
    highlightVerse.value = verse;
  }

  void toggleSearchDialog() {
    shouldShowSearchDialog.value = !shouldShowSearchDialog.value;
  }

  void jumpToPage(int page) {
    if (page >= 1 && page <= totalPagesCount) {
      addToNavigationHistory(index.value);
      pageController.jumpToPage(page);
      index.value = page;
      _updateBoundaryIndicators(page);
    }
  }

  // Helper method to get page data
  List<Map<String, dynamic>> getPageDataList(int page) {
    if (page <= 0) return [];
    try {
      var data = quran.getPageData(page);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("Error getting page data: $e");
      return [];
    }
  }

  // Method to handle long press on verses
  void onVerseLongPress(int surahNum, int verseNum) {
    print("Long pressed surah $surahNum verse $verseNum");
    // Implement your verse options logic here
  }

  void onVerseLongPressDown(int surahNum, int verseNum) {
    selectedSpan.value = "$surahNum$verseNum";
    update();
  }

  void onVerseLongPressUp() {
    selectedSpan.value = "";
    update();
  }

  void onVerseLongPressCancel() {
    selectedSpan.value = "";
    update();
  }

  // Get font family for the page
  String getFontFamily(int page) {
    return "QCF_P${page.toString().padLeft(3, "0")}";
  }

  // Get appropriate font size based on page
  double getFontSize(int page) {
    if (page == 1 || page == 2) {
      return 28.sp;
    } else if (page == 145 || page == 201) {
      return 22.4.sp;
    } else if (page == 532 || page == 533) {
      return 22.5.sp;
    } else {
      return 23.1.sp;
    }
  }

  // Get appropriate line height
  double getLineHeight(int page) {
    return (page == 1 || page == 2) ? 2.h : 1.95.h;
  }

  // Create a verse TextSpan with proper styling and gestures
  TextSpan createVerseTextSpan(Map<String, dynamic> e, int i, int page) {
    // Create a gesture recognizer
    final LongPressGestureRecognizer recognizer = LongPressGestureRecognizer();

    // Configure recognizer
    recognizer.onLongPress = () {
      onVerseLongPress(e["surah"], i);
    };

    recognizer.onLongPressDown = (LongPressDownDetails details) {
      onVerseLongPressDown(e["surah"], i);
    };

    recognizer.onLongPressUp = () {
      onVerseLongPressUp();
    };

    recognizer.onLongPressCancel = () {
      onVerseLongPressCancel();
    };

    // Create and return the TextSpan
    return TextSpan(
      recognizer: recognizer,
      text:
          i == e["start"]
              ? "${quran.getVerseQCF(e["surah"], i).replaceAll(" ", "").substring(0, 1)}\u200A${quran.getVerseQCF(e["surah"], i).replaceAll(" ", "").substring(1)}"
              : quran.getVerseQCF(e["surah"], i).replaceAll(' ', ''),
      style: TextStyle(
        color: Colors.black,
        height: getLineHeight(page),
        letterSpacing: 0.w,
        wordSpacing: 0,
        fontFamily: getFontFamily(page),
        fontSize: getFontSize(page),
        backgroundColor: Colors.transparent,
      ),
      children: const <TextSpan>[],
    );
  }

  // Generate text spans for a page
  List<InlineSpan> getPageTextSpans(BuildContext context, int page) {
    List<InlineSpan> allSpans = [];

    if (page <= 0) return allSpans;

    try {
      var pageData = getPageData(page);

      for (var e in pageData) {
        List<InlineSpan> spans = [];

        for (var i = e["start"]; i <= e["end"]; i++) {
          // Add header for first verse
          if (i == 1) {
            spans.add(
              WidgetSpan(child: HeaderWidget(e: e, jsonData: jsonData)),
            );

            // Add Basmallah for most surahs
            if (page != 187 && page != 1) {
              spans.add(WidgetSpan(child: Basmallah(index: 0)));
            }

            if (page == 187) {
              spans.add(WidgetSpan(child: Container(height: 10.h)));
            }
          }

          // Add verse text with gestures
          spans.add(createVerseTextSpan(e, i, page));
        }

        allSpans.addAll(spans);
      }

      return allSpans;
    } catch (e) {
      print("Error generating text spans: $e");
      return [TextSpan(text: "Error loading page content")];
    }
  }

  // Update boundary indicators based on current page
  void _updateBoundaryIndicators(int page) {
    isAtFirstPage.value = page <= 1;
    isAtLastPage.value = page >= totalPagesCount;
  }

  // Enforce page boundaries only for first page
  void _enforceFirstPageBoundary() {
    // Only do this when controller has clients
    if (!pageController.hasClients) return;

    try {
      double? currentPage = pageController.page;

      // Only enforce the first page boundary - the most important one
      if (currentPage != null && currentPage < 1.0) {
        // If we somehow got before page 1, snap back immediately
        pageController.jumpToPage(1);
        showBoundaryFeedback(true);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error in _enforceFirstPageBoundary: $e");
      }
    }
  }
}
