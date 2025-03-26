// quran_audio_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quranapp/controllers/quran_audio_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuranAudioPage extends StatelessWidget {
  QuranAudioPage({super.key});

  final QuranAudioController controller = Get.put(QuranAudioController());

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Recitations'),
        actions: [
          Obx(
            () => IconButton(
              icon: Icon(
                controller.isLoopEnabled.value
                    ? Icons.repeat_one
                    : Icons.repeat,
              ),
              onPressed: controller.toggleLoop,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildReciterSelector(),
          Expanded(child: _buildSurahList()),
          _buildAudioProgressBar(),
          _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildReciterSelector() {
    return Padding(
      padding: EdgeInsets.all(8.0.w),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
        child: Obx(() {
          // Use refreshTrigger to force rebuild when needed
          final _ = controller.refreshTrigger.value;

          final currentValue = controller.currentReciter.value;
          final List<Map<String, dynamic>> reciters =
              List<Map<String, dynamic>>.from(quran.getReciters());

          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: currentValue.isEmpty ? null : currentValue,
              hint: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: const Text('Select Reciter'),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              items:
                  reciters.map((reciter) {
                    return DropdownMenuItem<String>(
                      value: reciter['identifier'] as String,
                      child: Text(reciter['englishName'] as String),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  controller.currentReciter.value = value;
                }
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSurahList() {
    return Obx(() {
      final currentReciter = controller.currentReciter.value;
      final downloadedFiles = controller.downloadedFiles;
      final downloadQueue = controller.downloadQueue;
      final downloadProgress = controller.downloadProgress;
      final currentlyPlayingFile = controller.currentlyPlayingFile.value;
      final isPlaying = controller.isPlaying.value;
      // Use refreshTrigger to force rebuild when needed
      final _ = controller.refreshTrigger.value;

      return ListView.builder(
        itemCount: 114,
        itemBuilder: (context, index) {
          final surahNumber = index + 1;
          final filename = 'surah_${surahNumber}_$currentReciter.mp3';
          final fullPath = controller.getFullPath(filename);

          final isDownloaded = downloadedFiles.contains(fullPath);
          final isQueued = downloadQueue.contains(filename);
          final isCurrentlyPlaying = currentlyPlayingFile == fullPath;
          final progress = downloadProgress[filename];

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isDownloaded ? Colors.green : Colors.grey[200],
                child:
                    isDownloaded
                        ? const Icon(Icons.check, color: Colors.white)
                        : Text(surahNumber.toString()),
              ),
              title: Text(
                '${surahNumber.toString().padLeft(3, '0')}. ${quran.getSurahNameEnglish(surahNumber)}',
                style: TextStyle(
                  fontWeight:
                      isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal,
                  color:
                      isCurrentlyPlaying
                          ? Theme.of(context).primaryColor
                          : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quran.getSurahNameArabic(surahNumber),
                    style: TextStyle(fontFamily: 'uthmanic', fontSize: 16.sp),
                  ),
                  const SizedBox(height: 4),
                  if (progress != null)
                    SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              trailing:
                  isDownloaded
                      ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isCurrentlyPlaying
                                  ? (isPlaying ? Icons.pause : Icons.play_arrow)
                                  : Icons.play_arrow,
                              color:
                                  isCurrentlyPlaying
                                      ? Theme.of(context).primaryColor
                                      : null,
                            ),
                            onPressed: () {
                              if (isCurrentlyPlaying && isPlaying) {
                                controller.pausePlayback();
                              } else if (isCurrentlyPlaying && !isPlaying) {
                                controller.resumePlayback();
                              } else {
                                controller.playSurah(fullPath);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              controller.deleteSurah(fullPath);
                            },
                          ),
                        ],
                      )
                      : Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isQueued || progress != null)
                            SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed:
                                  currentReciter.isEmpty
                                      ? null
                                      : () {
                                        controller.downloadSurah(
                                          surahNumber,
                                          currentReciter,
                                        );
                                      },
                            ),
                        ],
                      ),
            ),
          );
        },
      );
    });
  }

  Widget _buildAudioProgressBar() {
    return Obx(() {
      // Use refreshTrigger to force rebuild when needed
      final _ = controller.refreshTrigger.value;

      if (controller.currentlyPlayingFile.value.isEmpty) {
        return const SizedBox(height: 4);
      }

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        child: Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(Get.context!).copyWith(
                trackHeight: 4.0,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.w),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 16.w),
                activeTrackColor: Get.theme.primaryColor,
                inactiveTrackColor: Colors.grey[300],
                thumbColor: Get.theme.primaryColor,
                overlayColor: Get.theme.primaryColor.withOpacity(0.3),
              ),
              child: Slider(
                value: controller.audioPosition.value.inSeconds.toDouble(),
                max: controller.audioDuration.value.inSeconds.toDouble(),
                onChanged: (value) {
                  controller.seekTo(Duration(seconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(controller.audioPosition.value)),
                  Text(_formatDuration(controller.audioDuration.value)),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMiniPlayer() {
    return Obx(() {
      // Use refreshTrigger to force rebuild when needed
      final _ = controller.refreshTrigger.value;

      if (controller.currentlyPlayingFile.value.isEmpty) {
        return const SizedBox.shrink();
      }

      final filename = controller.currentlyPlayingFile.value.split('/').last;
      final surahNumber = int.parse(filename.split('_')[1]);

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        color: Colors.grey[200],
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    quran.getSurahNameEnglish(surahNumber),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  Text(
                    quran.getSurahNameArabic(surahNumber),
                    style: TextStyle(fontFamily: 'uthmanic', fontSize: 14.sp),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                controller.isPlaying.value ? Icons.pause : Icons.play_arrow,
                color: Get.theme.primaryColor,
              ),
              onPressed: () {
                if (controller.isPlaying.value) {
                  controller.pausePlayback();
                } else {
                  controller.resumePlayback();
                }
              },
            ),
          ],
        ),
      );
    });
  }
}
