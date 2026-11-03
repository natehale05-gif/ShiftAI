import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoAlertDialog;
import 'package:flutter/material.dart' show Size, TextField, TextInputAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/api/http_repository.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

const ChatModel _chat = ChatModel(id: 'chat', name: 'Chat', isDefault: true);
const ChatModel _image = ChatModel(
  id: 'shift-image',
  name: 'SHIFT Image',
  bestFor: <TaskKind>{TaskKind.image},
);

/// Answers every message; records what it was sent and what it kept.
class _Engine extends SeedRepository {
  _Engine({this.serverProjects});

  final List<Project>? serverProjects;
  final List<
      ({
        String prompt,
        String? model,
        List<SentFile> files,
        List<ChatTurn> history
      })> sent = [];
  final List<Project> savedProjects = <Project>[];
  final List<String> deletedProjects = <String>[];
  final List<ChatThread> savedThreads = <ChatThread>[];

  @override
  Future<ShiftSnapshot> load() async {
    final ShiftSnapshot s = await super.load();
    return ShiftSnapshot(
      creator: s.creator,
      standings: s.standings,
      trophies: s.trophies,
      vault: <VaultItem>[
        VaultItem.fromJson(<String, dynamic>{
          ...Seed.vault.first.toJson(),
          'id': 'v-logo',
          'title': 'Ferry logo',
          'kind': 'image',
          'mediaType': 'image',
          'mediaUrl': 'https://app.example.com/media/logo.png',
        }..remove('byHandle')),
      ],
      ecoVault: s.ecoVault,
      notes: <Note>[
        Note(
          id: 'n-brief',
          title: 'Brand brief',
          body: 'Ferry Co. Teal and sand. Never say "cheap".',
          editedAt: DateTime.utc(2026, 11, 1),
        ),
      ],
      agentRuns: s.agentRuns,
      jobs: s.jobs,
      designs: s.designs,
      connectors: s.connectors,
      weekPool: s.weekPool,
      payoutLine: s.payoutLine,
      avatars: s.avatars,
      models: const <ChatModel>[_chat, _image],
      projects: serverProjects,
    );
  }

  @override
  Future<List<ChatMessage>> send(
    String prompt, {
    bool private = false,
    String? avatarId,
    String? model,
    List<ChatTurn> history = const <ChatTurn>[],
    Future<void>? cancel,
    void Function(String soFar)? onText,
    List<SentFile> files = const <SentFile>[],
  }) async {
    sent.add((prompt: prompt, model: model, files: files, history: history));
    return <ChatMessage>[
      ChatMessage(
        id: 'r${sent.length}',
        author: MessageAuthor.shift,
        body: 'Reply ${sent.length}',
        model: model,
      ),
    ];
  }

  @override
  Future<void> saveProject(Project project) async => savedProjects.add(project);

  @override
  Future<void> deleteProject(String id) async => deletedProjects.add(id);

  @override
  Future<void> saveThread(ChatThread thread) async => savedThreads.add(thread);
}

class _StubAuth implements AuthService {
  @override
  Future<void> signOut(String refreshToken) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<(AppState, _Engine)> _signedIn({
  Map<String, Object> prefs = const <String, Object>{},
  List<Project>? serverProjects,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'shift-backend': 'https://api.example.com',
    ...prefs,
  });
  final TokenStore tokens = MemoryTokenStore();
  await tokens.write(Session(
    accessToken: 'a',
    refreshToken: 'r',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    creator: Seed.creator,
  ));
  final AuthController auth =
      AuthController(service: _StubAuth(), store: tokens);
  await auth.restore();
  final _Engine engine = _Engine(serverProjects: serverProjects);
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
  return (state, engine);
}

Future<void> _settle() async {
  for (int i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<String> _blob(AppState state) async {
  await state.flush();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(StoreKeys.app)!;
}

/// "Ferry launch": instructions, a note, a vault picture and an upload.
Future<(AppState, _Engine, Project)> _withProject() async {
  final (AppState state, _Engine engine) = await _signedIn();
  final Project p = state.createProject('Ferry launch');
  state.setProjectInstructions(p.id, 'Write for commuters. Short lines.');
  state.addProjectResource(
    p.id,
    const ProjectResource(
        kind: ProjectResourceKind.note, ref: 'n-brief', name: 'Brand brief'),
  );
  state.addProjectResource(
    p.id,
    const ProjectResource(
        kind: ProjectResourceKind.vault, ref: 'v-logo', name: 'Ferry logo'),
  );
  state.addProjectResource(
    p.id,
    const ProjectResource(
      kind: ProjectResourceKind.file,
      ref: 'up-9',
      name: 'schedule.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 2048,
    ),
  );
  return (state, engine, p);
}

void main() {
  test(
      'a chat in a project is given its instructions, notes and files; the '
      'thread shows what was typed', () async {
    final (AppState state, _Engine engine, Project p) = await _withProject();
    expect(state.surface, Surface.project);
    state.newChatIn(p.id);
    expect(state.surface, Surface.suite);
    expect(state.chromeTitle, 'Ferry launch');

    state.sendMessage('Write a caption for the launch');
    await _settle();

    final String prompt = engine.sent.last.prompt;
    expect(prompt, contains('the project "Ferry launch"'));
    expect(prompt, contains('Write for commuters. Short lines.'));
    expect(prompt, contains('### Brand brief'));
    expect(prompt, contains('Never say "cheap".'));
    expect(
        prompt, contains('Project files (attached): Ferry logo, schedule.pdf'));
    expect(prompt, endsWith('Write a caption for the launch'));
    final List<SentFile> files = engine.sent.last.files;
    expect(files.map((SentFile f) => f.vaultItemId ?? f.uploadId),
        <String>['v-logo', 'up-9']);
    expect(files.first.url, 'https://app.example.com/media/logo.png');

    // What is on screen, and what goes back as history, is what was typed.
    expect(state.messages.first.body, 'Write a caption for the launch');
    state.sendMessage('Shorter');
    await _settle();
    expect(
        engine.sent.last.history.first.body, 'Write a caption for the launch');
    expect(engine.sent.last.prompt, endsWith('Shorter'));

    // Saved in the project.
    expect(state.threads.single.projectId, p.id);
    expect(state.threadsIn(p.id), hasLength(1));
    expect(engine.savedThreads.last.projectId, p.id);
  });

  test('an image model in a project is sent the words alone', () async {
    final (AppState state, _Engine engine, Project p) = await _withProject();
    state.newChatIn(p.id);
    state.sendMessage('generate an image of a teal ferry');
    await _settle();
    expect(engine.sent.last.model, _image.id);
    expect(engine.sent.last.prompt, 'generate an image of a teal ferry',
        reason: 'a page of notes in an image prompt would be drawn');
    expect(engine.sent.last.files, isEmpty);
  });

  test('a chat outside any project is sent as typed', () async {
    final (AppState state, _Engine engine, _) = await _withProject();
    state.clearThread();
    state.setSurface(Surface.suite);
    state.sendMessage('Hello');
    await _settle();
    expect(engine.sent.last.prompt, 'Hello');
    expect(state.threads.single.projectId, isNull);
  });

  test('chats move in and out; deleting a project keeps its chats', () async {
    final (AppState state, _Engine engine, Project p) = await _withProject();
    state.clearThread();
    state.sendMessage('A loose chat');
    await _settle();
    final String id = state.threads.single.id;
    expect(state.currentProjectId, isNull);

    state.moveThread(id, p.id);
    expect(state.threadsIn(p.id).single.id, id);
    expect(state.currentProjectId, p.id, reason: 'it is the one on screen');
    expect(engine.savedThreads.last.projectId, p.id);

    state.moveThread(id, null);
    expect(state.threadsIn(p.id), isEmpty);
    state.moveThread(id, p.id);

    state.deleteProject(p.id);
    expect(state.projects, isEmpty);
    expect(state.threads.single.id, id, reason: 'the chat is kept');
    expect(state.threads.single.projectId, isNull);
    expect(state.currentProjectId, isNull);
    expect(engine.deletedProjects, <String>[p.id]);
  });

  test('projects and the chats in them survive a restart', () async {
    final (AppState state, _, Project p) = await _withProject();
    state.newChatIn(p.id);
    state.sendMessage('Plan the week');
    await _settle();
    final String blob = await _blob(state);

    final (AppState again, _) =
        await _signedIn(prefs: <String, Object>{StoreKeys.app: blob});
    final Project back = again.projects.single;
    expect(back.name, 'Ferry launch');
    expect(back.instructions, 'Write for commuters. Short lines.');
    expect(back.resources.map((ProjectResource r) => r.key), <String>[
      'note:n-brief',
      'vault:v-logo',
      'file:up-9',
    ]);
    expect(again.threads.single.projectId, back.id);
    again.openThread(again.threads.single.id);
    expect(again.currentProjectId, back.id);
  });

  test(
      'the server\'s projects load, merged by newest; a deleted one stays '
      'deleted', () async {
    final Project onServer = Project(
      id: 'project-laptop',
      name: 'From the laptop',
      updatedAt: DateTime.utc(2026, 11, 2),
    );
    final (AppState state, _Engine engine) =
        await _signedIn(serverProjects: <Project>[onServer]);
    expect(state.projects.single.name, 'From the laptop');

    state.deleteProject('project-laptop');
    await state.refresh();
    expect(state.projects, isEmpty,
        reason: 'the server still lists it; it does not come back');
    expect(
        engine.deletedProjects, <String>['project-laptop', 'project-laptop']);
  });

  test('signing out takes the account\'s projects with it', () async {
    final (AppState state, _, _) = await _withProject();
    await state.signOut();
    expect(state.projects, isEmpty);
    expect(await _blob(state), isNot(contains('Ferry launch')));
  });

  group('over HTTP', () {
    test('GET, PUT and DELETE /v1/projects, and an engine without them',
        () async {
      final List<String> seen = <String>[];
      final HttpRepository repo = HttpRepository(ApiClient(
        baseUrl: 'https://api.example.com',
        client: _Client((http.Request r) {
          seen.add('${r.method} ${r.url.path}');
          if (r.url.path.startsWith('/v1/projects/')) {
            if (r.method == 'PUT') {
              expect(jsonDecode(r.body)['name'], 'Ferry launch');
            }
            return http.Response('{}', 200);
          }
          return http.Response('{"message":"no route"}', 404);
        }),
      ));
      final Project p = Project(
        id: 'project-1',
        name: 'Ferry launch',
        updatedAt: DateTime.utc(2026, 11, 3),
        resources: const <ProjectResource>[
          ProjectResource(
              kind: ProjectResourceKind.note, ref: 'n1', name: 'Brief'),
        ],
      );
      await repo.saveProject(p);
      await repo.deleteProject('project-1');
      expect(seen, <String>[
        'PUT /v1/projects/project-1',
        'DELETE /v1/projects/project-1',
      ]);
      final HttpRepository none = HttpRepository(ApiClient(
        baseUrl: 'https://api.example.com',
        client: _Client((_) => http.Response('{"message":"no route"}', 404)),
      ));
      await none.saveProject(p);
      await none.deleteProject('project-1');

      final Project? back =
          Project.tryParse(jsonDecode(jsonEncode(p.toJson())));
      expect(back?.resources.single.key, 'note:n1');
      expect(Project.tryParse(<String, dynamic>{'id': 'x'})?.name,
          'Untitled project');
    });
  });

  testWidgets(
      'New project in the sidebar names it and opens it; a new chat there '
      'says it is in the project', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final (AppState state, _) = await _signedIn();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pumpAndSettle();
    final Finder close = find.byTooltip('Close');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Projects'), findsOneWidget);
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(TextField),
      ),
      'Ferry launch',
    );
    await tester.pumpAndSettle();
    // Return creates it, as on an iPhone: it used to do nothing.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(state.surface, Surface.project);
    expect(find.text('Ferry launch'), findsWidgets);
    expect(find.text('Instructions'), findsOneWidget);
    expect(find.text('Files and notes'), findsOneWidget);

    await tester.tap(find.text('New chat in this project'));
    await tester.pumpAndSettle();
    expect(state.surface, Surface.suite);
    expect(find.text('In Ferry launch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sidebar opens on a wide screen with projects in it',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (AppState state, _) = await _signedIn();
    state.createProject('Ferry launch', open: false);
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pumpAndSettle();
    final Finder close = find.byTooltip('Close');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await tester.pumpAndSettle();
    }
    if (find.byTooltip('Open the sidebar').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Open the sidebar'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('New project'), findsOneWidget);
    await tester.tap(find.text('Ferry launch'));
    await tester.pumpAndSettle();
    expect(state.surface, Surface.project);
    expect(tester.takeException(), isNull);
  });
}

class _Client extends http.BaseClient {
  _Client(this.route);
  final http.Response Function(http.Request) route;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final http.Response r = route(request as http.Request);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(r.body)),
      r.statusCode,
      request: request,
    );
  }
}
