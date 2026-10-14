import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/theme/app_theme.dart';
import 'package:shift_ai/theme/tokens.dart';
import 'package:shift_ai/widgets/html_artifact.dart';
import 'package:shift_ai/widgets/markdown_text.dart';

const String _page = '''<!doctype html>
<html>
<head><title>Petal &amp; Pink</title><style>body{margin:0}</style></head>
<body><h1>Petal &amp; Pink</h1><button>Add to basket</button></body>
</html>''';

Future<void> _show(WidgetTester tester, String source) =>
    tester.pumpWidget(MaterialApp(
      theme: ShiftTheme.build(ShiftThemeId.values.first),
      home: Scaffold(body: SingleChildScrollView(child: MarkdownText(source))),
    ));

void main() {
  test('a page in a reply is read as one, with its language and end', () {
    final List<MdBlock> blocks =
        MdBlock.parse('Here is the page.\n\n```html\n$_page\n```\n\nEnjoy.');
    final MdCode code = blocks[1] as MdCode;
    expect(code.lang, 'html');
    expect(code.closed, isTrue);
    expect(HtmlArtifact.isPage(code.code, code.lang), isTrue);
    expect(blocks.last, isA<MdParagraph>());

    // Still being written: its fence has not closed.
    final MdCode open = MdBlock.parse('```html\n<!doctype html>\n<html><body>')
        .single as MdCode;
    expect(open.closed, isFalse);

    // A whole page given bare, with no fence.
    final MdCode bare = MdBlock.parse('Sure.\n$_page').last as MdCode;
    expect(bare.lang, 'html');
    expect(bare.closed, isTrue);
  });

  test('a short html example stays code to read', () {
    expect(HtmlArtifact.isPage('<br>', 'html'), isFalse);
    expect(HtmlArtifact.isPage('print(1)', 'python'), isFalse);
    expect(
        HtmlArtifact.isPage('<div><style>a{}</style></div>', 'html'), isTrue);
  });

  test('its name comes from its title, entities and all', () {
    expect(HtmlArtifact.titleOf(_page), 'Petal & Pink');
    expect(HtmlArtifact.titleOf('<p>no title</p>'), 'Web page');
    expect(HtmlArtifact.fileNameOf(_page), 'petal-pink.html');
  });

  testWidgets('a finished page is a website card, not a wall of source',
      (WidgetTester tester) async {
    await _show(tester, 'Here is the page.\n\n```html\n$_page\n```');
    expect(find.byType(HtmlArtifact), findsOneWidget);
    expect(find.text('Petal & Pink'), findsOneWidget);
    expect(find.text('Copy code'), findsOneWidget);
    // Off the web there is no browser to draw it, so the code shows and
    // the card says where to see the page.
    expect(find.textContaining('Open ShiftAi on the web'), findsOneWidget);
    expect(find.byType(CodeBlock), findsOneWidget);
  });

  testWidgets('a page still being written says so',
      (WidgetTester tester) async {
    await _show(tester, '```html\n<!doctype html>\n<html>\n<body>');
    expect(find.byType(HtmlArtifactBuilding), findsOneWidget);
    expect(find.textContaining('Building the page'), findsOneWidget);
    expect(find.byType(CodeBlock), findsNothing);
  });

  group('a page uses the pictures made in the chat', () {
    const List<PageAsset> made = <PageAsset>[
      PageAsset('image-0aa11bb2.png', 'https://cdn.example.com/u/first.png'),
      PageAsset('image-1c97aaa8.png', 'https://cdn.example.com/u/flower.png'),
    ];
    String use(String html) => HtmlArtifact.withAssets(html, made);

    test('by its file name, its stem, or the id on its link', () {
      expect(use('<img src="image-1c97aaa8.png">'),
          '<img src="https://cdn.example.com/u/flower.png">');
      expect(use("<img src='./images/image-0aa11bb2.jpg'>"),
          "<img src='https://cdn.example.com/u/first.png'>");
      expect(
          use('.hero{background:url(https://suite.shiftai.club/r/1c97aaa8)}'),
          ".hero{background:url('https://cdn.example.com/u/flower.png')}");
    });

    test(
        'a made-up picture name on no server is the newest picture: on 8 Oct '
        'the hero drew white words on a blank page', () {
      expect(use("background: url('pink-flower.jpg') center / cover"),
          "background: url('https://cdn.example.com/u/flower.png') center / cover");
      expect(use('<video poster="hero.webp">'),
          '<video poster="https://cdn.example.com/u/flower.png">');
    });

    test('real addresses, embedded pictures and links are left be', () {
      const String page = '<img src="https://images.example.com/rose.jpg">'
          '<img src="data:image/png;base64,AAAA">'
          '<a href="shop.html">Shop</a><script src="app.js"></script>';
      expect(use(page), page);
      expect(
          HtmlArtifact.withAssets('<img src="pink.jpg">', const <PageAsset>[]),
          '<img src="pink.jpg">');
    });
  });
}
