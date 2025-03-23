import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quranapp/globalhelpers/constants.dart';
import 'package:quranapp/views/quran_sura_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var widgejsonData;

  loadJsonAsset() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/json/surahs.json',
      );
      var data = jsonDecode(jsonString);
      setState(() {
        widgejsonData = data;
      });
    } catch (e) {
      print('Error loading JSON asset: $e');
      // Provide empty data structure to prevent null errors
      setState(() {
        widgejsonData = [];
      });
    }
  }

  @override
  void initState() {
    loadJsonAsset();

    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: quranPagesColor,
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (builder) => QuranPage()),
            );
          },
          child: const Text("Go To Quran Page"),
        ),
      ),
    );
  }
}
