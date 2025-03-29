# Quran App with QuranicAudio Integration

This project is a Flutter application for reading and listening to the Quran. It integrates with the QuranicAudio.com API to provide access to a wide variety of reciters and recitations.

## Features

- Read the Quran with beautiful typography
- Listen to recitations from multiple reciters
- Download recitations for offline playback
- Filter reciters by section (Recitations, Haramain Taraweeh, etc.)
- Navigate through surahs with play, pause, seek controls
- Previous and next surah navigation
- Audio progress tracking
- Shuffle play (coming soon)

## API Integration

The app uses the QuranicAudio.com API for fetching:

- List of reciters (qaris)
- Reciter sections
- Audio files and metadata
- MP3 download URLs

### API Endpoints

- Reciters: `https://quranicaudio.com/api/qaris`
- Sections: `https://quranicaudio.com/api/sections`
- Audio Files: `https://quranicaudio.com/api/audio_files`
- MP3 Downloads: `https://download.quranicaudio.com/quran/{relative_path}/{surah_number}.mp3`

## Project Structure

- `/lib/models` - Data models for API responses
- `/lib/services` - API service classes
- `/lib/controllers` - GetX controllers for state management
- `/lib/views` - UI screens and components

## Setup

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app

## Dependencies

- flutter_screenutil
- get (GetX for state management)
- just_audio
- path_provider
- http
- quran (for surah information)
- audio_session

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
