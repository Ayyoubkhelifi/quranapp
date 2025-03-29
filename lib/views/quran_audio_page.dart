// quran_audio_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quranapp/controllers/quran_audio_controller.dart';
import 'package:quranapp/widgets/persistent_audio_player.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quranapp/models/qari.dart';
import 'package:quranapp/models/section.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher_string.dart';

class QuranAudioPage extends StatelessWidget {
  const QuranAudioPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<QuranAudioController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Audio'),
        centerTitle: true,
        actions: [
          Obx(
            () => IconButton(
              icon: Icon(
                controller.filterBySection.value
                    ? Icons.filter_list
                    : Icons.filter_list_off,
              ),
              tooltip: 'Toggle Section Filter',
              onPressed: controller.toggleSectionFilter,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main content area - wrap in Expanded with SingleChildScrollView to prevent overflow
            Expanded(
              child: Obx(() {
                // Force refresh on trigger change
                controller.refreshTrigger.value;

                return Column(
                  children: [
                    // Top section can get very tall when sections are enabled
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildReciterSelector(context, controller),
                            if (controller.filterBySection.value &&
                                controller.sectionsList.isNotEmpty)
                              _buildSectionSelector(context, controller),
                          ],
                        ),
                      ),
                    ),
                    // The list should expand to fill remaining space
                    Expanded(child: _buildSurahList(context, controller)),
                  ],
                );
              }),
            ),

            // Persistent mini player
            Obx(
              () =>
                  controller.currentlyPlayingFile.value.isNotEmpty
                      ? const SizedBox(height: 8)
                      : const SizedBox.shrink(),
            ),

            // Audio progress bar
            Obx(
              () =>
                  controller.currentlyPlayingFile.value.isNotEmpty
                      ? _buildAudioProgressBar(context, controller)
                      : const SizedBox.shrink(),
            ),

            // Mini player
            Obx(
              () =>
                  controller.currentlyPlayingFile.value.isNotEmpty
                      ? _buildMiniPlayer(context, controller)
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReciterSelector(
    BuildContext context,
    QuranAudioController controller,
  ) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Obx(() {
        // Force refresh when needed
        controller.refreshTrigger.value;

        // Get filtered or all reciters based on section filter
        final qaris =
            controller.filterBySection.value &&
                    controller.currentSectionId.value > 0
                ? controller.getRecitersBySection(
                  controller.currentSectionId.value,
                )
                : controller.qarisList;

        if (controller.isLoadingQaris.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (qaris.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No reciters available. Please check your internet connection.',
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        // Check if the current reciter is in the filtered list (but don't update during build)
        final hasCurrentReciter =
            controller.currentQari.value != null &&
            qaris.any((q) => q.id == controller.currentQari.value!.id);

        // Choose a valid dropdown value - use currentQari if valid, otherwise null
        // This prevents the "Widget not found" error since we're not modifying state during build
        final dropdownValue =
            hasCurrentReciter ? controller.currentQari.value : null;

        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Qari>(
                  isExpanded: true,
                  hint: const Text('Select Reciter'),
                  value: dropdownValue,
                  onChanged: (Qari? newValue) {
                    if (newValue != null) {
                      controller.setCurrentReciter(newValue);
                    }
                  },
                  items:
                      qaris.map<DropdownMenuItem<Qari>>((Qari qari) {
                        return DropdownMenuItem<Qari>(
                          value: qari,
                          child: Text(
                            qari.arabicName != null
                                ? '${qari.name} (${qari.arabicName})'
                                : qari.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),

            // Debug button to validate current reciter
            if (controller.currentQari.value != null)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.bug_report, size: 18.w),
                      label: Text(
                        'Validate Reciter URL',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () async {
                        if (controller.currentQari.value != null) {
                          final reciter = controller.currentQari.value!;
                          _showValidationDialog(context, reciter.relativePath);
                        }
                      },
                    ),
                    SizedBox(width: 8.w),
                    // Add debug info button
                    ElevatedButton.icon(
                      icon: Icon(Icons.info_outline, size: 18.w),
                      label: Text(
                        'Debug Info',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () {
                        if (controller.currentQari.value != null) {
                          final qari = controller.currentQari.value!;
                          final identifier =
                              "${qari.getFileIdentifier()}_${qari.id}";

                          Get.dialog(
                            AlertDialog(
                              title: Text('Debug Information'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Reciter ID: ${qari.id}'),
                                    Text('Reciter Name: ${qari.name}'),
                                    Text('relativePath: ${qari.relativePath}'),
                                    Divider(),
                                    Text('File Identifier: $identifier'),
                                    Text(
                                      'Download Example: surah_1_$identifier.mp3',
                                    ),
                                    Divider(),
                                    Text(
                                      'Downloaded Files: ${controller.downloadedFiles.length}',
                                    ),
                                    Container(
                                      height: 150,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: EdgeInsets.all(8),
                                      child: ListView.builder(
                                        itemCount:
                                            controller.downloadedFiles.length,
                                        itemBuilder: (context, index) {
                                          return Text(
                                            controller.downloadedFiles[index]
                                                .split('/')
                                                .last,
                                            style: TextStyle(fontSize: 10),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  child: Text('Refresh Files'),
                                  onPressed: () {
                                    controller.loadDownloadedFiles();
                                    Get.back();
                                  },
                                ),
                                TextButton(
                                  child: Text('Close'),
                                  onPressed: () => Get.back(),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildSectionSelector(
    BuildContext context,
    QuranAudioController controller,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Obx(() {
        // Force refresh when needed
        controller.refreshTrigger.value;

        if (controller.isLoadingSections.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.sectionsList.isEmpty) {
          return const SizedBox.shrink();
        }

        // Check if current section exists, but don't update state during build
        final hasCurrentSection = controller.sectionsList.any(
          (section) => section.id == controller.currentSectionId.value,
        );

        // Get the valid section ID to display
        final displaySectionId =
            hasCurrentSection
                ? controller.currentSectionId.value
                : (controller.sectionsList.isNotEmpty
                    ? controller.sectionsList.first.id
                    : 0);

        // If we need to update the current section, do it after the build is complete
        if (!hasCurrentSection && controller.sectionsList.isNotEmpty) {
          // Use Future.microtask to schedule the update after the build phase
          Future.microtask(() {
            controller.setCurrentSection(controller.sectionsList.first.id);
          });
        }

        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  hint: const Text('Select Section'),
                  value: displaySectionId,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      controller.setCurrentSection(newValue);
                    }
                  },
                  items:
                      controller.sectionsList.map<DropdownMenuItem<int>>((
                        Section section,
                      ) {
                        return DropdownMenuItem<int>(
                          value: section.id,
                          child: Text(
                            section.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),

            // Add a test all reciters button
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: TextButton.icon(
                icon: Icon(Icons.check_circle_outline, size: 16.w),
                label: Text(
                  'Test All Reciters',
                  style: TextStyle(fontSize: 12.sp),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  foregroundColor: Theme.of(context).primaryColor,
                ),
                onPressed: () async {
                  _testAllReciters(context);
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSurahList(
    BuildContext context,
    QuranAudioController controller,
  ) {
    return Obx(() {
      // Force refresh
      controller.refreshTrigger.value;

      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.currentQari.value == null) {
        return const Center(child: Text('Please select a reciter'));
      }

      final files = controller.downloadedFiles;
      print("All downloaded files: $files");

      final qariId = controller.currentQari.value!.id.toString();
      final qariPath = controller.currentQari.value!.relativePath;
      final qariName = controller.currentQari.value!.name.toLowerCase();

      // Use an RxList for filtered files to avoid triggering setState during build
      // This filtering should happen outside the build method in a separate operation
      // that's triggered by the controller when needed
      final reciterFiles = controller.getReciterFiles(
        qariId,
        qariPath,
        qariName,
      );

      print("Filtered files for reciter $qariId ($qariPath): $reciterFiles");
      print("File count: ${reciterFiles.length}");

      // All surahs for download section
      final allSurahs = List<int>.generate(114, (index) => index + 1);

      // Build tabs for Downloaded and All Surahs
      return DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              tabs: const [
                Tab(text: 'Downloaded'),
                Tab(text: 'All Downloads'),
                Tab(text: 'All Surahs'),
              ],
              indicatorColor: Theme.of(context).primaryColor,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              isScrollable: true,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildDownloadedSurahs(context, controller, reciterFiles),
                  _buildAllDownloadedSurahs(
                    context,
                    controller,
                    controller.downloadedFiles,
                  ),
                  _buildAllSurahs(context, controller, allSurahs, reciterFiles),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDownloadedSurahs(
    BuildContext context,
    QuranAudioController controller,
    List<String> files,
  ) {
    // Don't sort directly in the build method
    print("Building downloaded surahs view with ${files.length} files");

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              size: 64.w,
              color: Colors.grey,
            ),
            SizedBox(height: 16.h),
            Text(
              'No downloaded surahs for this reciter',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 8.h),
            Text(
              'Go to the "All Surahs" tab to download',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            ),
            // Add a refresh button
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Refresh List'),
              onPressed: () {
                controller.loadDownloadedFiles();
              },
            ),
          ],
        ),
      );
    }

    // Get a sorted copy of the files instead of sorting in place
    final sortedFiles = controller.getSortedDownloadedFiles(files);

    return ListView.builder(
      itemCount: sortedFiles.length,
      itemBuilder: (context, index) {
        final file = sortedFiles[index];
        final filename = file.split('/').last;
        final surahNumber = controller.getSurahNumberFromFilename(filename);

        final surahName = quran.getSurahNameArabic(surahNumber);
        final surahNameEn = quran.getSurahName(surahNumber);

        final isPlaying =
            controller.currentlyPlayingFile.value == file &&
            controller.isPlaying.value;

        return ListTile(
          title: Text(surahNameEn),
          subtitle: Text(surahName),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Text(
              surahNumber.toString(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Theme.of(context).primaryColor,
                  size: 32.w,
                ),
                onPressed: () {
                  if (isPlaying) {
                    controller.pausePlayback();
                  } else {
                    controller.playSurah(file);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => controller.deleteSurah(file),
              ),
            ],
          ),
          onTap: () {
            if (isPlaying) {
              controller.pausePlayback();
            } else {
              controller.playSurah(file);
            }
          },
        );
      },
    );
  }

  Widget _buildAllDownloadedSurahs(
    BuildContext context,
    QuranAudioController controller,
    List<String> files,
  ) {
    // We need to avoid direct sorting during build phase as it causes setState during build
    print("Building ALL downloaded files view with ${files.length} files");

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              size: 64.w,
              color: Colors.grey,
            ),
            SizedBox(height: 16.h),
            Text(
              'No downloaded surahs yet',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 8.h),
            Text(
              'Go to the "All Surahs" tab to download',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            ),
            // Add a refresh button
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Refresh List'),
              onPressed: () {
                controller.loadDownloadedFiles();
              },
            ),
          ],
        ),
      );
    }

    // Get a sorted copy of the files instead of sorting in place
    final sortedFiles = controller.getSortedDownloadedFiles(files);

    return ListView.builder(
      itemCount: sortedFiles.length,
      itemBuilder: (context, index) {
        final file = sortedFiles[index];
        final filename = file.split('/').last;
        final surahNumber = controller.getSurahNumberFromFilename(filename);

        // Extract reciter info from filename for display
        String reciterName = "Unknown";

        // Try to get reciter data using the helper function
        final matchingReciter = controller.getReciterByName(filename);
        if (matchingReciter != null) {
          reciterName = matchingReciter.name;
        } else {
          try {
            // Fallback to parsing the filename if no reciter found
            final parts = filename.split('_');
            if (parts.length >= 3) {
              final reciterIdPart = parts[2].replaceAll('.mp3', '');

              // Make a readable version of the reciter ID
              reciterName = reciterIdPart
                  .replaceAll('_', ' ')
                  .replaceAll('-', ' ')
                  .split(' ')
                  .map(
                    (word) =>
                        word.isNotEmpty
                            ? word[0].toUpperCase() + word.substring(1)
                            : '',
                  )
                  .join(' ');
            }
          } catch (e) {
            print('Error extracting reciter from filename: $e');
          }
        }

        final surahName = quran.getSurahNameArabic(surahNumber);
        final surahNameEn = quran.getSurahName(surahNumber);

        final isPlaying =
            controller.currentlyPlayingFile.value == file &&
            controller.isPlaying.value;

        return ListTile(
          title: Text('$surahNameEn'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(surahName),
              Text(
                'Reciter: $reciterName',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          isThreeLine: true,
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Text(
              surahNumber.toString(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Theme.of(context).primaryColor,
                  size: 32.w,
                ),
                onPressed: () {
                  if (isPlaying) {
                    controller.pausePlayback();
                  } else {
                    controller.playSurah(file);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => controller.deleteSurah(file),
              ),
            ],
          ),
          onTap: () {
            if (isPlaying) {
              controller.pausePlayback();
            } else {
              controller.playSurah(file);
            }
          },
        );
      },
    );
  }

  Widget _buildAllSurahs(
    BuildContext context,
    QuranAudioController controller,
    List<int> allSurahs,
    List<String> downloadedFiles,
  ) {
    // Don't rely on state triggers during build
    print(
      "Building all surahs view with ${downloadedFiles.length} downloaded files",
    );

    return ListView.builder(
      itemCount: allSurahs.length,
      itemBuilder: (context, index) {
        final surahNumber = allSurahs[index];
        final surahName = quran.getSurahNameArabic(surahNumber);
        final surahNameEn = quran.getSurahName(surahNumber);

        // Check if this surah is already downloaded
        final isDownloaded = downloadedFiles.any((path) {
          final fileName = path.split('/').last;
          try {
            final pathSurahNumber = controller.getSurahNumberFromFilename(
              fileName,
            );
            return pathSurahNumber == surahNumber;
          } catch (e) {
            print('Error parsing surah number from $fileName: $e');
            return false;
          }
        });

        // Get the file path if it's downloaded
        String? filePath;
        if (isDownloaded) {
          try {
            filePath = downloadedFiles.firstWhere((path) {
              final fileName = path.split('/').last;
              final pathSurahNumber = controller.getSurahNumberFromFilename(
                fileName,
              );
              return pathSurahNumber == surahNumber;
            });
          } catch (e) {
            print('Error finding path for surah $surahNumber: $e');
          }
        }

        // Check if it's currently downloading
        final isDownloading = controller.downloadQueue.any((filename) {
          return filename.contains(
            'surah_${surahNumber}_${controller.currentQari.value?.id ?? ""}',
          );
        });

        // Get download progress if it's downloading
        double? progress;
        if (isDownloading) {
          final filename = controller.downloadQueue.firstWhere((filename) {
            return filename.contains(
              'surah_${surahNumber}_${controller.currentQari.value?.id ?? ""}',
            );
          });
          progress = controller.downloadProgress[filename] ?? 0.0;
        }

        return ListTile(
          title: Text(surahNameEn),
          subtitle: Text(surahName),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Text(
              surahNumber.toString(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          trailing: _buildDownloadOrPlayButton(
            context,
            controller,
            surahNumber,
            isDownloaded,
            isDownloading,
            progress,
            filePath,
          ),
          onTap: () {
            if (isDownloaded && filePath != null) {
              controller.playSurah(filePath);
            } else if (!isDownloading) {
              controller.downloadSurah(surahNumber);
            }
          },
        );
      },
    );
  }

  Widget _buildDownloadOrPlayButton(
    BuildContext context,
    QuranAudioController controller,
    int surahNumber,
    bool isDownloaded,
    bool isDownloading,
    double? progress,
    String? filePath,
  ) {
    if (isDownloaded) {
      if (filePath != null) {
        final isPlaying =
            controller.currentlyPlayingFile.value == filePath &&
            controller.isPlaying.value;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Theme.of(context).primaryColor,
                size: 32.w,
              ),
              onPressed: () {
                if (isPlaying) {
                  controller.pausePlayback();
                } else {
                  controller.playSurah(filePath);
                }
              },
            ),
            Icon(Icons.download_done, color: Colors.green),
          ],
        );
      }
    } else if (isDownloading) {
      return SizedBox(
        width: 80.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24.w,
              height: 24.w,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2.w,
              ),
            ),
            if (progress != null)
              Text(
                "${(progress * 100).round()}%",
                style: TextStyle(fontSize: 12.sp),
              ),
          ],
        ),
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.download),
        onPressed: () => controller.downloadSurah(surahNumber),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAudioProgressBar(
    BuildContext context,
    QuranAudioController controller,
  ) {
    return Obx(() {
      // Force refresh
      controller.refreshTrigger.value;

      final position = controller.audioPosition.value;
      final duration = controller.audioDuration.value;
      final progress =
          duration.inMilliseconds > 0
              ? position.inMilliseconds / duration.inMilliseconds
              : 0.0;

      return SizedBox(
        height: 36.h,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          child: Row(
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.w),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 12.w),
                    activeTrackColor: Theme.of(context).primaryColor,
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: Theme.of(context).primaryColor,
                    overlayColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.3),
                  ),
                  child: Slider(
                    value: position.inSeconds.toDouble(),
                    max: duration.inSeconds.toDouble(),
                    onChanged: (value) {
                      controller.seekTo(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                _formatDuration(duration),
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMiniPlayer(
    BuildContext context,
    QuranAudioController controller,
  ) {
    return Obx(() {
      // Force refresh
      controller.refreshTrigger.value;

      final mediaItem = controller.currentMediaItem.value;
      final isPlaying = controller.isPlaying.value;
      final hasPrevious = controller.hasPrevious.value;
      final hasNext = controller.hasNext.value;

      final fileName = controller.currentlyPlayingFile.value.split('/').last;
      final surahNumber = controller.getSurahNumberFromFilename(fileName);
      final surahName = quran.getSurahName(surahNumber);
      final surahNameArabic = quran.getSurahNameArabic(surahNumber);

      return Container(
        height: 60.h,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            // Skip previous
            IconButton(
              icon: Icon(
                Icons.skip_previous,
                color: hasPrevious ? Colors.grey[800] : Colors.grey[400],
              ),
              onPressed: hasPrevious ? controller.skipToPrevious : null,
            ),

            // Play/Pause
            IconButton(
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Theme.of(context).primaryColor,
                size: 34.w,
              ),
              onPressed: () {
                if (isPlaying) {
                  controller.pausePlayback();
                } else {
                  controller.resumePlayback();
                }
              },
            ),

            // Skip next
            IconButton(
              icon: Icon(
                Icons.skip_next,
                color: hasNext ? Colors.grey[800] : Colors.grey[400],
              ),
              onPressed: hasNext ? controller.skipToNext : null,
            ),

            // Surah info
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      surahName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      surahNameArabic,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // Loop button
            IconButton(
              icon: Icon(
                controller.isLoopEnabled.value
                    ? Icons.repeat_one
                    : Icons.repeat,
                color:
                    controller.isLoopEnabled.value
                        ? Theme.of(context).primaryColor
                        : Colors.grey[700],
              ),
              onPressed: controller.toggleLoop,
            ),

            // Close button
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey[700]),
              onPressed: () {
                controller.pausePlayback();
                controller.currentlyPlayingFile.value = '';
              },
            ),
          ],
        ),
      );
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  // Method to validate a reciter URL
  void _showValidationDialog(BuildContext context, String reciterId) {
    final QuranAudioController controller = Get.find<QuranAudioController>();

    Get.dialog(
      AlertDialog(
        title: const Text('Validating Reciter'),
        content: FutureBuilder<bool>(
          future: controller.validateReciterUrl(reciterId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: 16.h),
                  const Text('Testing URL...'),
                ],
              );
            }

            final isValid = snapshot.data ?? false;
            final sampleUrl = controller.getPublicAudioUrl(1, reciterId);

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isValid ? Icons.check_circle : Icons.error,
                        color: isValid ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        isValid ? 'URL is valid!' : 'URL is invalid!',
                        style: TextStyle(
                          color: isValid ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    isValid
                        ? 'The reciter URL is valid and accessible.'
                        : 'The reciter URL cannot be accessed. Please check the connection or reciter configuration.',
                  ),
                  SizedBox(height: 16.h),
                  const Text(
                    'URL Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      sampleUrl,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                  if (!isValid) ...[
                    SizedBox(height: 16.h),
                    const Text(
                      'Troubleshooting Tips:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8.h),
                    const Text('1. Check internet connection'),
                    const Text('2. Verify reciter path is correct'),
                    const Text('3. Try a different reciter or surah'),
                  ],
                  // Add option to try different surah for URL testing
                  SizedBox(height: 16.h),
                  const Text(
                    'Try different surah:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          [1, 2, 18, 36, 55, 67, 78, 114]
                              .map(
                                (surahNum) => Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4.w,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _testReciterWithSurah(
                                        context,
                                        reciterId,
                                        surahNum,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 4.h,
                                      ),
                                      minimumSize: Size(40.w, 30.h),
                                    ),
                                    child: Text(
                                      '$surahNum',
                                      style: TextStyle(fontSize: 12.sp),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
          TextButton(
            onPressed: () async {
              final sampleUrl = controller.getPublicAudioUrl(1, reciterId);
              if (await canLaunchUrlString(sampleUrl)) {
                await launchUrlString(sampleUrl);
              } else {
                Get.snackbar(
                  'Error',
                  'Could not launch URL',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('Open in Browser'),
          ),
        ],
      ),
    );
  }

  // Test reciter URL with a specific surah
  void _testReciterWithSurah(
    BuildContext context,
    String reciterId,
    int surahNumber,
  ) {
    final QuranAudioController controller = Get.find<QuranAudioController>();

    Get.dialog(
      AlertDialog(
        title: Text('Testing Surah $surahNumber'),
        content: FutureBuilder<bool>(
          future: controller.validateReciterUrl(
            reciterId,
            surahNumber: surahNumber,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: 16.h),
                  Text('Testing URL for Surah $surahNumber...'),
                ],
              );
            }

            final isValid = snapshot.data ?? false;
            final sampleUrl = controller.getPublicAudioUrl(
              surahNumber,
              reciterId,
            );

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isValid ? Icons.check_circle : Icons.error,
                        color: isValid ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        isValid ? 'URL is valid!' : 'URL is invalid!',
                        style: TextStyle(
                          color: isValid ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Surah tested: $surahNumber (${quran.getSurahName(surahNumber)})',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.h),
                  const Text(
                    'URL Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      sampleUrl,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
          TextButton(
            onPressed: () => _showValidationDialog(context, reciterId),
            child: const Text('Back to Main'),
          ),
          TextButton(
            onPressed: () async {
              final sampleUrl = controller.getPublicAudioUrl(
                surahNumber,
                reciterId,
              );
              if (await canLaunchUrlString(sampleUrl)) {
                await launchUrlString(sampleUrl);
              } else {
                Get.snackbar(
                  'Error',
                  'Could not launch URL',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('Open in Browser'),
          ),
        ],
      ),
    );
  }

  // Method to test all reciters and show results
  void _testAllReciters(BuildContext context) {
    final QuranAudioController controller = Get.find<QuranAudioController>();

    Get.dialog(
      AlertDialog(
        title: const Text('Testing All Reciters'),
        content: FutureBuilder<Map<String, bool>>(
          future: controller.validateAllReciters(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: 16.h),
                  const Text('This may take a moment...'),
                ],
              );
            }

            final results = snapshot.data!;
            final validCount = results.values.where((valid) => valid).length;
            final totalCount = results.length;

            return SizedBox(
              width: double.maxFinite,
              height: 300.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Valid Reciters: $validCount / $totalCount',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView(
                      children:
                          results.entries.map((entry) {
                            return ListTile(
                              leading: Icon(
                                entry.value ? Icons.check_circle : Icons.error,
                                color: entry.value ? Colors.green : Colors.red,
                              ),
                              title: Text(entry.key),
                              subtitle: Text(entry.value ? 'Valid' : 'Invalid'),
                              dense: true,
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
        ],
      ),
    );
  }
}
