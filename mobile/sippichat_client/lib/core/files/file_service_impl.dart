Future<String?> chooseDownloadPathImpl({required String filename}) async {
  throw UnsupportedError(
    'Choosing a download path is not implemented on this platform.',
  );
}

Future<void> openFileImpl(String path) async {
  throw UnsupportedError('Opening files is not implemented on this platform.');
}
