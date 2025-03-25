enum SearchType {
  all,
  surah,
  ayah,
  page,
  juz;

  String get displayName {
    switch (this) {
      case SearchType.all:
        return 'All';
      case SearchType.surah:
        return 'Surah';
      case SearchType.ayah:
        return 'Ayah';
      case SearchType.page:
        return 'Page';
      case SearchType.juz:
        return 'Juz';
    }
  }
}
