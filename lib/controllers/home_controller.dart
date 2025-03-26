import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quranapp/controllers/quran_page_controller.dart';

class HomeController extends GetxController {
  var jsonData;

  @override
  void onInit() {
    loadJsonAsset();
    super.onInit();
  }

  loadJsonAsset() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/json/surahs.json',
      );
      var data = jsonDecode(jsonString);
      jsonData = data;
      update(); // Notify GetBuilder to update UI
    } catch (e) {
      print('Error loading JSON asset: $e');
      // Provide empty data structure to prevent null errors
      jsonData = [];
      update();
    }
  }

  void navigateToQuranPage() {
    // Initialize QuranPageController before navigation
    Get.put(QuranPageController());
    Get.toNamed('/quran-page');
  }

  void navigateToAudioPage() {
    Get.toNamed('/quran-audio');
  }
}
