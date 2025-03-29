import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quranapp/controllers/home_controller.dart';
import 'package:quranapp/globalhelpers/constants.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quranapp/controllers/quran_audio_controller.dart';
import 'package:quranapp/widgets/persistent_audio_player.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.put(HomeController());
    final audioController = Get.find<QuranAudioController>();

    return Scaffold(
      backgroundColor: quranPagesColor,
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16.w,
                mainAxisSpacing: 16.w,
                children: [
                  _buildFeatureCard(
                    context,
                    'Quran Viewer',
                    Icons.book,
                    () => Get.toNamed('/quran-page'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Audio Recitation',
                    Icons.headset,
                    () => Get.toNamed('/quran-audio'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Prayer Times',
                    Icons.access_time,
                    () => _showFeatureComingSoon(context, 'Prayer Times'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Qibla Direction',
                    Icons.explore,
                    () => _showFeatureComingSoon(context, 'Qibla Direction'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Islamic Calendar',
                    Icons.calendar_today,
                    () => _showFeatureComingSoon(context, 'Islamic Calendar'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Duas',
                    Icons.favorite,
                    () => _showFeatureComingSoon(context, 'Duas'),
                  ),
                ],
              ),
            ),
          ),

          // Mini audio player that appears at the bottom of all screens
          Obx(
            () =>
                audioController.currentlyPlayingFile.value.isNotEmpty
                    ? PersistentAudioPlayerBar(
                      controller: audioController,
                      isMinimized: true,
                      onTap: () => Get.toNamed('/quran-audio'),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50.w, color: Theme.of(context).primaryColor),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showFeatureComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
