import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:quran/dart';
import 'package:quran/quran.dart';
import 'package:quranapp/globalhelpers/constants.dart';
import 'package:quranapp/models/sura.dart';
import 'package:easy_container/easy_container.dart';
import 'package:quranapp/views/quran_page.dart';
import 'package:string_validator/string_validator.dart';
import 'package:get/get.dart';
import 'package:quranapp/controllers/quran_page_controller.dart';
import 'package:quranapp/models/search_type.dart';

class QuranPage extends StatelessWidget {
  QuranPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Get.find() with error handling
    final controller =
        Get.isRegistered<QuranPageController>()
            ? Get.find<QuranPageController>()
            : Get.put(QuranPageController());

    return Scaffold(
      backgroundColor: quranPagesColor,
      appBar: AppBar(title: const Text("Quran Page")),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              cacheExtent: 1000, // Cache more items
              slivers: [
                SliverToBoxAdapter(child: _buildSearchBar(controller)),
                if (controller.pageNumbers.isNotEmpty)
                  _buildPageNumbersList(controller),
                if ((controller.searchType.value == SearchType.ayah ||
                        controller.searchType.value == SearchType.all) &&
                    controller.verseSearchResults.isNotEmpty)
                  _buildVerseSearchResults(controller),
                if (controller.searchType.value != SearchType.ayah)
                  _buildSuraList(controller),
              ],
            ),
            if (controller.isSearching.value)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      }),
    );
  }

  Widget _buildSearchBar(QuranPageController controller) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              textDirection: TextDirection.rtl,
              controller: controller.textEditingController,
              onChanged: controller.onSearchChanged,
              style: const TextStyle(color: Color.fromARGB(190, 0, 0, 0)),
              decoration: InputDecoration(
                hintText:
                    'Search ${controller.searchType.value.displayName}...',
                hintStyle: const TextStyle(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon:
                    controller.searchQuery.value.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: controller.clearSearch,
                        )
                        : null,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: PopupMenuButton<SearchType>(
              initialValue: controller.searchType.value,
              onSelected: controller.setSearchType,
              itemBuilder:
                  (context) =>
                      SearchType.values
                          .map(
                            (type) => PopupMenuItem(
                              value: type,
                              child: Text(type.displayName),
                            ),
                          )
                          .toList(),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Text(controller.searchType.value.displayName),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageNumbersList(QuranPageController controller) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((ctx, index) {
        return Padding(
          padding: const EdgeInsets.all(5.0),
          child: EasyContainer(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(controller.pageNumbers[index].toString()),
                  Text(
                    getSurahName(
                      getPageData(controller.pageNumbers[index])[0]["surah"],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }, childCount: controller.pageNumbers.length),
    );
  }

  Widget _buildVerseSearchResults(QuranPageController controller) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == controller.verseSearchResults.length) {
          return controller.verseSearchResults.length <
                  controller.allVerseResults.length
              ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: controller.loadMoreResults,
                  child: Text(
                    "Show More (${controller.allVerseResults.length - controller.verseSearchResults.length} remaining)",
                  ),
                ),
              )
              : null;
        }

        final verse = controller.verseSearchResults[index];
        return ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              verse['text'] ?? '',
              style: const TextStyle(fontSize: 20, height: 2),
            ),
          ),
          subtitle: Text(
            'Surah ${getSurahName(verse["surah"])} - Verse ${verse["verse"]}',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          onTap: () {
            final pageNum = getPageNumber(verse['surah'], verse['verse']);
            print(
              'Navigating to page $pageNum for surah ${verse["surah"]}, verse ${verse["verse"]}',
            );
            Get.toNamed(
              '/quran-view-page',
              arguments: {
                'shouldHighlightText': true,
                'highlightVerse': verse['text'],
                'pageNumber': pageNum,
              },
            );
          },
        );
      }, childCount: controller.verseSearchResults.length + 1),
    );
  }

  Widget _buildSuraList(QuranPageController controller) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        try {
          if (controller.filteredData == null ||
              index >= controller.filteredData.length) {
            return null;
          }

          int suraNumber = controller.filteredData[index]["number"];
          String suraName = controller.filteredData[index]["englishName"];
          String suraNameEnglishTranslated =
              controller.filteredData[index]["englishNameTranslation"];
          int suraNumberInQuran = controller.filteredData[index]["number"];
          String suraNameTranslated = getSurahNameArabic(suraNumberInQuran);
          int ayahCount = getVerseCount(suraNumberInQuran);

          return ListTile(
            leading: SizedBox(
              width: 45,
              height: 45,
              child: Center(
                child: Text(
                  suraNumber.toString(),
                  style: const TextStyle(color: orangeColor, fontSize: 14),
                ),
              ),
            ),
            minVerticalPadding: 0,
            title: SizedBox(
              width: 90,
              child: Row(
                children: [
                  Text(
                    suraName,
                    style: const TextStyle(
                      color: blueColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                style: const TextStyle(
                  fontFamily: "arsura",
                  fontSize: 22,
                  color: Colors.black,
                ),
              ),
            ),
            onTap: () {
              final pageNum = getPageNumber(suraNumberInQuran, 1);
              print('Navigating to page $pageNum for surah $suraNumberInQuran');
              Get.toNamed(
                '/quran-view-page',
                arguments: {
                  'shouldHighlightText': false,
                  'highlightVerse': "",
                  'jsonData': controller.filteredData[index],
                  'pageNumber': pageNum,
                },
              );
            },
          );
        } catch (e) {
          dev.log('Error building item at index $index: $e');
          return null;
        }
      }, childCount: controller.filteredData?.length ?? 0),
    );
  }
}
