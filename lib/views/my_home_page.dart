import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quranapp/controllers/home_controller.dart';
import 'package:quranapp/globalhelpers/constants.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.put(HomeController());

    return Scaffold(
      backgroundColor: quranPagesColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: controller.navigateToQuranPage,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
              ),
              child: const Text("Read Quran"),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: controller.navigateToAudioPage,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
              ),
              child: const Text("Listen to Recitations"),
            ),
          ],
        ),
      ),
    );
  }
}
