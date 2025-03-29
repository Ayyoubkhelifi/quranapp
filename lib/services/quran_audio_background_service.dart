import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';

class QuranAudioBackgroundService {
  final AudioPlayer _player = AudioPlayer();
  final List<MediaItem> _mediaItems = [];
  final _currentMediaItemController = StreamController<MediaItem?>.broadcast();

  MediaItem? _currentMediaItem;

  // Stream getters
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlaybackState> get playbackStateStream => _createPlaybackStateStream();
  Stream<MediaItem?> get mediaItemStream => _currentMediaItemController.stream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;

  // Backward compatibility streams
  Stream<bool> get playingStream => _player.playingStream;
  Stream<bool> get completedStream => _player.processingStateStream.map(
    (state) => state == ProcessingState.completed,
  );
  Stream<PlaybackState> get processingStateStream =>
      _createPlaybackStateStream();
  MediaItem? get currentMediaItem => _currentMediaItem;

  // Navigation properties
  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;

  QuranAudioBackgroundService() {
    _setupListeners();
  }

  // Initialize the audio service
  static Future<void> init() async {
    try {
      // Check if we're running in a context that supports background audio
      // (i.e., not in a test environment or on an unsupported platform)
      final canInitialize = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      if (!canInitialize) {
        debugPrint(
          'Audio service initialization skipped - unsupported platform',
        );
        return;
      }

      await AudioService.init(
        builder: () => _AudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.quranapp.audio',
          androidNotificationChannelName: 'Quran Audio',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      debugPrint('Audio service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize audio service: $e');
      // Log detailed error to help with debugging
      debugPrint('Audio service initialization failed with stacktrace:');
      debugPrintStack(label: e.toString());
      // Continue without background audio functionality
    }
  }

  // Set up listeners for the audio player
  void _setupListeners() {
    // Listen for playback completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (_player.loopMode != LoopMode.one) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      }
    });

    // Listen for current index changes
    _player.currentIndexStream.listen((index) {
      if (index != null && index < _mediaItems.length) {
        _currentMediaItem = _mediaItems[index];
        _currentMediaItemController.add(_currentMediaItem);
      }
    });
  }

  // Create a custom playback state stream
  Stream<PlaybackState> _createPlaybackStateStream() {
    return CombineLatestStream.combine2<PlayerState, Duration, PlaybackState>(
      _player.playerStateStream,
      _player.positionStream,
      (playerState, position) => PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playerState.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        playing: playerState.playing,
        updatePosition: position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
        processingState: _getProcessingState(playerState.processingState),
      ),
    );
  }

  // Map Just Audio processing state to Audio Service processing state
  AudioProcessingState _getProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }

  // Update media items for the playlist
  Future<void> updateMediaItems(List<MediaItem> items) async {
    _mediaItems.clear();
    _mediaItems.addAll(items);

    // Create playlist from media items
    final playlist = ConcatenatingAudioSource(
      children:
          _mediaItems
              .map((item) => AudioSource.uri(Uri.file(item.id)))
              .toList(),
    );

    // Load the playlist
    await _player.setAudioSource(playlist);
  }

  // Compatibility method with old method names
  Future<void> loadPlaylist({
    required List<String> filePaths,
    required String reciterName,
    String? reciterArabicName,
  }) async {
    final mediaItems =
        filePaths.map((path) {
          final filename = path.split('/').last;
          return MediaItem(
            id: path,
            title: filename.replaceAll('.mp3', ''),
            artist: reciterName,
          );
        }).toList();

    await updateMediaItems(mediaItems);
  }

  // Compatibility method
  Future<void> loadSurah({
    required int surahNumber,
    required String filePath,
    required String reciterName,
    String? reciterArabicName,
  }) async {
    await playMediaItem(filePath);
  }

  // Play a specific media item by file path
  Future<void> playMediaItem(String filePath) async {
    try {
      final index = _mediaItems.indexWhere((item) => item.id == filePath);

      if (index != -1) {
        await _player.seek(Duration.zero, index: index);
        await _player.play();
        _currentMediaItem = _mediaItems[index];
        _currentMediaItemController.add(_currentMediaItem);

        // Preload next track for smoother playback
        preloadNextTrack();
      } else {
        // Enhanced error handling for missing files
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('Audio file does not exist: $filePath');
          return;
        }

        await _player.setAudioSource(
          AudioSource.uri(Uri.file(filePath)),
          preload: true, // Enable preloading
        );
        await _player.play();

        final filename = filePath.split('/').last;
        _currentMediaItem = MediaItem(
          id: filePath,
          title: filename.replaceAll('.mp3', ''),
        );
        _currentMediaItemController.add(_currentMediaItem);
      }
    } catch (e) {
      debugPrint('Error playing media item: $e');
      // Attempt recovery
      await _player.stop();
      await Future.delayed(const Duration(seconds: 1));
      try {
        await _player.setAudioSource(AudioSource.uri(Uri.file(filePath)));
        await _player.play();
      } catch (retryError) {
        debugPrint('Recovery attempt failed: $retryError');
      }
    }
  }

  // Play the current media item
  Future<void> play() async {
    await _player.play();
  }

  // Pause the current media item
  Future<void> pause() async {
    await _player.pause();
  }

  // Stop playback completely
  Future<void> stop() async {
    await _player.stop();
    _currentMediaItemController.add(null);
  }

  // Seek to a specific position - compatibility methods
  Future<void> seekTo(Duration position) async {
    await seek(position);
  }

  // Seek to a specific position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // Skip to the next item in the playlist
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  // Skip to the previous item in the playlist
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  // Set the loop mode for the player
  Future<void> setLoopMode(LoopMode mode) async {
    await _player.setLoopMode(mode);
  }

  // Dispose resources
  void dispose() {
    _player.dispose();
    _currentMediaItemController.close();
  }

  // Add caching mechanism to improve playback performance
  Future<void> preloadNextTrack() async {
    if (_player.hasNext && _player.nextIndex != null) {
      try {
        final nextIndex = _player.nextIndex!;
        if (nextIndex < _mediaItems.length) {
          await AudioPlayer().setUrl(_mediaItems[nextIndex].id);
        }
      } catch (e) {
        debugPrint('Error preloading next track: $e');
      }
    }
  }

  // Add cleanup method
  Future<void> cleanUp() async {
    try {
      await _player.stop();
      await _player.dispose();
      _currentMediaItemController.close();
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }
}

// Implementation of AudioHandler for background audio service
class _AudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  _AudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
  }

  // Broadcast state changes
  void _broadcastState(PlaybackEvent event) {
    final state = PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _getProcessingState(),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );

    playbackState.add(state);
  }

  // Map Just Audio processing state to Audio Service processing state
  AudioProcessingState _getProcessingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() =>
      _player.hasNext ? _player.seekToNext() : Future.value();

  @override
  Future<void> skipToPrevious() =>
      _player.hasPrevious ? _player.seekToPrevious() : Future.value();
}
