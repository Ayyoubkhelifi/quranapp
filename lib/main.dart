import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:quranapp/views/my_home_page.dart';
import 'package:quranapp/views/quran_page.dart';
import 'package:quranapp/views/quran_sura_page.dart';
import 'package:quranapp/views/quran_audio_page.dart';

void main() {
  // Initialize the binding first
  WidgetsFlutterBinding.ensureInitialized();

  // Now we can safely access ServicesBinding.instance
  ServicesBinding.instance.keyboard.addHandler((KeyEvent event) {
    // Return true for the problematic key to prevent default handling
    // This is typically the '#' key on Android devices
    if (event is KeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.numberSign) {
      return true; // Mark as handled
    }
    return false; // Let other keys be handled normally
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(392.72727272727275, 800.7272727272727),
      builder:
          (context, child) => GetMaterialApp(
            title: 'Quran App',
            theme: ThemeData(primarySwatch: Colors.blue),
            initialRoute: '/',
            getPages: [
              GetPage(name: '/', page: () => const MyHomePage()),
              GetPage(name: '/quran-page', page: () => QuranPage()),
              GetPage(name: '/quran-audio', page: () => QuranAudioPage()),
              GetPage(
                name: '/quran-view-page',
                page:
                    () =>
                        Get.arguments != null
                            ? QuranViewPage(
                              pageNumber: Get.arguments['pageNumber'] ?? 1,
                              jsonData: Get.arguments['jsonData'] ?? {},
                              shouldHighlightText:
                                  Get.arguments['shouldHighlightText'] ?? false,
                              highlightVerse:
                                  Get.arguments['highlightVerse'] ?? "",
                            )
                            : QuranPage(),
              ),
            ],
          ),
    );
  }
}
