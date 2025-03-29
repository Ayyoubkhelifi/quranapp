import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quranapp/controllers/quran_audio_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audio_service/audio_service.dart';

class PersistentAudioPlayerBar extends StatelessWidget {
  final QuranAudioController controller;
  final bool isMinimized;
  final VoidCallback? onTap;

  const PersistentAudioPlayerBar({
    Key? key,
    required this.controller,
    this.isMinimized = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Check if we have a currently playing file
      if (controller.currentlyPlayingFile.value.isEmpty) {
        return const SizedBox.shrink();
      }

      final mediaItem = controller.currentMediaItem.value;
      final isPlaying = controller.isPlaying.value;
      final hasPrevious = controller.hasPrevious.value;
      final hasNext = controller.hasNext.value;

      // Calculate progress as a value between 0.0 and 1.0
      final duration = controller.audioDuration.value.inMilliseconds;
      final position = controller.audioPosition.value.inMilliseconds;
      final progress = duration > 0 ? position / duration : 0.0;

      // Return a minimized player if requested
      if (isMinimized) {
        return _buildMinimizedPlayer(context, mediaItem, isPlaying, progress);
      }

      // Return the full-sized player
      return _buildFullPlayer(
        context,
        mediaItem,
        isPlaying,
        progress,
        hasPrevious,
        hasNext,
      );
    });
  }

  // Minimized player bar that appears at the bottom of other screens
  Widget _buildMinimizedPlayer(
    BuildContext context,
    MediaItem? mediaItem,
    bool isPlaying,
    double progress,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60.h,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
              minHeight: 2.h,
            ),
            // Player content
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    // Surah info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mediaItem?.title ?? 'Unknown Surah',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            mediaItem?.artist ?? '',
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
                    // Controls
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        if (isPlaying) {
                          controller.pausePlayback();
                        } else {
                          controller.resumePlayback();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.pausePlayback();
                        controller.currentlyPlayingFile.value = '';
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Full-sized player with more controls
  Widget _buildFullPlayer(
    BuildContext context,
    MediaItem? mediaItem,
    bool isPlaying,
    double progress,
    bool hasPrevious,
    bool hasNext,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar with time indicators
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.w),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 16.w),
                    activeTrackColor: Theme.of(context).primaryColor,
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: Theme.of(context).primaryColor,
                    overlayColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.3),
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
          ),

          // Title and Reciter
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
            child: Column(
              children: [
                Text(
                  mediaItem?.title ?? 'Unknown Surah',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4.h),
                Text(
                  mediaItem?.displayDescription ?? '',
                  style: TextStyle(
                    fontFamily: 'uthmanic',
                    fontSize: 16.sp,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4.h),
                Text(
                  mediaItem?.artist ?? '',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Playback controls
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Loop button
                Obx(
                  () => IconButton(
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
                ),

                // Previous button
                IconButton(
                  icon: Icon(
                    Icons.skip_previous,
                    color: hasPrevious ? Colors.grey[800] : Colors.grey[400],
                    size: 36.w,
                  ),
                  onPressed: hasPrevious ? controller.skipToPrevious : null,
                ),

                // Play/Pause button
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 36.w,
                    ),
                    onPressed: () {
                      if (isPlaying) {
                        controller.pausePlayback();
                      } else {
                        controller.resumePlayback();
                      }
                    },
                  ),
                ),

                // Next button
                IconButton(
                  icon: Icon(
                    Icons.skip_next,
                    color: hasNext ? Colors.grey[800] : Colors.grey[400],
                    size: 36.w,
                  ),
                  onPressed: hasNext ? controller.skipToNext : null,
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
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }
}
