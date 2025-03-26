// quran_audio_controller.dart
import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;

class QuranAudioController extends GetxController {
  final player = AudioPlayer();
  var currentReciter = "".obs;
  // RxMap and RxList automatically notify listeners when updated.
  var downloadProgress = <String, double>{}.obs;
  var isPlaying = false.obs;
  var currentlyPlayingFile = "".obs;
  var isLoopEnabled = false.obs;
  var downloadQueue = <String>[].obs;
  var downloadedFiles = <String>[].obs;
  var isLoading = false.obs;
  var errorMsg = "".obs;
  var audioDuration = Duration.zero.obs;
  var audioPosition = Duration.zero.obs;
  // Add a trigger for UI refreshes
  var refreshTrigger = 0.obs;

  // Force UI refresh
  void forceRefresh() {
    refreshTrigger.value++;
    update(); // Ensure GetBuilder widgets update too
  }

  @override
  void onInit() {
    super.onInit();
    _setupAudioSession();
    _setupAudioPlayer();
    loadDownloadedFiles();

    // Refresh the downloaded files when the reciter changes.
    ever(currentReciter, (_) {
      loadDownloadedFiles();
      forceRefresh();
    });

    // Refresh UI when playback state changes
    ever(isPlaying, (_) => forceRefresh());
    ever(currentlyPlayingFile, (_) => forceRefresh());
  }

  @override
  void onClose() {
    player.dispose();
    super.onClose();
  }

  void _setupAudioPlayer() {
    player.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      if (state.processingState == ProcessingState.completed) {
        isPlaying.value = false;
        audioPosition.value = Duration.zero;
      }
      forceRefresh(); // Force refresh on player state change
    });

    player.positionStream.listen((position) {
      audioPosition.value = position;
      // Only force refresh every second to avoid too many updates
      if (position.inMilliseconds % 1000 < 50) {
        forceRefresh();
      }
    });

    player.durationStream.listen((duration) {
      audioDuration.value = duration ?? Duration.zero;
      forceRefresh(); // Force refresh when duration changes
    });

    player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        print('A stream error occurred: $e');
        errorMsg.value = 'Audio playback error: $e';
        forceRefresh(); // Force refresh on error
      },
    );
  }

  Future<void> _setupAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );
    } catch (e) {
      errorMsg.value = 'Failed to setup audio session: $e';
    }
  }

  Future<void> loadDownloadedFiles() async {
    try {
      isLoading.value = true;
      forceRefresh(); // Force refresh when starting to load

      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/quran_audio');
      if (!await audioDir.exists()) {
        await audioDir.create();
      }
      final files = await audioDir.list().toList();
      downloadedFiles.value = files.map((f) => f.path).toList();
      print('Loaded downloaded files: $downloadedFiles');
    } catch (e) {
      errorMsg.value = 'Failed to load downloaded files: $e';
      print('Error loading files: $e');
    } finally {
      isLoading.value = false;
      forceRefresh(); // Force refresh after loading completes
    }
  }

  String _getAudioUrl(int surahNumber, String reciterIdentifier) {
    final cleanReciterId = reciterIdentifier.replaceAll('ar.', '');
    final paddedNumber = surahNumber.toString().padLeft(3, '0');
    return 'https://download.quranicaudio.com/quran/$cleanReciterId/$paddedNumber.mp3';
  }

  Future<void> downloadSurah(int surahNumber, String reciterIdentifier) async {
    if (reciterIdentifier.isEmpty) {
      Get.snackbar('Error', 'Please select a reciter first');
      return;
    }

    final filename = 'surah_${surahNumber}_$reciterIdentifier.mp3';
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/quran_audio');
    if (!await audioDir.exists()) {
      await audioDir.create();
    }
    final file = File('${audioDir.path}/$filename');

    if (await file.exists()) {
      Get.snackbar('Already Downloaded', 'This surah is already downloaded');
      return;
    }

    try {
      downloadQueue.add(filename);
      forceRefresh(); // Force refresh when adding to queue

      final url = _getAudioUrl(surahNumber, reciterIdentifier);
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw 'Failed to download: Server returned ${response.statusCode}';
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;
      final sink = file.openWrite();

      // Initialize progress for this file.
      downloadProgress[filename] = 0.0;
      forceRefresh(); // Force refresh when initializing progress

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          downloadProgress[filename] = downloaded / contentLength;
          // Update progress every 5% to avoid too many UI updates
          if ((downloaded / contentLength * 100) % 5 < 0.5) {
            forceRefresh();
          }
        }
      }

      await sink.close();

      // Remove progress and queue entry.
      downloadProgress.remove(filename);
      downloadQueue.remove(filename);

      // Add the downloaded file to the list.
      downloadedFiles.add(file.path);
      forceRefresh(); // Force refresh after download completes

      Get.snackbar('Success', 'Surah downloaded successfully');
    } catch (e) {
      errorMsg.value = 'Download failed: $e';
      Get.snackbar('Error', 'Failed to download surah: $e');
      downloadProgress.remove(filename);
      if (await file.exists()) {
        await file.delete();
      }
    } finally {
      downloadQueue.remove(filename);
      forceRefresh(); // Force refresh after cleanup
    }
  }

  Future<void> playSurah(String filePath) async {
    try {
      if (currentlyPlayingFile.value == filePath && isPlaying.value) {
        await pausePlayback();
        return;
      }

      if (currentlyPlayingFile.value != filePath) {
        await player.stop();
        await player.setFilePath(filePath);
        currentlyPlayingFile.value = filePath;
        forceRefresh(); // Force refresh when changing file
      }

      await player.play();
      isPlaying.value = true;
      forceRefresh(); // Force refresh when starting playback
    } catch (e) {
      errorMsg.value = 'Playback failed: $e';
      Get.snackbar('Error', 'Failed to play audio: $e');
    }
  }

  void seekTo(Duration position) {
    player.seek(position);
    forceRefresh(); // Force refresh when seeking
  }

  void toggleLoop() {
    isLoopEnabled.value = !isLoopEnabled.value;
    player.setLoopMode(isLoopEnabled.value ? LoopMode.one : LoopMode.off);
    forceRefresh(); // Force refresh when toggling loop
  }

  Future<void> pausePlayback() async {
    try {
      await player.pause();
      isPlaying.value = false;
      forceRefresh(); // Force refresh when pausing
    } catch (e) {
      errorMsg.value = 'Failed to pause: $e';
    }
  }

  Future<void> resumePlayback() async {
    try {
      await player.play();
      isPlaying.value = true;
      forceRefresh(); // Force refresh when resuming
    } catch (e) {
      errorMsg.value = 'Failed to resume: $e';
      Get.snackbar('Error', 'Failed to resume playback: $e');
    }
  }

  Future<void> deleteSurah(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        if (currentlyPlayingFile.value == filePath) {
          await player.stop();
          currentlyPlayingFile.value = "";
          isPlaying.value = false;
        }
        await file.delete();
        downloadedFiles.remove(filePath);
        forceRefresh(); // Force refresh after deletion
        Get.snackbar('Success', 'Surah deleted successfully');
      }
    } catch (e) {
      errorMsg.value = 'Failed to delete: $e';
      Get.snackbar('Error', 'Failed to delete surah: $e');
    }
  }

  String getFullPath(String filename) {
    final dir =
        downloadedFiles.isNotEmpty
            ? downloadedFiles.first.substring(
              0,
              downloadedFiles.first.lastIndexOf('/'),
            )
            : '';
    return '$dir/$filename';
  }
}
