import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:quranapp/views/my_home_page.dart';
import 'package:quranapp/views/quran_page.dart';
import 'package:quranapp/views/quran_sura_page.dart';
import 'package:quranapp/views/quran_audio_page.dart';
import 'package:quranapp/services/quran_audio_background_service.dart';
import 'package:quranapp/controllers/quran_view_controller.dart';
import 'package:quranapp/controllers/quran_audio_controller.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  // Wrap the entire startup in a try-catch block to prevent crashes
  try {
    // Initialize the binding first
    WidgetsFlutterBinding.ensureInitialized();

    // Set up error handling for platform channel errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is PlatformException) {
        // Log platform exceptions but don't crash the app
        debugPrint('Platform exception: ${details.exception}');
        // No need to present the error UI for platform exceptions
      } else {
        // For other errors, use default error handling
        FlutterError.presentError(details);
      }
    };

    // Initialize audio services
    await QuranAudioBackgroundService.init();

    // Register the QuranAudioController and restore last session
    final audioController = QuranAudioController();
    Get.put(audioController, permanent: true);

    try {
      // Initialize API data first before trying to restore playback
      print("Loading API data before session restoration...");
      await Future.wait([
        audioController.loadQarisList(),
        audioController.loadSectionsList(),
        audioController.loadSurahsList(),
      ]);
      print("API data loaded successfully");

      // Then load downloaded files
      await audioController.loadDownloadedFiles();
      print("Downloaded files loaded successfully");

      // Finally restore last session when everything is ready
      audioController.restoreLastPlayback();
      print("Last session restoration attempted");
    } catch (e) {
      print("Error during initialization sequence: $e");
    }

    // Start the app first
    runApp(const MyApp());

    // Defer initialization of services
    _initializeServicesAfterDelay();
  } catch (e) {
    // Catch any unexpected errors during app startup
    debugPrint('Critical error during app startup: $e');

    // Run a minimal app that shows an error screen if everything else fails
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Error starting app: $e'))),
      ),
    );
  }
}

// Initialize services after a delay to ensure the app is running
Future<void> _initializeServicesAfterDelay() async {
  try {
    // Allow the app UI to initialize first
    await Future.delayed(const Duration(seconds: 2));

    // Initialize background audio service
    try {
      await QuranAudioBackgroundService.init();
      debugPrint('Audio service initialized successfully');
    } catch (e) {
      // Log the error but continue with the app
      debugPrint('Error initializing audio service: $e');
    }

    // Now we can safely access ServicesBinding.instance
    try {
      ServicesBinding.instance.keyboard.addHandler((KeyEvent event) {
        // Return true for the problematic key to prevent default handling
        // This is typically the '#' key on Android devices
        if (event is KeyUpEvent &&
            event.logicalKey == LogicalKeyboardKey.numberSign) {
          return true; // Mark as handled
        }
        return false; // Let other keys be handled normally
      });
    } catch (e) {
      debugPrint('Error setting up keyboard handler: $e');
    }
  } catch (e) {
    debugPrint('Error during delayed services initialization: $e');
    // App will continue to run even if services fail to initialize
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Register controllers with default values
    Get.put(
      QuranViewController(
        initialPageNumber: 1,
        jsonData: {},
        initialShouldHighlightText: false,
        initialHighlightVerse: "",
      ),
      permanent: true,
    );

    return ScreenUtilInit(
      designSize: const Size(392.72727272727275, 800.7272727272727),
      builder:
          (context, child) => GetMaterialApp(
            title: 'Quran App',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.green,
              textTheme: GoogleFonts.poppinsTextTheme(),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            initialRoute: '/',
            getPages: [
              GetPage(name: '/', page: () => const MyHomePage()),
              GetPage(name: '/quran-page', page: () => QuranPage()),
              GetPage(name: '/quran-audio', page: () => const QuranAudioPage()),
              GetPage(
                name: '/quran-view-page',
                page: () {
                  if (Get.arguments != null &&
                      Get.arguments['pageNumber'] != null) {
                    print(
                      "Navigating to Quran view page: ${Get.arguments['pageNumber']}",
                    );
                  }
                  return Get.arguments != null
                      ? QuranViewPage(
                        pageNumber: Get.arguments['pageNumber'] ?? 1,
                        jsonData: Get.arguments['jsonData'] ?? {},
                        shouldHighlightText:
                            Get.arguments['shouldHighlightText'] ?? false,
                        highlightVerse: Get.arguments['highlightVerse'] ?? "",
                      )
                      : QuranPage();
                },
              ),
            ],
          ),
    );
  }
}
