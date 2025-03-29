import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Get the path to the audio files folder
Future<String> getFolderPath() async {
  final directory = await getApplicationDocumentsDirectory();
  final folderPath = '${directory.path}/quran_audio';

  // Create the directory if it doesn't exist
  final dir = Directory(folderPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  return folderPath;
}

// Check if a file exists
Future<bool> fileExists(String path) async {
  final file = File(path);
  return await file.exists();
}

// Delete a file
Future<void> deleteFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

// List files in a directory
Future<List<FileSystemEntity>> listFiles(String directoryPath) async {
  final directory = Directory(directoryPath);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
    return [];
  }

  return directory.listSync();
}

// Get file size
Future<int> getFileSize(String path) async {
  final file = File(path);
  if (await file.exists()) {
    return await file.length();
  }
  return 0;
}
