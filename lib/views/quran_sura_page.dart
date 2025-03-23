import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:quran/dart';
import 'package:quran/quran.dart';
import 'package:quranapp/globalhelpers/constants.dart';
import 'package:quranapp/models/sura.dart';
import 'package:easy_container/easy_container.dart';
import 'package:quranapp/views/quran_page.dart';
import 'package:string_validator/string_validator.dart';

class QuranPage extends StatefulWidget {
  QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  TextEditingController textEditingController = TextEditingController();
  var suraJsonData;
  loadJsonAsset() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/json/surahs.json',
      );
      var data = jsonDecode(jsonString);
      setState(() {
        suraJsonData = data;
      });
    } catch (e) {
      print('Error loading JSON asset: $e');
      // Provide empty data structure to prevent null errors
      setState(() {
        suraJsonData = [];
      });
    }
  }

  bool isLoading = true;

  var searchQuery = "";
  var filteredData;
  List<Surah> surahList = [];
  var ayatFiltered;

  List pageNumbers = [];

  addFilteredData() async {
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      filteredData = suraJsonData;
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  void initializeData() async {
    await loadJsonAsset();
    addFilteredData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: quranPagesColor,
      appBar: AppBar(title: const Text("Quran Page")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                shrinkWrap: true,
                physics: const CustomPageViewScrollPhysics(),
                children: [
                  TextField(
                    textDirection: TextDirection.rtl,
                    controller: textEditingController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });

                      if (value == "") {
                        filteredData = suraJsonData;

                        pageNumbers = [];

                        setState(() {});
                      }

                      if (searchQuery.isNotEmpty &&
                          isInt(searchQuery) &&
                          toInt(searchQuery) < 605 &&
                          toInt(searchQuery) > 0) {
                        pageNumbers.add(toInt(searchQuery));
                      }

                      if (searchQuery.length > 3 ||
                          searchQuery.toString().contains(" ")) {
                        setState(() {
                          ayatFiltered = [];

                          ayatFiltered = searchWords(searchQuery);
                          filteredData =
                              suraJsonData.where((sura) {
                                final suraName =
                                    sura['englishName'].toLowerCase();
                                // final suraNameTranslated =
                                //     sura['name']
                                //         .toString()
                                //         .toLowerCase();
                                final suraNameTranslated = getSurahNameArabic(
                                  sura["number"],
                                );

                                return suraName.contains(
                                      searchQuery.toLowerCase(),
                                    ) ||
                                    suraNameTranslated.contains(
                                      searchQuery.toLowerCase(),
                                    );
                              }).toList();
                        });
                      }
                    },
                    style: const TextStyle(color: Color.fromARGB(190, 0, 0, 0)),
                    decoration: const InputDecoration(
                      hintText: 'searchQuran',
                      hintStyle: TextStyle(),
                      border: InputBorder.none,
                    ),
                  ),
                  if (pageNumbers.isNotEmpty)
                    Container(
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("page"),
                      ),
                    ),
                  ListView.separated(
                    reverse: true,
                    itemBuilder: (ctx, index) {
                      return Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: EasyContainer(
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(pageNumbers[index].toString()),
                                Text(
                                  getSurahName(
                                    getPageData(pageNumbers[index])[0]["surah"],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder:
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Divider(color: Colors.grey.withOpacity(.5)),
                        ),
                    itemCount: pageNumbers.length,
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder:
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Divider(color: Colors.grey.withOpacity(.5)),
                        ),
                    itemCount: filteredData?.length ?? 0,
                    itemBuilder: (context, index) {
                      if (filteredData == null ||
                          index >= filteredData.length) {
                        return const SizedBox.shrink();
                      }

                      int suraNumber = index + 1;
                      String suraName =
                          filteredData[index]["englishName"] ?? "";
                      String suraNameEnglishTranslated =
                          filteredData[index]["englishNameTranslation"] ?? "";
                      int suraNumberInQuran = filteredData[index]["number"];
                      String suraNameTranslated =
                          filteredData[index]["name"].toString();
                      int ayahCount = getVerseCount(suraNumber);

                      return Padding(
                        padding: const EdgeInsets.all(0.0),
                        child: Container(
                          child: ListTile(
                            leading: SizedBox(
                              width: 45,
                              height: 45,
                              child: Center(
                                child: Text(
                                  suraNumber.toString(),
                                  style: const TextStyle(
                                    color: orangeColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ), //  Material(
                            minVerticalPadding: 0,
                            title: SizedBox(
                              width: 90,
                              child: Row(
                                children: [
                                  Text(
                                    suraName,
                                    style: const TextStyle(
                                      // fontWeight: FontWeight.bold,
                                      color: blueColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700, // Text color
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            subtitle: Text(
                              "$suraNameEnglishTranslated ($ayahCount)",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.withOpacity(.8),
                              ),
                            ),
                            trailing: RichText(
                              text: TextSpan(
                                text: suraNumber.toString(),

                                // textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: "arsura",
                                  fontSize: 22,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            onTap: () async {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (builder) => QuranViewPage(
                                        shouldHighlightText: false,
                                        highlightVerse: "",
                                        jsonData: suraJsonData,
                                        pageNumber: getPageNumber(
                                          suraNumberInQuran,
                                          1,
                                        ),
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  if (ayatFiltered != null)
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount:
                          ayatFiltered["occurences"] != null &&
                                  ayatFiltered["occurences"] > 10
                              ? 10
                              : ayatFiltered["occurences"] ?? 0,
                      itemBuilder: (context, index) {
                        if (ayatFiltered["result"] == null ||
                            index >= (ayatFiltered["result"]?.length ?? 0)) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: EasyContainer(
                            color: Colors.white70,
                            borderRadius: 14,
                            onTap: () async {},
                            child: Text(
                              "سورة ${getSurahNameArabic(ayatFiltered["result"][index]["surah"])} - ${getVerse(ayatFiltered["result"][index]["surah"], ayatFiltered["result"][index]["verse"], verseEndSymbol: true)}",
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
    );
  }
}
