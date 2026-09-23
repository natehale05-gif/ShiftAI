import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/theme/app_theme.dart';
import 'package:shift_ai/theme/tokens.dart';
import 'package:shift_ai/widgets/common.dart';

Map<String, dynamic> _row(Map<String, dynamic> extra) => <String, dynamic>{
      'id': 'fca39ec9',
      'title': 'Untitled image',
      'kind': 'image',
      'prompt': '',
      'model': '',
      'createdAt': '2026-09-23T00:00:00Z',
      'credits': 0,
      'aspect': 1,
      ...extra,
    };

void main() {
  test('the three new fields are read as the server sends them', () {
    final VaultItem item = VaultItem.fromJson(_row(<String, dynamic>{
      'mediaType': 'image',
      'mediaUrl': 'https://app.shiftai.club/app-preview/api/v1/media/a.png',
      'thumbnailUrl': 'https://app.shiftai.club/app-preview/api/v1/thumb/a.png',
    }));
    expect(item.mediaType, MediaType.image);
    expect(item.mediaUrl, endsWith('/v1/media/a.png'));
    expect(item.thumbnailUrl, endsWith('/v1/thumb/a.png'));
  });

  test('audio arrives with kind image, and mediaType says what it is', () {
    final VaultItem item = VaultItem.fromJson(_row(<String, dynamic>{
      'mediaType': 'audio',
      'mediaUrl': 'https://example.com/v1/media/b.mp3',
      'thumbnailUrl': null,
    }));
    expect(item.kind, MediaKind.image);
    expect(item.mediaType, MediaType.audio);
    expect(item.thumbnailUrl, isNull);
  });

  test('a row from before the fields existed still parses', () {
    final VaultItem video =
        VaultItem.fromJson(_row(<String, dynamic>{'kind': 'video'}));
    expect(video.mediaType, MediaType.video);
    expect(video.mediaUrl, isNull);
    expect(video.thumbnailUrl, isNull);
    // An empty string is no URL, not a broken image.
    final VaultItem blank =
        VaultItem.fromJson(_row(<String, dynamic>{'thumbnailUrl': ''}));
    expect(blank.thumbnailUrl, isNull);
  });

  test('renaming or publishing keeps the media, and the cache carries it', () {
    final VaultItem item = VaultItem.fromJson(_row(<String, dynamic>{
      'mediaType': 'document',
      'mediaUrl': 'https://example.com/v1/media/c.pdf',
    }));
    final VaultItem renamed = item.copyWith(title: 'Deck', published: true);
    expect(renamed.mediaType, MediaType.document);
    expect(renamed.mediaUrl, item.mediaUrl);
    final VaultItem back = VaultItem.fromJson(renamed.toJson());
    expect(back.mediaType, MediaType.document);
    expect(back.mediaUrl, item.mediaUrl);
  });

  testWidgets('a tile draws the thumbnail over its art, or the art alone',
      (WidgetTester tester) async {
    Future<void> pump(Widget child) => tester.pumpWidget(
          MaterialApp(
            theme: ShiftTheme.build(ShiftThemeId.retro),
            home: Center(child: SizedBox.square(dimension: 200, child: child)),
          ),
        );

    await pump(const MediaThumbnail(
      seed: 'a',
      thumbnailUrl: 'https://example.com/v1/thumb/a.png',
    ));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(PosterArt), findsOneWidget);

    await pump(const MediaThumbnail(seed: 'b'));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(PosterArt), findsOneWidget);

    // Audio has no picture: the art, and a symbol saying it is audio.
    await pump(const MediaThumbnail(seed: 'c', mediaType: MediaType.audio));
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
  });
}
