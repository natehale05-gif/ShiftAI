import 'picked_file.dart';

export 'picked_file.dart';

/// Off the web there is no browser dialog to open. The caller treats an
/// empty list as "the person picked nothing", which is the honest answer
/// here rather than a crash.
Future<List<PickedFile>> pickAnyFiles() async => const <PickedFile>[];

/// Same, filtered to images. Also empty off the web.
Future<PickedFile?> pickOneImage() async => null;
