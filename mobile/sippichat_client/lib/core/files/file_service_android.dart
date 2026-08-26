import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> chooseDownloadPathImpl({required String filename}) async {
  final downloadsDirectory = await getDownloadsDirectory();

  if (downloadsDirectory == null) {
    throw Exception('Could not access Downloads directory.');
  }

  return '${downloadsDirectory.path}/$filename';
}

Future<void> openFileImpl(String path) async {
  final result = await OpenFilex.open(path);

  if (result.type != ResultType.done) {
    throw Exception(result.message);
  }
}
