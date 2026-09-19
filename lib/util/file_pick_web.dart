import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'picked_file.dart';

export 'picked_file.dart';

/// Opens the browser's own file dialog with no `accept` filter, so every
/// kind of file is offered — images, video, audio, PDFs, zips, anything.
/// Multiple selection is allowed; the bytes come back read.
Future<List<PickedFile>> pickAnyFiles() => _openDialog(multiple: true);

/// The browser's own file dialog. With no `accept` every kind of file is
/// offered, which is what the attachment button wants; the avatar passes
/// `image/*`.
Future<List<PickedFile>> _openDialog({
  required bool multiple,
  String? accept,
}) async {
  final web.HTMLInputElement input =
      web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.multiple = multiple;
  if (accept != null) input.accept = accept;
  input.style.display = 'none';
  web.document.body?.append(input);

  final Completer<List<PickedFile>> done = Completer<List<PickedFile>>();

  void finish(List<PickedFile> files) {
    if (!done.isCompleted) done.complete(files);
    input.remove();
  }

  input.onchange = (web.Event _) {
    final web.FileList? list = input.files;
    if (list == null || list.length == 0) {
      finish(const <PickedFile>[]);
      return;
    }
    final List<Future<PickedFile>> reads = <Future<PickedFile>>[];
    for (int i = 0; i < list.length; i++) {
      final web.File? file = list.item(i);
      if (file != null) reads.add(_read(file));
    }
    unawaited(
      Future.wait(reads).then<void>(finish).catchError(
            (Object _) => finish(const <PickedFile>[]),
          ),
    );
  }.toJS;

  // A dialog the person closes fires no `change` event, so the future
  // would hang forever. `cancel` covers the browsers that send it — after a
  // beat, because some of them fire it alongside a real selection and the
  // selection has to win.
  input.oncancel = (web.Event _) {
    Future<void>.delayed(
      const Duration(milliseconds: 400),
      () => finish(const <PickedFile>[]),
    );
  }.toJS;

  input.click();
  return done.future;
}

/// One image, for the avatar. Built on the same dialog as the attachment
/// picker — only the filter and the count differ — because that path is
/// the one that is known to behave across browsers.
Future<PickedFile?> pickOneImage() async {
  final List<PickedFile> picked = await _openDialog(
    multiple: false,
    accept: 'image/*',
  );
  return picked.isEmpty ? null : picked.first;
}

Future<PickedFile> _read(web.File file) async {
  final JSArrayBuffer buffer = await file.arrayBuffer().toDart;
  return PickedFile(
    name: file.name,
    bytes: buffer.toDart.asUint8List(),
    mimeType: file.type.isEmpty ? 'application/octet-stream' : file.type,
  );
}
