import 'dart:async';

import 'package:easy_container/easy_container.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quranapp/globalhelpers/constants.dart';
import 'package:quranapp/widgets/basmallah.dart';
import 'package:quranapp/widgets/header_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:get/get.dart';
import 'package:quranapp/controllers/quran_view_controller.dart';
import 'package:quranapp/widgets/persistent_audio_player.dart';
import 'package:quranapp/controllers/quran_audio_controller.dart';

// Smoother scrolling physics for Quran pages with minimal resistance
class QuranScrollPhysics extends ScrollPhysics {
  final int currentPage;
  final int totalPages;
  final QuranViewController controller;

  const QuranScrollPhysics({
    required this.currentPage,
    required this.totalPages,
    required this.controller,
    ScrollPhysics? parent,
  }) : super(parent: parent);

  @override
  QuranScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return QuranScrollPhysics(
      currentPage: currentPage,
      totalPages: totalPages,
      controller: controller,
      parent: buildParent(ancestor),
    );
  }

  // Only block scrolling at absolute boundaries
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Only block at first page when at absolute edge
    if (currentPage <= 1) {
      if (position.pixels >= position.maxScrollExtent - 0.1) {
        controller.showBoundaryFeedback(true);
        return false; // Block only at the absolute edge
      }
    }

    // Only block at last page when at absolute edge
    if (currentPage >= totalPages) {
      if (position.pixels <= position.minScrollExtent + 0.1) {
        controller.showBoundaryFeedback(false);
        return false; // Block only at the absolute edge
      }
    }

    return true; // Allow all other scrolling
  }

  // Use reduced resistance for smoother scrolling
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Only block at first page when trying to go backward at the absolute edge
    if (currentPage <= 1 &&
        offset > 0 &&
        position.pixels >= position.maxScrollExtent - 0.1) {
      controller.showBoundaryFeedback(true);
      return 0.0;
    }

    // Only block at last page when trying to go forward at the absolute edge
    if (currentPage >= totalPages &&
        offset < 0 &&
        position.pixels <= position.minScrollExtent + 0.1) {
      controller.showBoundaryFeedback(false);
      return 0.0;
    }

    // Make scrolling smoother with reduced resistance
    return offset * 1.05; // Slightly boost scrolling movement
  }

  // No boundary conditions for smoother experience
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    return 0.0; // No additional resistance
  }

  // Use lower friction for smoother scrolling
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // For all pages, use smoother scrolling physics
    if (velocity.abs() >= kMinFlingVelocity) {
      return ClampingScrollSimulation(
        position: position.pixels,
        velocity: velocity,
        friction:
            0.12, // Lower friction for smoother scrolling (was default 0.135)
        tolerance: const Tolerance(
          velocity: 1.0, // More tolerant velocity threshold
          distance: 0.01, // More tolerant distance threshold
        ),
      );
    }

    return super.createBallisticSimulation(position, velocity);
  }
}

class QuranViewPage extends StatelessWidget {
  final int pageNumber;
  final dynamic jsonData;
  final bool shouldHighlightText;
  final String highlightVerse;

  const QuranViewPage({
    Key? key,
    required this.pageNumber,
    required this.jsonData,
    required this.shouldHighlightText,
    required this.highlightVerse,
  }) : super(key: key);

  // Helper function to get surah name
  String getSurahName(QuranViewController controller, int page) {
    try {
      final data = controller.jsonData;
      final pageData = controller.getPageData(page);
      if (pageData.isEmpty) return "Surah";

      // Get the surah number from the page data
      final surahNumber = pageData[0]["surah"];

      // If data is a search result (a list with specific surah)
      if (data is List && data.isNotEmpty) {
        // First check if the surah in the list matches the page's surah
        for (var surah in data) {
          if (surah["number"] == surahNumber) {
            return surah["name"] ?? "Surah";
          }
        }
      }

      // Fallback to using the quran package for consistent naming
      return quran.getSurahNameArabic(surahNumber);
    } catch (e) {
      return "Surah";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Log the provided page number for debugging
    print("QuranViewPage building with pageNumber: $pageNumber");

    final controller = Get.put(
      QuranViewController(
        initialPageNumber: pageNumber,
        jsonData: jsonData,
        initialShouldHighlightText: shouldHighlightText,
        initialHighlightVerse: highlightVerse,
      ),
      tag: "quran_view_${pageNumber}_${DateTime.now().millisecondsSinceEpoch}",
    );

    // Get audio controller for the mini player
    final audioController = Get.find<QuranAudioController>();

    // Use a FutureBuilder to ensure the PageController is ready
    return FutureBuilder(
      // We're not waiting for any actual future, just using post-frame callback
      future: Future.delayed(Duration.zero),
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: quranPagesColor,
          body: WillPopScope(
            onWillPop: () async {
              // Return to quran_sura_page
              controller.navigateBack();
              return false;
            },
            child: Column(
              children: [
                // Main content with PageView
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      // Only handle events from our PageView
                      if (notification.depth != 0) return false;

                      // ONLY show boundary feedback at the first and last page
                      // First page - show boundary feedback only
                      if (controller.index.value <= 1) {
                        if (notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent - 5) {
                          controller.showBoundaryFeedback(true);
                        }
                      }

                      // Last page - show boundary feedback only
                      if (controller.index.value >=
                          controller.totalPagesCount) {
                        if (notification.metrics.pixels <=
                            notification.metrics.minScrollExtent + 5) {
                          controller.showBoundaryFeedback(false);
                        }
                      }

                      // Never consume the notifications to allow scrolling
                      return false;
                    },
                    child: Stack(
                      children: [
                        Obx(
                          () => PageView.builder(
                            controller: controller.pageController,
                            reverse: true,
                            scrollDirection: Axis.horizontal,
                            onPageChanged: controller.onPageChanged,
                            itemCount: controller.totalPagesCount + 1,
                            physics: QuranScrollPhysics(
                              currentPage: controller.index.value,
                              totalPages: controller.totalPagesCount,
                              controller: controller,
                            ),
                            itemBuilder: (context, page) {
                              // Cover page
                              if (page == 0) {
                                return Container(
                                  color: const Color(0xffFFFCE7),
                                  child: Center(
                                    child: Image.asset(
                                      "assets/images/888-02.png",
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              }

                              // Regular Quran page
                              return Container(
                                decoration: const BoxDecoration(
                                  color: quranPagesColor,
                                ),
                                child: Scaffold(
                                  resizeToAvoidBottomInset: false,
                                  backgroundColor: Colors.transparent,
                                  body: SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        right: 12.0,
                                        left: 12.0,
                                      ),
                                      child: SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(
                                          parent:
                                              AlwaysScrollableScrollPhysics(),
                                          decelerationRate:
                                              ScrollDecelerationRate.fast,
                                        ),
                                        child: Column(
                                          children: [
                                            // Header with page info and navigation
                                            SizedBox(
                                              width:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  // Left section with back button and surah name
                                                  SizedBox(
                                                    width:
                                                        MediaQuery.of(
                                                          context,
                                                        ).size.width *
                                                        0.27,
                                                    child: Row(
                                                      children: [
                                                        IconButton(
                                                          onPressed:
                                                              controller
                                                                  .navigateBack,
                                                          icon: const Icon(
                                                            Icons
                                                                .arrow_back_ios,
                                                            size: 24,
                                                          ),
                                                        ),
                                                        if (controller
                                                                    .jsonData !=
                                                                null &&
                                                            controller
                                                                .getPageData(
                                                                  page,
                                                                )
                                                                .isNotEmpty)
                                                          Flexible(
                                                            child: Text(
                                                              getSurahName(
                                                                controller,
                                                                page,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                    fontFamily:
                                                                        "Taha",
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Center - page number
                                                  EasyContainer(
                                                    borderRadius: 12,
                                                    color: Colors.orange
                                                        .withOpacity(0.5),
                                                    showBorder: true,
                                                    height: 20,
                                                    width: 120,
                                                    padding: 0,
                                                    margin: 0,
                                                    child: Center(
                                                      child: Text(
                                                        "Page $page",
                                                        style: const TextStyle(
                                                          fontFamily:
                                                              'aldahabi',
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  // Right section with settings button
                                                  SizedBox(
                                                    width:
                                                        MediaQuery.of(
                                                          context,
                                                        ).size.width *
                                                        0.27,
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        IconButton(
                                                          onPressed: () {},
                                                          icon: const Icon(
                                                            Icons.settings,
                                                            size: 24,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Special spacing for particular pages
                                            if (page == 1 || page == 2)
                                              SizedBox(
                                                height:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.height *
                                                    0.15,
                                              ),

                                            const SizedBox(height: 30),

                                            // Quran text with proper Arabic formatting
                                            Directionality(
                                              textDirection: TextDirection.rtl,
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  0.0,
                                                ),
                                                child: SizedBox(
                                                  width: double.infinity,
                                                  child: GetBuilder<
                                                    QuranViewController
                                                  >(
                                                    builder:
                                                        (ctrl) => RichText(
                                                          key:
                                                              controller
                                                                  .richTextKeys[page -
                                                                  1],
                                                          textDirection:
                                                              TextDirection.rtl,
                                                          textAlign:
                                                              (page == 1 ||
                                                                      page ==
                                                                          2 ||
                                                                      page >
                                                                          570)
                                                                  ? TextAlign
                                                                      .center
                                                                  : TextAlign
                                                                      .center,
                                                          softWrap: true,
                                                          locale: const Locale(
                                                            "ar",
                                                          ),
                                                          text: TextSpan(
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                              fontSize: 23.sp,
                                                            ),
                                                            children: controller
                                                                .getPageTextSpans(
                                                                  context,
                                                                  page,
                                                                ),
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Boundary feedback indicators
                        Obx(
                          () =>
                              controller.showStartBoundaryFeedback.value
                                  ? Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 5,
                                      color: Colors.red.withOpacity(0.5),
                                    ),
                                  )
                                  : const SizedBox.shrink(),
                        ),

                        Obx(
                          () =>
                              controller.showEndBoundaryFeedback.value
                                  ? Positioned(
                                    right: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 5,
                                      color: Colors.red.withOpacity(0.5),
                                    ),
                                  )
                                  : const SizedBox.shrink(),
                        ),

                        // Boundary feedback indicators
                        Positioned.fill(
                          child: Obx(
                            () => Stack(
                              children: [
                                // First page boundary indicator
                                if (controller.isAtFirstPage.value &&
                                    controller.showStartBoundaryFeedback.value)
                                  Positioned(
                                    top: 20.h,
                                    right: 20.w,
                                    child: EasyContainer(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: 10,
                                      padding: 10,
                                      child: Text(
                                        "First Page",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Last page boundary indicator
                                if (controller.isAtLastPage.value &&
                                    controller.showEndBoundaryFeedback.value)
                                  Positioned(
                                    top: 20.h,
                                    left: 20.w,
                                    child: EasyContainer(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: 10,
                                      padding: 10,
                                      child: Text(
                                        "Last Page",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Mini audio player at the bottom
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
          ),
        );
      },
    );
  }
}
