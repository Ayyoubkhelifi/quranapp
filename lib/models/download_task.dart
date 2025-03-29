enum DownloadStatus { downloading, completed, failed, canceled }

class DownloadTask {
  final int reciterId;
  final String reciterName;
  final int surahId;
  final String surahName;
  DownloadStatus status;
  int progress;

  DownloadTask({
    required this.reciterId,
    required this.reciterName,
    required this.surahId,
    required this.surahName,
    this.status = DownloadStatus.downloading,
    this.progress = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'reciterId': reciterId,
      'reciterName': reciterName,
      'surahId': surahId,
      'surahName': surahName,
      'status': status.toString(),
      'progress': progress,
    };
  }
}
