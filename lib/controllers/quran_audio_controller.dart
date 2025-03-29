// quran_audio_controller.dart
import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import 'package:quranapp/models/qari.dart';
import 'package:quranapp/models/section.dart';
import 'package:quranapp/models/surah.dart';
import 'package:audio_service/audio_service.dart';
import 'package:quran/quran.dart' as quran;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class QuranAudioController extends GetxController {
  // Core audio player
  final player = AudioPlayer();

  // Observable state variables
  var currentReciter = "".obs;
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
  var currentQari = Rx<Qari?>(null);
  var qarisList = <Qari>[].obs;
  var isLoadingQaris = false.obs;
  var filterBySection = false.obs;
  var sectionsList = <Section>[].obs;
  var isLoadingSections = false.obs;
  var currentSectionId = 0.obs;
  var hasPrevious = false.obs;
  var hasNext = false.obs;
  var currentMediaItem = Rx<MediaItem?>(null);
  var refreshTrigger = 0.obs;
  var surahsList = <Surah>[].obs;
  var isLoadingSurahs = false.obs;

  // New properties for enhanced functionality
  var isCaching = false.obs;
  var playbackSpeed = 1.0.obs;
  var isBackgroundPlayEnabled = true.obs;
  var lastPlayedSurah = "".obs;
  var favoriteSurahs = <String>[].obs;

  // Timers and state
  Timer? _positionUpdateTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _wasPlayingBeforeInterruption = false;

  // Directory cache
  String? _audioDir;

  // Add buffer management
  static const int maxBufferSize = 5 * 1024 * 1024; // 5MB buffer size
  var isBuffering = false.obs;
  Timer? _bufferTimer;

  // Force UI refresh
  void forceRefresh() {
    refreshTrigger.value++;
    update();
  }

  @override
  void onInit() {
    super.onInit();

    // Setup with error handling
    _initializeResources();

    // Load the last played surah
    _loadLastPlayedSurah();
    _loadFavoriteSurahs();

    // Setup listeners
    _setupObservers();

    // Monitor connectivity
    _setupConnectivityMonitor();

    _initializeBufferManagement();
  }

  Future<void> _initializeResources() async {
    try {
      await _setupAudioSession();
      _setupAudioPlayer();

      // Parallel initialization
      await Future.wait([
        loadDownloadedFiles(),
        loadQarisList(),
        loadSectionsList(),
      ]);
    } catch (e) {
      errorMsg.value = 'Initialization error: $e';
      print('Error initializing resources: $e');
    }
  }

  void _setupObservers() {
    // Refresh the downloaded files when the reciter changes
    ever(currentReciter, (_) => loadDownloadedFiles());

    // Refresh UI when playback state changes
    ever(isPlaying, (playing) {
      forceRefresh();
      _handlePlaybackStateChange(playing);
    });

    ever(currentlyPlayingFile, (_) => forceRefresh());
    ever(currentQari, (_) => forceRefresh());

    // Auto-update navigation flags when files change
    ever(downloadedFiles, (_) {
      if (currentlyPlayingFile.value.isNotEmpty) {
        updateNavigationFlags();
      }
    });

    // Handle playback speed changes
    ever(playbackSpeed, (speed) => _updatePlaybackSpeed(speed));
  }

  void _handlePlaybackStateChange(bool isPlaying) {
    // Keep screen on during playback
    if (isPlaying) {
      try {
        WakelockPlus.enable().catchError((_) {
          // Silently handle wakelock errors
          print('Could not enable wakelock - no foreground activity');
        });
      } catch (e) {
        print('Error enabling wakelock: $e');
      }
    } else {
      try {
        WakelockPlus.disable().catchError((_) {
          // Silently handle wakelock errors
          print('Could not disable wakelock - no foreground activity');
        });
      } catch (e) {
        print('Error disabling wakelock: $e');
      }
    }
  }

  Future<void> _loadLastPlayedSurah() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPlayed = prefs.getString('last_played_surah') ?? '';

      if (lastPlayed.isNotEmpty) {
        lastPlayedSurah.value = lastPlayed;
      }
    } catch (e) {
      print('Error loading last played surah: $e');
    }
  }

  Future<void> _saveLastPlayedSurah(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_played_surah', filePath);

      // Also save the position
      final position = await player.position;
      await prefs.setInt('last_played_position', position.inMilliseconds);

      // Save the current reciter ID directly
      if (currentQari.value != null) {
        await prefs.setInt('last_qari_id', currentQari.value!.id);
        await prefs.setString(
          'last_qari_path',
          currentQari.value!.relativePath,
        );
        print(
          'Saved current reciter info - ID: ${currentQari.value!.id}, Path: ${currentQari.value!.relativePath}',
        );
      }

      // Extract info from filename as backup
      final filename = filePath.split('/').last;
      final parts = filename.split('_');
      if (parts.length >= 3) {
        final fileReciterId = parts[2].replaceAll('.mp3', '');
        await prefs.setString('last_file_reciter_id', fileReciterId);
        print('Saved file-based reciter identifier: $fileReciterId');
      }

      print(
        'Saved last played surah: $filePath at position ${position.inMilliseconds}ms',
      );
    } catch (e) {
      print('Error saving last played surah: $e');
    }
  }

  Future<void> _loadFavoriteSurahs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_surahs') ?? [];
      favoriteSurahs.value = favorites;
    } catch (e) {
      print('Error loading favorite surahs: $e');
    }
  }

  Future<void> toggleFavoriteSurah(String filePath) async {
    try {
      if (favoriteSurahs.contains(filePath)) {
        favoriteSurahs.remove(filePath);
      } else {
        favoriteSurahs.add(filePath);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_surahs', favoriteSurahs);

      forceRefresh();
      Get.snackbar(
        'Success',
        favoriteSurahs.contains(filePath)
            ? 'Surah added to favorites'
            : 'Surah removed from favorites',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      errorMsg.value = 'Failed to update favorites: $e';
      Get.snackbar('Error', 'Failed to update favorites');
    }
  }

  bool isSurahFavorite(String filePath) {
    return favoriteSurahs.contains(filePath);
  }

  void _setupConnectivityMonitor() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      if (isPlaying.value) {
        _wasPlayingBeforeInterruption = true;
      }
    } else if (_wasPlayingBeforeInterruption) {
      _wasPlayingBeforeInterruption = false;
      // Wait a bit to make sure connection is stable
      Future.delayed(const Duration(seconds: 1), resumePlayback);
    }
  }

  void _updatePlaybackSpeed(double speed) {
    if (player.playing) {
      player.setSpeed(speed);
    }
  }

  @override
  void onClose() {
    try {
      WakelockPlus.disable().catchError((_) {
        // Silently handle wakelock errors
        print('Could not disable wakelock - no foreground activity');
      });
    } catch (e) {
      print('Error disabling wakelock: $e');
    }
    _positionUpdateTimer?.cancel();
    _connectivitySubscription?.cancel();
    player.stop();
    player.dispose();
    _bufferTimer?.cancel();
    super.onClose();
  }

  Future<String> _getAudioDirectory() async {
    if (_audioDir != null) return _audioDir!;

    final dir = await getApplicationDocumentsDirectory();
    final audioDir = '${dir.path}/quran_audio';

    // Ensure directory exists
    final directory = Directory(audioDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    _audioDir = audioDir;
    return audioDir;
  }

  Future<void> loadDownloadedFiles() async {
    try {
      isLoading.value = true;
      forceRefresh();

      final audioDir = await _getAudioDirectory();
      final dir = Directory(audioDir);

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final List<FileSystemEntity> files =
          await dir.list().where((file) => file.path.endsWith('.mp3')).toList();

      downloadedFiles.value = files.map((file) => file.path).toList();
      print('Loaded ${downloadedFiles.length} downloaded files');

      // If we have a current reciter, update the filtered files too
      // This prevents the setState during build error when changing reciters
      if (currentQari.value != null) {
        final qari = currentQari.value!;
        _updateFilteredFiles(
          qari.id.toString(),
          qari.relativePath,
          qari.name.toLowerCase(),
        );
      }

      // Force UI update
      forceRefresh();
    } catch (e) {
      errorMsg.value = 'Error loading downloaded files: $e';
      print('Error loading downloaded files: $e');
    } finally {
      isLoading.value = false;
      forceRefresh();
    }
  }

  // Update filtered files when reciter changes - called outside of build
  void _updateFilteredFiles(String qariId, String qariPath, String qariName) {
    // This is called separately from the build method to prevent setState during build
    getReciterFiles(qariId, qariPath, qariName);
  }

  // Set current reciter with proper update
  void setCurrentReciter(Qari reciter) {
    currentQari.value = reciter;
    // Update filtered files to prevent setState during build
    _updateFilteredFiles(
      reciter.id.toString(),
      reciter.relativePath,
      reciter.name.toLowerCase(),
    );
    forceRefresh();
  }

  Future<void> _downloadSurahWithReciter(
    int surahNumber,
    String reciterIdentifier, {
    bool showNotifications = true,
  }) async {
    if (reciterIdentifier.isEmpty) {
      if (showNotifications) {
        Get.snackbar('Error', 'Please select a reciter first');
      }
      return;
    }

    // Clean up identifier for consistent filename format
    // Remove trailing slash if present
    final cleanIdentifier =
        reciterIdentifier.endsWith('/')
            ? reciterIdentifier.substring(0, reciterIdentifier.length - 1)
            : reciterIdentifier;

    // Format: surah_NUMBER_RECITERID where RECITERID is consistent with our filtering
    final filename = 'surah_${surahNumber}_$cleanIdentifier.mp3';
    final audioDir = await _getAudioDirectory();
    final file = File('$audioDir/$filename');

    print(
      'Preparing to download surah $surahNumber with reciter $cleanIdentifier',
    );
    print('Filename: $filename');

    if (await file.exists()) {
      if (showNotifications) {
        Get.snackbar('Already Downloaded', 'This surah is already downloaded');
      }
      return;
    }

    try {
      downloadQueue.add(filename);
      forceRefresh();

      final url = _getAudioUrl(surahNumber, reciterIdentifier);
      print('Downloading from URL: $url');
      print('Saving to: ${file.path}');

      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client()
          .send(request)
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              throw 'Download timed out. Please check your connection and try again.';
            },
          );

      if (response.statusCode != 200) {
        throw 'Failed to download: Server returned ${response.statusCode}';
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;
      final sink = file.openWrite();

      // Initialize progress for this file.
      downloadProgress[filename] = 0.0;
      forceRefresh();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          downloadProgress[filename] = downloaded / contentLength;
          // Only update UI every 5% to improve performance
          if ((downloaded / contentLength * 100) % 5 < 0.5) {
            forceRefresh();
          }
        }
      }

      await sink.close();

      // Remove progress and queue entry.
      downloadProgress.remove(filename);
      downloadQueue.remove(filename);

      print('File saved successfully: ${file.path}');

      // Verify the file exists
      final fileExists = await file.exists();
      final fileSize = await file.length();
      print('File exists: $fileExists, size: $fileSize bytes');

      // Add the downloaded file to the list.
      if (fileExists && fileSize > 0) {
        if (!downloadedFiles.contains(file.path)) {
          downloadedFiles.add(file.path);
          print('Added to downloadedFiles list: ${file.path}');

          // Create media item for the downloaded file
          _createMediaItemForFile(file.path);
        }

        // Sort downloaded files by surah number for better navigation
        _sortDownloadedFiles();
      } else {
        print('File verification failed. Exists: $fileExists, Size: $fileSize');
      }

      // Force update UI
      forceRefresh();

      if (showNotifications) {
        Get.snackbar('Success', 'Surah downloaded successfully');
      }

      // Reload the list to ensure it's up to date
      await loadDownloadedFiles();
    } catch (e) {
      errorMsg.value = 'Download failed: $e';
      print('Download error: $e');
      if (showNotifications) {
        Get.snackbar('Error', 'Failed to download surah: $e');
      }
      downloadProgress.remove(filename);
      downloadQueue.remove(filename);
      if (await file.exists()) {
        await file.delete();
      }
    } finally {
      downloadQueue.remove(filename);
      forceRefresh();
    }
  }

  Future<void> playSurah(String filePath) async {
    try {
      if (!await File(filePath).exists()) {
        errorMsg.value = 'Audio file not found';
        return;
      }

      // Cancel any existing buffer timer
      _bufferTimer?.cancel();

      // Update current media item before starting playback
      _updateMediaItem(filePath);

      // Save as last played
      _saveLastPlayedSurah(filePath);

      // Set up new audio source with retry mechanism
      await player
          .setAudioSource(AudioSource.file(filePath), preload: true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Loading audio timed out');
            },
          );

      // Start playback
      await player.play();
      isPlaying.value = true;
      currentlyPlayingFile.value = filePath;

      // Update UI and manage wake lock
      _updatePlaybackStatus(true);
      _manageWakeLock(true);

      // Update navigation flags
      updateNavigationFlags();

      // Start buffer management
      _startBufferManagement();
    } catch (e) {
      // Attempt recovery
      await _handlePlaybackError(filePath, e);
    }
  }

  void _createMediaItemForFile(String filePath) {
    try {
      final filename = filePath.split('/').last;
      final surahNumber = getSurahNumberFromFilename(filename);

      // Get surah information
      final surahName = quran.getSurahName(surahNumber);
      final surahNameArabic = quran.getSurahNameArabic(surahNumber);
      final reciterName = currentQari.value?.name ?? "Unknown Reciter";

      final mediaItem = MediaItem(
        id: filePath,
        title: surahName,
        artist: reciterName,
        displayDescription: surahNameArabic,
        artUri: Uri.parse('asset:///assets/images/quran_icon.png'),
        playable: true,
      );

      print('Created media item for $filePath: $surahName by $reciterName');
    } catch (e) {
      print('Error creating media item: $e');
    }
  }

  void _updateMediaItem(String filePath) {
    try {
      final filename = filePath.split('/').last;
      final surahNumber = getSurahNumberFromFilename(filename);

      // Get surah information
      final surahName = quran.getSurahName(surahNumber);
      final surahNameArabic = quran.getSurahNameArabic(surahNumber);

      // Get reciter information
      String reciterName = "Unknown Reciter";
      if (currentQari.value != null) {
        reciterName = currentQari.value!.name;
      } else {
        // Try to extract reciter ID from filename
        final parts = filename.split('_');
        if (parts.length >= 3) {
          final reciterId = parts[2].replaceAll('.mp3', '');
          // Find reciter by ID or relativePath
          final matchingReciter = qarisList.firstWhereOrNull(
            (r) => r.relativePath == reciterId,
          );
          if (matchingReciter != null) {
            reciterName = matchingReciter.name;
          }
        }
      }

      final mediaItem = MediaItem(
        id: filePath,
        title: surahName,
        artist: reciterName,
        album: "Quran Recitation",
        displayTitle: "Surah $surahNumber: $surahName",
        displaySubtitle: reciterName,
        displayDescription: surahNameArabic,
        artUri: Uri.parse('asset:///assets/images/quran_icon.png'),
      );

      // Update current media item locally
      currentMediaItem.value = mediaItem;

      // If using audio service, update the media item there too
      // AudioService.updateMediaItem(mediaItem); // Commented out as it's causing errors

      print('Updated media item for $filePath: $surahName by $reciterName');
    } catch (e) {
      print('Error updating media item: $e');
    }
  }

  Future<void> _handlePlaybackError(String filePath, dynamic error) async {
    debugPrint('Playback error: $error');
    errorMsg.value = 'Error playing audio: $error';

    // Wait a bit before retry
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Attempt to recover by resetting and trying again
      await player.stop();
      await player.setAudioSource(AudioSource.file(filePath));
      await player.play();
      isPlaying.value = true;
      currentlyPlayingFile.value = filePath;
      _updatePlaybackStatus(true);
    } catch (retryError) {
      debugPrint('Recovery attempt failed: $retryError');
      errorMsg.value = 'Playback recovery failed';
      _updatePlaybackStatus(false);
    }
  }

  // Other existing methods...

  Future<void> playLastSurah() async {
    if (lastPlayedSurah.value.isNotEmpty) {
      final file = File(lastPlayedSurah.value);
      if (await file.exists()) {
        await playSurah(lastPlayedSurah.value);
      } else {
        Get.snackbar('Error', 'Last played surah not found');
        lastPlayedSurah.value = '';
      }
    } else {
      Get.snackbar('Info', 'No recently played surah');
    }
  }

  Future<void> downloadAllSurahs() async {
    if (currentQari.value == null) {
      Get.snackbar('Error', 'Please select a reciter first');
      return;
    }

    // Check connectivity
    if (!await _checkConnectivity()) {
      Get.snackbar(
        'No Connection',
        'Please check your internet connection and try again',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Confirm with user
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Download All Surahs'),
        content: const Text(
          'This will download all 114 surahs and may use significant storage and data. Continue?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Get.back(result: false),
          ),
          TextButton(
            child: const Text('Download'),
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );

    if (result != true) return;

    // Start bulk download
    isCaching.value = true;

    try {
      // Download surahs in batches to avoid overloading
      const batchSize = 5;
      for (int i = 1; i <= 114; i += batchSize) {
        final batch = List.generate(
          batchSize,
          (index) => i + index,
        ).where((num) => num <= 114);

        await Future.wait(
          batch.map(
            (surahNum) => _downloadSurahWithReciter(
              surahNum,
              currentQari.value!.relativePath,
              showNotifications: false,
            ),
          ),
        );
      }

      Get.snackbar(
        'Success',
        'All surahs downloaded successfully',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to download all surahs: $e');
    } finally {
      isCaching.value = false;
    }
  }

  void setPlaybackSpeed(double speed) {
    if (speed >= 0.5 && speed <= 2.0) {
      playbackSpeed.value = speed;
      player.setSpeed(speed);
      forceRefresh();

      Get.snackbar(
        'Playback Speed',
        'Speed set to ${speed}x',
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> shareAudioFile(String filePath) async {
    try {
      // You would implement sharing functionality here using a sharing package
      // such as share_plus
      Get.snackbar(
        'Coming Soon',
        'Sharing functionality will be available soon',
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to share audio file: $e');
    }
  }

  Future<bool> exportAudioFile(String filePath, String destinationPath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final fileName = filePath.split('/').last;
        final destination = '$destinationPath/$fileName';
        await file.copy(destination);
        return true;
      }
      return false;
    } catch (e) {
      errorMsg.value = 'Failed to export audio: $e';
      return false;
    }
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
          androidWillPauseWhenDucked: true,
        ),
      );

      // Handle interruptions (phone calls, etc)
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          // Interruption began, save state
          _wasPlayingBeforeInterruption = isPlaying.value;
          if (isPlaying.value) {
            pausePlayback();
          }
        } else {
          // Interruption ended, restore if needed
          if (_wasPlayingBeforeInterruption &&
              event.type == AudioInterruptionType.pause) {
            resumePlayback();
          }
          _wasPlayingBeforeInterruption = false;
        }
      });

      // Handle becoming noisy (headphones unplugged)
      session.becomingNoisyEventStream.listen((_) {
        if (isPlaying.value) {
          pausePlayback();
        }
      });
    } catch (e) {
      errorMsg.value = 'Failed to setup audio session: $e';
      print('Error setting up audio session: $e');
    }
  }

  void _setupAudioPlayer() {
    // Listen to player state changes
    player.playerStateStream.listen((state) {
      isPlaying.value = state.playing;

      if (state.processingState == ProcessingState.completed) {
        isPlaying.value = false;
        audioPosition.value = Duration.zero;

        // Auto-play next if not looping
        if (!isLoopEnabled.value && hasNext.value) {
          // Small delay to improve UX
          Future.delayed(const Duration(milliseconds: 500), skipToNext);
        }
      }

      forceRefresh();
    });

    // More efficient position tracking using timer instead of stream
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) {
      audioPosition.value = player.position;
    });

    // Get duration when available
    player.durationStream.listen((duration) {
      audioDuration.value = duration ?? Duration.zero;
      forceRefresh();
    });

    // Handle errors
    player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        print('Audio playback error: $e');
        errorMsg.value = 'Audio playback error: $e';

        // Try to recover from error
        if (currentlyPlayingFile.value.isNotEmpty) {
          final file = File(currentlyPlayingFile.value);
          if (file.existsSync()) {
            // Attempt to restart playback after a brief pause
            Future.delayed(const Duration(seconds: 1), () {
              player.seek(Duration.zero);
              player.play();
            });
          }
        }

        forceRefresh();
      },
    );
  }

  // Toggle section filter
  void toggleSectionFilter() {
    // Store current state to check for changes
    final wasFilterEnabled = filterBySection.value;
    final previousSectionId = currentSectionId.value;

    // Toggle the filter
    filterBySection.value = !filterBySection.value;

    // Handle reciter validation after toggling filter
    // Only if we're enabling filtering and have a reciter selected
    if (!wasFilterEnabled &&
        filterBySection.value &&
        currentQari.value != null) {
      // Schedule this check for after the build cycle completes
      Future.microtask(() {
        final qari = currentQari.value;
        if (qari != null) {
          final filteredReciters = getRecitersBySection(currentSectionId.value);

          // If current reciter is not in the filtered list, reset the reciter
          if (!filteredReciters.any((r) => r.id == qari.id)) {
            // If section has reciters, set to first reciter in the section
            if (filteredReciters.isNotEmpty) {
              setCurrentReciter(filteredReciters.first);
            } else {
              // If no reciters in current section, just null out the current reciter
              currentQari.value = null;
            }
          }
        }
        forceRefresh();
      });
    }

    forceRefresh();
  }

  // Set current section
  void setCurrentSection(int sectionId) {
    // Store current sectionId to check if it actually changed
    final previousSectionId = currentSectionId.value;

    // Set the new section ID
    currentSectionId.value = sectionId;

    // Only do the reciter check if the section actually changed
    if (previousSectionId != sectionId) {
      // Schedule the check after the build cycle completes
      Future.microtask(() {
        // Handle reciter validation after changing section
        if (filterBySection.value && currentQari.value != null) {
          final qari = currentQari.value;
          if (qari != null) {
            final filteredReciters = getRecitersBySection(sectionId);

            // If current reciter is not in the filtered list, reset the reciter
            if (!filteredReciters.any((r) => r.id == qari.id)) {
              // If section has reciters, set to first reciter in the section
              if (filteredReciters.isNotEmpty) {
                setCurrentReciter(filteredReciters.first);
              } else {
                // If no reciters in current section, just null out the current reciter
                currentQari.value = null;
              }
            }
          }
        }
        forceRefresh();
      });
    }

    forceRefresh();
  }

  // Get reciters by section
  List<Qari> getRecitersBySection(int sectionId) {
    return qarisList.where((qari) => qari.sectionId == sectionId).toList();
  }

  // Load list of reciters
  Future<void> loadQarisList() async {
    try {
      isLoadingQaris.value = true;
      forceRefresh();

      // Use the API endpoint from the README.md
      final response = await http
          .get(Uri.parse('https://quranicaudio.com/api/qaris'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout:
                () => throw 'Connection timed out while fetching reciters',
          );

      if (response.statusCode != 200) {
        throw 'Failed to load reciters: Server returned ${response.statusCode}';
      }

      // Parse the JSON response
      final List<dynamic> qariListJson = json.decode(response.body);
      final List<Qari> fetchedQarisList =
          qariListJson
              .map(
                (qariJson) => Qari.fromJson(qariJson as Map<String, dynamic>),
              )
              .toList();

      // Load sections to organize reciters
      await loadSectionsList();

      // Update the observable list
      qarisList.value = fetchedQarisList;
      print('Loaded ${qarisList.length} reciters from API');

      // Set default reciter if none selected
      if (currentQari.value == null && qarisList.isNotEmpty) {
        // Try to use a featured reciter first (home: true)
        final featuredReciter = qarisList.firstWhere(
          (qari) => qari.home && qari.sectionId == 1,
          orElse: () => qarisList.first,
        );
        currentQari.value = featuredReciter;
        print('Set default reciter: ${currentQari.value?.name}');
      }
    } catch (e) {
      // Fall back to hardcoded list if API fails
      print('Error loading reciters from API: $e');
      errorMsg.value = 'Failed to load reciters from API: $e';
      _loadFallbackQarisList();
    } finally {
      isLoadingQaris.value = false;
      forceRefresh();
    }
  }

  // Fallback method with hardcoded reciters if API fails
  void _loadFallbackQarisList() {
    qarisList.value = [
      Qari(
        id: 1,
        name: "Mishary Rashid Alafasy",
        arabicName: "مشاري بن راشد العفاسي",
        relativePath: "mishaari_raashid_al_3afaasee/",
        fileFormats: "mp3",
        sectionId: 1,
        home: true,
      ),
      Qari(
        id: 2,
        name: "Abdul Basit Abdul Samad",
        arabicName: "عبد الباسط عبد الصمد",
        relativePath: "abdul_baasit_abdus-samad/",
        fileFormats: "mp3",
        sectionId: 1,
        home: true,
      ),
      // Add other fallback reciters
    ];
    print('Loaded ${qarisList.length} fallback reciters');
  }

  // Load sections list from API
  Future<void> loadSectionsList() async {
    try {
      isLoadingSections.value = true;
      forceRefresh();

      // Use the API endpoint from the README.md
      final response = await http
          .get(Uri.parse('https://quranicaudio.com/api/sections'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout:
                () => throw 'Connection timed out while fetching sections',
          );

      if (response.statusCode != 200) {
        throw 'Failed to load sections: Server returned ${response.statusCode}';
      }

      // Parse the JSON response
      final List<dynamic> sectionListJson = json.decode(response.body);
      final List<Section> fetchedSectionsList =
          sectionListJson
              .map(
                (sectionJson) =>
                    Section.fromJson(sectionJson as Map<String, dynamic>),
              )
              .toList();

      // Update the observable list
      sectionsList.value = fetchedSectionsList;
      print('Loaded ${sectionsList.length} sections from API');
    } catch (e) {
      // Fall back to hardcoded sections if API fails
      print('Error loading sections from API: $e');
      errorMsg.value = 'Failed to load sections: $e';
      _loadFallbackSectionsList();
    } finally {
      isLoadingSections.value = false;
      forceRefresh();
    }
  }

  // Fallback method with hardcoded sections if API fails
  void _loadFallbackSectionsList() {
    sectionsList.value = [
      Section(id: 0, name: "All Sections"),
      Section(id: 1, name: "Recitations"),
      Section(id: 2, name: "Recitations from Haramain Taraweeh"),
      Section(id: 3, name: "Non-Hafs Recitations"),
      Section(id: 4, name: "Recitations with Translations"),
    ];
    print('Loaded ${sectionsList.length} fallback sections');
  }

  // Extract surah number from filename
  int getSurahNumberFromFilename(String filename) {
    try {
      // Parse from format 'surah_114_reciterId.mp3'
      final parts = filename.split('_');
      if (parts.length >= 2) {
        return int.parse(parts[1]);
      }
      return 1; // Default to first surah if parsing fails
    } catch (e) {
      print('Error parsing surah number: $e');
      return 1;
    }
  }

  // Skip to previous surah
  void skipToPrevious() {
    if (!hasPrevious.value) return;

    try {
      final currentFile = currentlyPlayingFile.value;
      final currentIndex = downloadedFiles.indexOf(currentFile);

      if (currentIndex > 0) {
        final previousFile = downloadedFiles[currentIndex - 1];
        playSurah(previousFile);
      }
    } catch (e) {
      errorMsg.value = 'Failed to play previous: $e';
      Get.snackbar('Error', 'Failed to play previous audio');
    }
  }

  // Skip to next surah
  void skipToNext() {
    if (!hasNext.value) return;

    try {
      final currentFile = currentlyPlayingFile.value;
      final currentIndex = downloadedFiles.indexOf(currentFile);

      if (currentIndex < downloadedFiles.length - 1) {
        final nextFile = downloadedFiles[currentIndex + 1];
        playSurah(nextFile);
      }
    } catch (e) {
      errorMsg.value = 'Failed to play next: $e';
      Get.snackbar('Error', 'Failed to play next audio');
    }
  }

  // Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Double-check with actual HTTP request
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Connectivity check failed: $e');
      return false;
    }
  }

  // Get audio URL - Comprehensive implementation for reciter mapping
  String _getAudioUrl(int surahNumber, String reciterIdentifier) {
    // Format surah number with leading zeros to ensure 3 digits (e.g. 001, 114)
    final paddedNumber = surahNumber.toString().padLeft(3, '0');

    // Base URL as per README.md
    const baseUrl = 'https://download.quranicaudio.com/quran/';

    // Extract the clean path from the identifier (handling composite identifiers)
    String cleanPath = reciterIdentifier;
    if (reciterIdentifier.contains('_')) {
      final parts = reciterIdentifier.split('_');
      if (parts.length >= 2) {
        cleanPath = parts[0];
      }
    }

    // Ensure path ends with a slash
    if (!cleanPath.endsWith('/')) {
      cleanPath = '$cleanPath/';
    }

    // Create normalized version for comparison
    final normalizedPath = cleanPath
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll('/', '');

    print("Normalized path for matching: $normalizedPath");

    // Comprehensive mapping of reciter names/identifiers to server paths
    final Map<String, String> reciterMapping = {
      // Common reciters with exact path mapping
      'mishaari_raashid_al_3afaasee': 'mishari_rashid_al_afasy',
      'mishari': 'mishari_rashid_al_afasy',
      'alafasy': 'mishari_rashid_al_afasy',
      'abdul_baasit_abdus-samad': 'abdul_basit_abdus-samad',
      'abdulbasit': 'abdul_basit_abdus-samad',
      'mahmood_khaleel_al-husaree': 'mahmood_khaleel_al-husaree_iza3a',
      'husary': 'mahmood_khaleel_al-husaree_iza3a',
      'alhusary': 'mahmood_khaleel_al-husaree_iza3a',
      'muhammad_siddeeq_al-minshaawee': 'muhammad_siddeeq_al-minshaawee',
      'minshawi': 'muhammad_siddeeq_al-minshaawee',
      'sahl_yaaseen': 'sahl_yaaseen',
      'sahlYasin': 'sahl_yaaseen',
      'mostafa': 'mostafa_ismaeel/muzamil_normalize',
      'mostafaismaeel': 'mostafa_ismaeel/muzamil_normalize',
      'mostafa_ismaeel': 'mostafa_ismaeel/muzamil_normalize',
      'khalefa_al_tunaiji': 'khalifa_al_tunaiji_64kbps',
      'tunaiji': 'khalifa_al_tunaiji_64kbps',
      'abdullaah_3awwaad_al-juhaynee': 'abdullaah_3awwaad_al-juhaynee',
      'aljuhani': 'abdullaah_3awwaad_al-juhaynee',
      'muhammad_jibreel': 'muhammad_jibreel',
      'jibreel': 'muhammad_jibreel',
      'mustafa_al_3azzawi': 'mustafa_al_3azzawi_128kbps',
      'azzawi': 'mustafa_al_3azzawi_128kbps',
      'alhusaynee_al3azazee': 'alhusaynee_al3azazee_with_children',
      'alhusaynee': 'alhusaynee_al3azazee_with_children',
      'hudhaify': 'hudhaify_64kbps',
      'alhudhaify': 'hudhaify_64kbps',
      'hudaify': 'hudhaify_64kbps',
      'abdul_muhsin_al_qasim': 'abdul_muhsin_al_qasim',
      'qasim': 'abdul_muhsin_al_qasim',
      'sa3ood_ash-shuraym': 'sa3ood_ash-shuraym',
      'shuraym': 'sa3ood_ash-shuraym',
      'shuraim': 'sa3ood_ash-shuraym',
      'salah_al_budair': 'salah_al_budair',
      'budair': 'salah_al_budair',
      'muhammad_siddiq_al-minshawi':
          'muhammad_siddiq_al-minshawi_with_children',
      'minshawi_child': 'muhammad_siddiq_al-minshawi_with_children',
      'abdurrahmaan_as-sudays': 'abdurrahmaan_as-sudais_64kbps',
      'sudais': 'abdurrahmaan_as-sudais_64kbps',
      'hani_ar-rifai': 'hani_ar-rifai_64kbps',
      'rifai': 'hani_ar-rifai_64kbps',
      'sa3d_al-ghaamidi': 'sa3d_al-ghaamidi',
      'ghamidi': 'sa3d_al-ghaamidi',
    };

    // Try to find a match using the normalized path
    String? matchedPath;
    for (final entry in reciterMapping.entries) {
      final normalizedKey = entry.key
          .toLowerCase()
          .replaceAll('_', '')
          .replaceAll('-', '')
          .replaceAll('/', '');

      if (normalizedPath.contains(normalizedKey) ||
          normalizedKey.contains(normalizedPath)) {
        matchedPath = entry.value;
        print('Matched reciter: $normalizedPath -> $matchedPath');
        break;
      }
    }

    // Use the matched path if found, otherwise use the original clean path
    String finalPath =
        matchedPath != null
            ? (matchedPath.endsWith('/') ? matchedPath : '$matchedPath/')
            : cleanPath;

    // Handle special cases with additional logic
    if (normalizedPath.contains('mostafa') ||
        normalizedPath.contains('ismaeel')) {
      finalPath = 'mostafa_ismaeel/muzamil_normalize/';
      print('Using special path for Mostafa: $finalPath');
    } else if (normalizedPath.contains('sudais') ||
        normalizedPath.contains('sudays')) {
      finalPath = 'abdurrahmaan_as-sudais_64kbps/';
      print('Using special path for Sudais: $finalPath');
    } else if (normalizedPath.contains('husary') ||
        normalizedPath.contains('husaree')) {
      finalPath = 'mahmood_khaleel_al-husaree_iza3a/';
      print('Using special path for Husary: $finalPath');
    }

    // Construct the final URL
    final url = '$baseUrl$finalPath$paddedNumber.mp3';

    print('Generated audio URL for surah $surahNumber: $url');
    return url;
  }

  // Return a public URL for testing purposes
  String getPublicAudioUrl(int surahNumber, String reciterId) {
    return _getAudioUrl(surahNumber, reciterId);
  }

  // Validate if a reciter URL is accessible
  Future<bool> validateReciterUrl(
    String reciterId, {
    int surahNumber = 1,
  }) async {
    try {
      if (!await _checkConnectivity()) {
        return false;
      }

      final url = _getAudioUrl(surahNumber, reciterId);
      print('Testing URL: $url');

      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print('Error validating reciter URL: $e');
      return false;
    }
  }

  // Validate all reciters and return results
  Future<Map<String, bool>> validateAllReciters() async {
    final results = <String, bool>{};

    for (final reciter in qarisList) {
      results[reciter.id.toString()] = await validateReciterUrl(
        reciter.id.toString(),
      );
    }

    return results;
  }

  // Download single surah
  Future<void> downloadSurah(int surahNumber) async {
    if (currentQari.value == null) {
      Get.snackbar('Error', 'Please select a reciter first');
      return;
    }

    // Check for network connectivity
    final hasConnection = await _checkConnectivity();
    if (!hasConnection) {
      Get.snackbar(
        'No Connection',
        'Please check your internet connection and try again',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Use a consistent identifier format for the reciter
    final qari = currentQari.value!;
    // Add the ID to the identifier to ensure uniqueness
    final identifier = "${qari.getFileIdentifier()}_${qari.id}";

    print("Downloading surah $surahNumber for reciter: ${qari.name}");
    print("Using identifier: $identifier");

    // Use both ID and path for reliable file organization
    return _downloadSurahWithReciter(surahNumber, identifier);
  }

  // Update navigation flags
  void updateNavigationFlags() {
    if (downloadedFiles.isEmpty || currentlyPlayingFile.value.isEmpty) {
      hasPrevious.value = false;
      hasNext.value = false;
      return;
    }

    final currentFile = currentlyPlayingFile.value;
    final currentIndex = downloadedFiles.indexOf(currentFile);

    hasPrevious.value = currentIndex > 0;
    hasNext.value = currentIndex < downloadedFiles.length - 1;
    forceRefresh();
  }

  // Seek to position
  void seekTo(Duration position) {
    if (position < Duration.zero) {
      position = Duration.zero;
    } else if (position > audioDuration.value) {
      position = audioDuration.value;
    }

    player.seek(position);
    audioPosition.value = position;
    forceRefresh();
  }

  // Jump forward by seconds
  void jumpForward([int seconds = 10]) {
    final newPosition = audioPosition.value + Duration(seconds: seconds);
    seekTo(newPosition);
  }

  // Jump backward by seconds
  void jumpBackward([int seconds = 10]) {
    final newPosition = audioPosition.value - Duration(seconds: seconds);
    seekTo(newPosition);
  }

  // Toggle loop mode
  void toggleLoop() {
    isLoopEnabled.value = !isLoopEnabled.value;
    player.setLoopMode(isLoopEnabled.value ? LoopMode.one : LoopMode.off);

    Get.snackbar(
      'Repeat Mode',
      isLoopEnabled.value ? 'Repeat enabled' : 'Repeat disabled',
      duration: const Duration(seconds: 2),
    );

    forceRefresh();
  }

  // Pause playback
  Future<void> pausePlayback() async {
    try {
      await player.pause();
      isPlaying.value = false;
      try {
        WakelockPlus.disable().catchError((_) {
          // Silently handle wakelock errors
          print('Could not disable wakelock - no foreground activity');
        });
      } catch (e) {
        print('Error disabling wakelock: $e');
      }
      forceRefresh();
    } catch (e) {
      errorMsg.value = 'Failed to pause: $e';
      print('Error pausing playback: $e');
    }
  }

  // Resume playback
  Future<void> resumePlayback() async {
    try {
      await player.play();
      isPlaying.value = true;
      try {
        WakelockPlus.enable().catchError((_) {
          // Silently handle wakelock errors
          print('Could not enable wakelock - no foreground activity');
        });
      } catch (e) {
        print('Error enabling wakelock: $e');
      }
      forceRefresh();
    } catch (e) {
      errorMsg.value = 'Failed to resume: $e';
      Get.snackbar('Error', 'Failed to resume playback: $e');
    }
  }

  // Delete surah
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

        // Also remove from favorites if present
        if (favoriteSurahs.contains(filePath)) {
          await toggleFavoriteSurah(filePath);
        }

        // Update last played if needed
        if (lastPlayedSurah.value == filePath) {
          lastPlayedSurah.value = '';
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('last_played_surah');
        }

        forceRefresh();
        Get.snackbar('Success', 'Surah deleted successfully');
      }
    } catch (e) {
      errorMsg.value = 'Failed to delete: $e';
      Get.snackbar('Error', 'Failed to delete surah: $e');
    }
  }

  // Get full file path
  String getFullPath(String filename) {
    if (_audioDir != null) {
      return '$_audioDir/$filename';
    }

    final dir =
        downloadedFiles.isNotEmpty
            ? downloadedFiles.first.substring(
              0,
              downloadedFiles.first.lastIndexOf('/'),
            )
            : '';
    return '$dir/$filename';
  }

  // Resume after interruption
  Future<void> resumeAfterInterruption() async {
    try {
      if (currentlyPlayingFile.value.isNotEmpty && !isPlaying.value) {
        await player.play();
        isPlaying.value = true;
        try {
          WakelockPlus.enable().catchError((_) {
            // Silently handle wakelock errors
            print('Could not enable wakelock - no foreground activity');
          });
        } catch (e) {
          print('Error enabling wakelock: $e');
        }
        forceRefresh();
      }
    } catch (e) {
      errorMsg.value = 'Failed to resume after interruption: $e';
      print('Error resuming after interruption: $e');
    }
  }

  // Release resources for battery optimization
  Future<void> releaseResources() async {
    try {
      try {
        WakelockPlus.disable().catchError((_) {
          // Silently handle wakelock errors
          print('Could not disable wakelock - no foreground activity');
        });
      } catch (e) {
        print('Error disabling wakelock: $e');
      }

      if (isPlaying.value) {
        await player.pause();
        isPlaying.value = false;
      }

      await player.stop();
      forceRefresh();
    } catch (e) {
      errorMsg.value = 'Failed to release resources: $e';
      print('Error releasing resources: $e');
    }
  }

  // Clear all downloaded audio
  Future<void> clearCache() async {
    try {
      // Confirm with user
      final result = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Clear Audio Cache'),
          content: const Text(
            'This will delete all downloaded surahs. This action cannot be undone. Continue?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Get.back(result: false),
            ),
            TextButton(
              child: const Text('Clear'),
              onPressed: () => Get.back(result: true),
            ),
          ],
        ),
      );

      if (result != true) return;

      if (isPlaying.value) {
        await player.stop();
        isPlaying.value = false;
        currentlyPlayingFile.value = '';
      }

      final audioDir = await _getAudioDirectory();
      final directory = Directory(audioDir);

      if (await directory.exists()) {
        // Delete all files individually for better tracking
        for (final file in downloadedFiles) {
          final fileObj = File(file);
          if (await fileObj.exists()) {
            await fileObj.delete();
          }
        }

        // Clear lists
        downloadedFiles.clear();
        favoriteSurahs.clear();
        lastPlayedSurah.value = '';

        // Clear preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('favorite_surahs');
        await prefs.remove('last_played_surah');

        forceRefresh();
        Get.snackbar(
          'Success',
          'Audio cache cleared successfully',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      errorMsg.value = 'Failed to clear cache: $e';
      Get.snackbar('Error', 'Failed to clear cache: $e');
    }
  }

  void _initializeBufferManagement() {
    // Configure audio settings for Android
    if (Platform.isAndroid) {
      player.setAndroidAudioAttributes(
        const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
      );
    }

    player.processingStateStream.listen((state) {
      isBuffering.value = state == ProcessingState.buffering;
      if (state == ProcessingState.completed) {
        _handlePlaybackCompletion();
      }
    });
  }

  void _handlePlaybackCompletion() async {
    if (!isLoopEnabled.value && player.hasNext) {
      await _preloadNextTrack();
    }
  }

  Future<void> _preloadNextTrack() async {
    try {
      if (player.hasNext) {
        final nextIndex = player.nextIndex;
        if (nextIndex != null) {
          final nextFile = downloadedFiles[nextIndex];
          await player.setAudioSource(
            AudioSource.file(nextFile),
            preload: false, // Don't preload yet
          );
        }
      }
    } catch (e) {
      debugPrint('Error preloading next track: $e');
    }
  }

  void _manageWakeLock(bool enable) {
    if (enable) {
      try {
        WakelockPlus.enable().catchError((_) {
          // Silently handle wakelock errors
          print('Could not enable wakelock - no foreground activity');
        });
      } catch (e) {
        print('Error enabling wakelock: $e');
      }
    } else {
      try {
        WakelockPlus.disable().catchError((_) {
          // Silently handle wakelock errors
          print('Could not disable wakelock - no foreground activity');
        });
      } catch (e) {
        print('Error disabling wakelock: $e');
      }
    }
  }

  void _startBufferManagement() {
    _bufferTimer?.cancel();
    _bufferTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (player.playing && !isBuffering.value && Platform.isAndroid) {
        player.setAndroidAudioAttributes(
          const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
        );
      }
    });
  }

  void _updatePlaybackStatus(bool isPlaying) {
    this.isPlaying.value = isPlaying;
    refreshTrigger.value =
        refreshTrigger.value == 0 ? 1 : 0; // Toggle between 0 and 1
  }

  Future<void> restoreLastPlayback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPlayedPath = prefs.getString('last_played_surah');

      // Don't autoplay by default
      final shouldAutoPlay = false;

      if (lastPlayedPath != null && await File(lastPlayedPath).exists()) {
        print('Restoring last played surah: $lastPlayedPath');

        // Load position data
        final lastPosition = prefs.getInt('last_played_position') ?? 0;

        // Try to set the correct reciter with multiple fallback strategies
        bool reciterSet = false;

        // 1. Try to use the directly saved reciter ID (most reliable)
        final savedQariId = prefs.getInt('last_qari_id');
        if (savedQariId != null && qarisList.isNotEmpty) {
          final savedReciter = qarisList.firstWhereOrNull(
            (r) => r.id == savedQariId,
          );
          if (savedReciter != null) {
            currentQari.value = savedReciter;
            print(
              'Restored reciter by saved ID: ${savedReciter.name} (ID: ${savedReciter.id})',
            );
            reciterSet = true;
          }
        }

        // 2. Try to use the saved reciter path if ID failed
        if (!reciterSet) {
          final savedQariPath = prefs.getString('last_qari_path');
          if (savedQariPath != null && qarisList.isNotEmpty) {
            final savedReciter = qarisList.firstWhereOrNull(
              (r) => r.relativePath == savedQariPath,
            );
            if (savedReciter != null) {
              currentQari.value = savedReciter;
              print(
                'Restored reciter by saved path: ${savedReciter.name} (Path: ${savedReciter.relativePath})',
              );
              reciterSet = true;
            }
          }
        }

        // 3. Try to extract reciter from filename as last resort
        if (!reciterSet) {
          final filename = lastPlayedPath.split('/').last;
          final parts = filename.split('_');
          if (parts.length >= 3) {
            final extractedReciterId = parts[2].replaceAll('.mp3', '');
            print(
              'Extracted reciter identifier from filename: $extractedReciterId',
            );

            // Try to find a matching reciter by relative path or ID
            for (final reciter in qarisList) {
              final cleanPath =
                  reciter.relativePath.endsWith('/')
                      ? reciter.relativePath.substring(
                        0,
                        reciter.relativePath.length - 1,
                      )
                      : reciter.relativePath;

              if (cleanPath == extractedReciterId ||
                  extractedReciterId.contains(cleanPath) ||
                  reciter.id.toString() == extractedReciterId) {
                currentQari.value = reciter;
                print('Matched reciter from filename: ${reciter.name}');
                reciterSet = true;
                break;
              }
            }

            // If still not set, use the first reciter as fallback
            if (!reciterSet && qarisList.isNotEmpty) {
              currentQari.value = qarisList.first;
              print(
                'Using default reciter as fallback: ${qarisList.first.name}',
              );
            }
          }
        }

        // Set up the last played file but don't autoplay
        lastPlayedSurah.value = lastPlayedPath;

        // Load the file into the player but don't start playback
        await player.setAudioSource(
          AudioSource.file(lastPlayedPath),
          preload: true,
        );

        // Update the media item
        _updateMediaItem(lastPlayedPath);

        // Set the currentlyPlayingFile but don't actually play
        currentlyPlayingFile.value = lastPlayedPath;

        // Seek to the last position
        seekTo(Duration(milliseconds: lastPosition));

        // Update UI without starting playback
        isPlaying.value = false;
        updateNavigationFlags();

        print('Restored last played file and position without autoplay');
      }
    } catch (e) {
      print('Error restoring last playback: $e');
      errorMsg.value = 'Failed to restore last playback: $e';
    }
  }

  // Load surah list from API
  Future<void> loadSurahsList() async {
    try {
      isLoadingSurahs.value = true;
      forceRefresh();

      // Use the API endpoint from the README.md
      final response = await http
          .get(Uri.parse('https://quranicaudio.com/api/surahs'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw 'Connection timed out while fetching surahs',
          );

      if (response.statusCode != 200) {
        throw 'Failed to load surahs: Server returned ${response.statusCode}';
      }

      // Parse the JSON response
      final List<dynamic> surahListJson = json.decode(response.body);
      final List<Surah> fetchedSurahsList =
          surahListJson
              .map(
                (surahJson) =>
                    Surah.fromJson(surahJson as Map<String, dynamic>),
              )
              .toList();

      // Update the observable list
      surahsList.value = fetchedSurahsList;
      print('Loaded ${surahsList.length} surahs from API');
    } catch (e) {
      // Fall back to hardcoded list if API fails
      print('Error loading surahs from API: $e');
      errorMsg.value = 'Failed to load surahs: $e';
      _loadFallbackSurahsList();
    } finally {
      isLoadingSurahs.value = false;
      forceRefresh();
    }
  }

  // Fallback method with hardcoded surahs if API fails
  void _loadFallbackSurahsList() {
    // We'll implement a basic list here
    // In a real app, you would include all 114 surahs
    print('Loading fallback surah list');
    // Implement fallback list if needed
  }

  // Helper to match downloaded file with reciter data
  Qari? getReciterByName(String fileName) {
    try {
      final parts = fileName.split('_');
      if (parts.length < 3) return null;

      // Extract reciter ID part (may be a name, path, or ID)
      String reciterIdentifier = parts[2].replaceAll('.mp3', '');

      // First try exact ID match
      Qari? reciter = qarisList.firstWhereOrNull(
        (r) => r.id.toString() == reciterIdentifier,
      );
      if (reciter != null) return reciter;

      // Then try path match
      reciter = qarisList.firstWhereOrNull(
        (r) =>
            r.relativePath.toLowerCase().contains(
              reciterIdentifier.toLowerCase(),
            ) ||
            reciterIdentifier.toLowerCase().contains(
              r.relativePath.toLowerCase(),
            ),
      );
      if (reciter != null) return reciter;

      // Then try name match
      final normalizedIdentifier = reciterIdentifier
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');
      reciter = qarisList.firstWhereOrNull(
        (r) =>
            r.name.toLowerCase().contains(normalizedIdentifier) ||
            normalizedIdentifier.contains(r.name.toLowerCase()),
      );

      return reciter;
    } catch (e) {
      print('Error finding reciter for file $fileName: $e');
      return null;
    }
  }

  // Get a sorted copy of files so we don't modify the original list
  List<String> getSortedDownloadedFiles(List<String> files) {
    // Create a copy of the list to avoid modifying the original
    final sortedFiles = List<String>.from(files);

    // Sort by surah number
    sortedFiles.sort((a, b) {
      final surahA = getSurahNumberFromFilename(a.split('/').last);
      final surahB = getSurahNumberFromFilename(b.split('/').last);
      return surahA.compareTo(surahB);
    });

    return sortedFiles;
  }

  // Get files for a specific reciter to avoid filtering in the build method
  List<String> getReciterFiles(
    String qariId,
    String qariPath,
    String qariName,
  ) {
    if (downloadedFiles.isEmpty) return [];

    final result = <String>[];

    for (final path in downloadedFiles) {
      final fileName = path.split('/').last.toLowerCase();

      // Debug info
      print("Checking file: ${fileName.split('/').last}");
      print(
        "Current reciter - qariId: $qariId, qariPath: $qariPath, qariName: $qariName",
      );

      // 1. Check if file contains the actual ID of the current reciter
      if (fileName.contains('_${qariId}_') ||
          fileName.contains('_${qariId}.mp3')) {
        print("Match by exact qariId: $fileName contains ID $qariId");
        result.add(path);
        continue;
      }

      // 2. Check for the relativePath (with or without trailing slash)
      final cleanPath =
          qariPath.endsWith('/')
              ? qariPath.substring(0, qariPath.length - 1)
              : qariPath;

      if (fileName.contains(cleanPath.toLowerCase())) {
        print(
          "Match by relativePath: $fileName contains ${cleanPath.toLowerCase()}",
        );
        result.add(path);
        continue;
      }

      // 3. Extract reciter identifier from filename for deeper inspection
      try {
        final parts = fileName.split('_');
        if (parts.length >= 3) {
          // Get the third part (reciter identifier) and remove any .mp3 extension
          final fileReciterId = parts[2].replaceAll('.mp3', '');
          print("Extracted identifier: '$fileReciterId' from $fileName");

          // Additional checks for name-based matching - handles cases where saved files
          // don't use the exact ID or path but have recognizable reciter name elements
          final qariNameNormalized =
              qariName.replaceAll(' ', '_').toLowerCase();
          final fileReciterIdLower = fileReciterId.toLowerCase();

          // Match by ID
          if (fileReciterId == qariId) {
            print("Match by direct ID comparison");
            result.add(path);
            continue;
          }

          // Match by relativePath or variation of it
          if (fileReciterIdLower.contains(cleanPath.toLowerCase()) ||
              cleanPath.toLowerCase().contains(fileReciterIdLower)) {
            print("Match by relativePath partial match");
            result.add(path);
            continue;
          }

          // Match by reciter name
          if (fileReciterIdLower.contains(qariNameNormalized) ||
              qariNameNormalized.contains(fileReciterIdLower)) {
            print(
              "Match by reciter name: $fileReciterIdLower contains elements of $qariNameNormalized",
            );
            result.add(path);
            continue;
          }

          // No match found
          print(
            "No match - Current reciter: $qariNameNormalized, File reciter: $fileReciterIdLower",
          );
        }
      } catch (e) {
        print("Error parsing filename $fileName: $e");
      }
    }

    return result;
  }

  // Sort downloaded files by surah number
  void _sortDownloadedFiles() {
    downloadedFiles.sort((a, b) {
      final aNum = getSurahNumberFromFilename(a.split('/').last);
      final bNum = getSurahNumberFromFilename(b.split('/').last);
      return aNum.compareTo(bNum);
    });
  }
}
