import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quranapp/controllers/home_controller.dart';
import 'package:quranapp/globalhelpers/constants.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller with GetX
    final HomeController controller = Get.put(HomeController());

    return Scaffold(
      backgroundColor: quranPagesColor,
      body: Center(
        child: ElevatedButton(
          onPressed: controller.navigateToQuranPage,
          child: const Text("Go To Quran Page"),
        ),
      ),
    );
  }
}
