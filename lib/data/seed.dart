import 'package:flutter/material.dart';

import '../models/models.dart';

/// The demo account. Patches 0013 and 0014 are not deployed, so the client
/// must stand up fully on seeded rows and on-device state — nothing here
/// waits on a server.
abstract final class Seed {
  /// Brand kits a design can start from.
  static const List<String> brands = <String>[
    'ShiftAi — house',
    'ShiftAi — retro neon',
    'Client: Northline',
    'Client: Rooftop Coffee',
  ];

  /// The demo account is the app itself, never a person.
  ///
  /// This used to be a real name on a real iCloud address, which shipped
  /// in every build and showed up in the sidebar of anybody who opened the
  /// app without signing in — a private address handed out with the
  /// binary. A brand-new account should read as a demo, and this is what
  /// makes it obvious that nobody is signed in yet.
  static const Creator creator = Creator(
    // No '@': docs/API.md stores the bare handle and every screen adds the
    // '@' when it draws one.
    handle: 'shiftai',
    name: 'ShiftAi',
    email: 'demo@shiftai.club',
    initials: 'SA',
  );

  // Avatars ---------------------------------------------------------------

  static const List<Avatar> avatars = <Avatar>[
    Avatar(
        id: 'av-1',
        name: 'Everyday',
        status: AvatarStatus.ready,
        personal: true),
    Avatar(id: 'av-2', name: 'Studio lighting', status: AvatarStatus.training),
  ];

  // Leaderboard ---------------------------------------------------------

  static const int weekPool = 53497;
  static const String payoutLine = 'Pools pay Friday';

  static const List<StandingRow> standings = <StandingRow>[
    StandingRow(
      rank: 1,
      name: 'Marisol Vega',
      earnings: 11727.62,
      movement: 0,
      tier: TrophyTier.gold,
    ),
    StandingRow(
      rank: 2,
      name: 'Tomas Lindqvist',
      earnings: 7471.62,
      movement: 0,
      tier: TrophyTier.gold,
    ),
    StandingRow(
      rank: 3,
      name: 'Dee Okonkwo',
      earnings: 6083.49,
      movement: 0,
      tier: TrophyTier.gold,
    ),
    StandingRow(
      rank: 4,
      name: 'Grant Whitlock',
      earnings: 5171.03,
      movement: 2,
      tier: TrophyTier.silver,
    ),
    StandingRow(
      rank: 5,
      name: 'Ayesha Rahman',
      earnings: 4706.24,
      movement: 1,
      tier: TrophyTier.silver,
    ),
    StandingRow(
      rank: 6,
      name: 'Priya Balan',
      earnings: 3260.42,
      movement: -3,
      tier: TrophyTier.silver,
    ),
    StandingRow(
      rank: 7,
      name: 'Bea Lindholm',
      earnings: 1925.59,
      movement: -1,
      tier: TrophyTier.silver,
    ),
    StandingRow(
      rank: 8,
      name: 'Nina Sorokina',
      earnings: 1908.01,
      movement: 3,
      tier: TrophyTier.silver,
    ),
    StandingRow(
      rank: 9,
      name: 'Cassie Arnold',
      earnings: 1639.58,
      movement: -1,
      tier: TrophyTier.bronze,
    ),
    StandingRow(
      rank: 10,
      name: 'Ingrid Holm',
      earnings: 1275.42,
      movement: 1,
      tier: TrophyTier.bronze,
    ),
    StandingRow(
      rank: 11,
      name: 'Hector Salas',
      earnings: 1185.38,
      movement: -2,
      tier: TrophyTier.silver,
    ),
    StandingRow(
      rank: 12,
      name: 'Owen Mbeki',
      earnings: 953.83,
      movement: 0,
      tier: TrophyTier.bronze,
    ),
    StandingRow(
      rank: 13,
      name: 'You',
      earnings: 767.09,
      movement: 1,
      isYou: true,
      tier: TrophyTier.bronze,
    ),
    StandingRow(
      rank: 14,
      name: 'Lena Duval',
      earnings: 739.75,
      movement: -1,
      tier: TrophyTier.bronze,
    ),
    StandingRow(
      rank: 15,
      name: 'Sam Okafor',
      earnings: 612.40,
      movement: 0,
      tier: TrophyTier.bronze,
    ),
    StandingRow(
      rank: 16,
      name: 'Rin Watanabe',
      earnings: 548.12,
      movement: 2,
      tier: TrophyTier.bronze,
    ),
  ];

  // Local league ----------------------------------------------------------

  /// A demo cohort: not the same fifteen faces as the global board, on
  /// purpose — a local league is a different, smaller fight, and showing
  /// the same names in both would read as the same board twice.
  static const League league = League(
    division: TrophyTier.silver,
    regionLabel: 'Austin Metro',
    promoteCount: 3,
    relegateCount: 3,
    rows: <StandingRow>[
      StandingRow(rank: 1, name: 'Jodie Marsh', earnings: 412.80, movement: 1),
      StandingRow(rank: 2, name: 'Reese Cantu', earnings: 388.15, movement: -1),
      StandingRow(rank: 3, name: 'Wyatt Okafor', earnings: 355.60, movement: 0),
      StandingRow(
        rank: 4,
        name: 'You',
        earnings: 301.25,
        movement: 2,
        isYou: true,
      ),
      StandingRow(rank: 5, name: 'Priya Nair', earnings: 288.90, movement: -1),
      StandingRow(rank: 6, name: 'Leo Fontaine', earnings: 240.05, movement: 0),
      StandingRow(rank: 7, name: 'Ama Boateng', earnings: 199.70, movement: 3),
      StandingRow(rank: 8, name: 'Sana Malik', earnings: 176.40, movement: -2),
      StandingRow(rank: 9, name: 'Cole Petrov', earnings: 154.15, movement: 1),
      StandingRow(
          rank: 10, name: 'Iris Delgado', earnings: 121.60, movement: 0),
    ],
  );

  // Trophies ------------------------------------------------------------

  static final List<Trophy> trophies = <Trophy>[
    // Bronze, six.
    _t('first_light', 'First Light', 'Make your first piece',
        Icons.auto_awesome_rounded, TrophyTier.bronze,
        label: '1 of 1', members: 94, progress: 1, earnedOn: '2026-03-04'),
    _t('out_loud', 'Out Loud', 'Publish a piece to the EcoVault',
        Icons.public_rounded, TrophyTier.bronze,
        label: '0 of 1', members: 44),
    _t('on_the_board', 'On the Board', 'Appear on the weekly leaderboard',
        Icons.bar_chart_rounded, TrophyTier.bronze,
        label: '1 of 1', members: 72, progress: 1, earnedOn: '2026-07-06'),
    _t('first_dollar', 'First Dollar', 'Bank money from any pool',
        Icons.payments_outlined, TrophyTier.bronze,
        label: '1 of 1', members: 68, progress: 1, earnedOn: '2026-07-19'),
    _t('sound_check', 'Sound Check', 'Make your first track',
        Icons.graphic_eq_rounded, TrophyTier.bronze,
        label: '0 of 1', members: 31),
    _t('face_time', 'Face Time', 'Make your first avatar read',
        Icons.person_outline_rounded, TrophyTier.bronze,
        label: '0 of 1', members: 27),

    // Silver, six.
    _t('prolific', 'Prolific', 'Make ten pieces', Icons.grid_view_rounded,
        TrophyTier.silver,
        label: '8 of 10', members: 61, progress: 0.8),
    _t(
        'quadruple_threat',
        'Quadruple Threat',
        'Make a picture, a video, an avatar and a track',
        Icons.category_outlined,
        TrophyTier.silver,
        label: '2 of 4',
        members: 28,
        progress: 0.5),
    _t('curator', 'Curator', 'Publish five pieces', Icons.collections_outlined,
        TrophyTier.silver,
        label: '0 of 5', members: 19),
    _t('contender', 'Contender', 'Finish a week in the top fifty',
        Icons.trending_up_rounded, TrophyTier.silver,
        label: 'Best #13', members: 24, progress: 1, earnedOn: '2026-09-11'),
    _t('streak', 'Streak', 'Make something five days running',
        Icons.local_fire_department_outlined, TrophyTier.silver,
        label: '3 of 5', members: 22, progress: 0.6),
    _t('bankroll', 'Bankroll', 'Bank a thousand dollars',
        Icons.savings_outlined, TrophyTier.silver,
        label: '\$767 of \$1,000', members: 17, progress: 0.77),

    // Gold, four.
    _t('machine', 'Machine', 'Make a hundred pieces', Icons.factory_outlined,
        TrophyTier.gold,
        label: '8 of 100', members: 12, progress: 0.08),
    _t(
        'front_page',
        'Front Page',
        'Be the most-viewed piece in the EcoVault that week',
        Icons.workspace_premium_outlined,
        TrophyTier.gold,
        label: 'Needs EcoVault view counts',
        members: 3),
    _t('top_ten', 'Top Ten', 'Finish a week in the top ten',
        Icons.military_tech_outlined, TrophyTier.gold,
        label: 'Best #13', members: 6, progress: 0.3),
    _t('headliner', 'Headliner', 'Finish a week in the top three',
        Icons.star_outline_rounded, TrophyTier.gold,
        label: 'Best #13', members: 4, progress: 0.15),

    // Platinum, two.
    _t('champion', 'Champion', 'Finish a week at number one',
        Icons.emoji_events_outlined, TrophyTier.platinum,
        label: 'Best #13', members: 1, progress: 0.1),
    _t('untouchable', 'Untouchable', 'Finish three weeks at number one',
        Icons.shield_outlined, TrophyTier.platinum,
        label: 'Best #13', members: 0, progress: 0.05),
  ];

  static Trophy _t(
    String id,
    String name,
    String requirement,
    IconData glyph,
    TrophyTier tier, {
    required String label,
    required int members,
    double progress = 0,
    String? earnedOn,
  }) {
    return Trophy(
      id: id,
      name: name,
      requirement: requirement,
      glyph: glyph,
      tier: tier,
      progressLabel: label,
      memberPercent: members,
      progress: progress,
      earnedOn: earnedOn == null ? null : DateTime.parse(earnedOn),
    );
  }

  // Agents --------------------------------------------------------------

  static const String agentScope = 'shiftai/shift';

  /// What the scope picker offers. Only `agentScope` / `jobScope` are
  /// authorised; the rest need connecting first.
  static const List<String> agentScopes = <String>[
    agentScope,
    'shiftai/shift-server',
    'shiftai/shift-brand',
  ];
  static const List<String> jobScopes = <String>[
    jobScope,
    'Client deliverables',
    'Weekly exports',
  ];
  static const String jobScope = 'Quarterly reports';
  static const String jobPolicy = 'Accept edits, ask before commands';

  static const int agentsInAll = 5;
  static const int agentsWorking = 2;
  static const int agentsNeedYou = 1;
  static const int agentsInReview = 1;

  static const List<AgentRun> agentRuns = <AgentRun>[
    AgentRun(
      id: 'r-mono',
      title: 'Register monospace as a literal family name',
      detail: '',
      status: RunStatus.inReview,
      checksPassed: true,
      diff: '+128 -14',
      scope: agentScope,
    ),
    AgentRun(
      id: 'r-imports',
      title: 'Scan conditional imports before release build',
      detail: 'Unable to complete request',
      status: RunStatus.failed,
    ),
  ];

  static const List<JobRow> jobs = <JobRow>[
    JobRow(
      id: 'j-brief',
      title: 'Summarise every report into one brief',
      detail: 'Working · Quarterly reports',
      status: RunStatus.working,
    ),
    JobRow(
      id: 'j-receipts',
      title: 'Rename the receipts by date and vendor',
      detail: 'Run `mv` in this folder? · Scanned receipts',
      status: RunStatus.needsYou,
    ),
  ];

  // Design --------------------------------------------------------------

  static const List<DesignDoc> designs = <DesignDoc>[
    // One of each kind the thumbnails draw.
    DesignDoc(
      id: 'd-palette',
      title: 'Palette reference sheet',
      versions: 2,
      kindLabel: 'Brand',
    ),
    DesignDoc(
      id: 'd-tide',
      title: 'Tide clock landing page',
      versions: 1,
      kindLabel: 'Page',
    ),
    DesignDoc(
      id: 'd-recap',
      title: 'Launch week recap',
      versions: 3,
      kindLabel: 'Deck',
    ),
  ];

  static const List<SourceOption> sourceOptions = <SourceOption>[
    SourceOption(
      title: 'Sync from a repository',
      detail: 'Point ShiftAi at a repo; it reads the tokens and components '
          'from code.',
      icon: Icons.code_rounded,
    ),
    SourceOption(
      title: 'Build from connectors',
      detail: 'ShiftAi builds from your connected tools, or asks a few '
          'questions first.',
      icon: Icons.hub_outlined,
    ),
    SourceOption(
      title: 'Upload brand files',
      detail: 'Drop in logos, fonts, guidelines and token files; ShiftAi '
          'drafts from them.',
      icon: Icons.note_add_outlined,
    ),
  ];

  // Notes ---------------------------------------------------------------

  static final List<Note> notes = <Note>[
    Note(
      id: 'n-standup',
      title: 'Standup, Tuesday',
      editedAt: DateTime(2026, 9, 18, 9, 12),
      body: 'Ship the update banner behind the version check, then look at '
          'the fallback fonts folder before N2 closes.',
    ),
    Note(
      id: 'n-composer',
      title: 'Why the composer grows to eight lines',
      editedAt: DateTime(2026, 9, 16, 17, 40),
      body: 'People paste paragraphs. A single-line input is the most common '
          'way this component is got wrong.',
    ),
  ];

  // Suite ---------------------------------------------------------------

  /// The Create screen opens empty. This is the answer a first message gets,
  /// so the thread, the artifact card and the failure card are all reachable
  /// without a server.
  static const List<ChatMessage> cannedReply = <ChatMessage>[
    ChatMessage(
      id: 'm-reply',
      author: MessageAuthor.shift,
      eyebrow: 'ShiftAi · Video',
      body: 'Here is the cut. Take two starts at 00:14, so I used that one '
          'and ducked the room tone six decibels under the voice.',
      bullets: <String>[
        '0:00 to 0:06 — wide shot, no music',
        '0:06 to 0:14 — take two, voice up three decibels',
        '0:14 to 0:20 — logo hold on black',
      ],
      attachment: MessageAttachment(
        fileName: 'promo-vertical-v4.mp4',
        meta: '20S · 1080 × 1920 · 14 CREDITS',
        kind: MediaKind.video,
        vaultItemId: 'v-launch-promo',
      ),
    ),
    ChatMessage(
      id: 'm-failure',
      author: MessageAuthor.shift,
      body: '',
      failure: FailureInfo.planCheckUnreachable,
    ),
  ];

  // Vault ---------------------------------------------------------------

  static final List<VaultItem> vault = <VaultItem>[
    VaultItem(
      id: 'v-rooftop-3',
      title: 'Rooftop loop, take 3',
      kind: MediaKind.video,
      prompt: 'Slow push in on a rooftop at blue hour, city lights coming up '
          'behind, handheld feel, no people in frame.',
      model: 'HeyGen · video v2',
      createdAt: DateTime(2026, 9, 16, 21, 14),
      credits: 14,
      aspect: 9 / 16,
      durationSeconds: 6,
      width: 1080,
      height: 1920,
    ),
    VaultItem(
      id: 'v-cover-warm',
      title: 'Cover art, warm pass',
      kind: MediaKind.image,
      prompt: 'Square cover, warm grain, one figure lit from the side, '
          'type space left clear at the bottom.',
      model: 'Image · standard',
      createdAt: DateTime(2026, 9, 16, 18, 2),
      credits: 4,
      aspect: 1,
      width: 1024,
      height: 1024,
    ),
    VaultItem(
      id: 'v-avatar-v2',
      title: 'Avatar read, script v2',
      kind: MediaKind.video,
      prompt: 'Avatar reads the second script, neutral studio background, '
          'eye line to camera.',
      model: 'HeyGen · avatar IV',
      createdAt: DateTime(2026, 9, 15, 11, 40),
      credits: 22,
      aspect: 16 / 9,
      durationSeconds: 34,
      width: 1920,
      height: 1080,
    ),
    VaultItem(
      id: 'v-poster-blue',
      title: 'Poster, blue on black',
      kind: MediaKind.image,
      prompt: 'Poster, one electric blue on near black, wide tracked caps, '
          'a lot of empty space.',
      model: 'Image · standard',
      createdAt: DateTime(2026, 9, 14, 9, 25),
      credits: 4,
      aspect: 3 / 4,
      published: true,
      width: 1200,
      height: 1600,
    ),
    VaultItem(
      id: 'v-thumbs-4up',
      title: 'Thumbnail set, 4 up',
      kind: MediaKind.image,
      prompt: 'Four thumbnails from the same still, each cropped differently.',
      model: 'Image · fast',
      createdAt: DateTime(2026, 9, 13, 16, 8),
      credits: 3,
      aspect: 16 / 9,
      width: 1280,
      height: 720,
    ),
    VaultItem(
      id: 'v-product-spin',
      title: 'Product spin, 8s',
      kind: MediaKind.video,
      prompt: 'Slow turntable of the product on a seamless ground, one key '
          'light, no reflections on the label.',
      model: 'HeyGen · video v2',
      createdAt: DateTime(2026, 9, 12, 20, 51),
      credits: 16,
      aspect: 1,
      durationSeconds: 8,
      width: 1080,
      height: 1080,
    ),
    VaultItem(
      id: 'v-studio-still-9',
      title: 'Studio still, take 9',
      kind: MediaKind.image,
      prompt: 'Studio portrait, hard side light, dark ground, shoulders in '
          'frame.',
      model: 'Image · standard',
      createdAt: DateTime(2026, 9, 11, 13, 30),
      credits: 4,
      aspect: 4 / 5,
      width: 1024,
      height: 1280,
    ),
    VaultItem(
      id: 'v-launch-promo',
      title: 'Launch promo, vertical',
      kind: MediaKind.video,
      prompt: 'Twenty second vertical promo, take two of the read, room tone '
          'ducked under the voice.',
      model: 'HeyGen · video v2',
      createdAt: DateTime(2026, 9, 17, 9, 12),
      credits: 14,
      aspect: 9 / 16,
      durationSeconds: 20,
      width: 1080,
      height: 1920,
    ),
    VaultItem(
      id: 'v-grain-test',
      title: 'Grain test, three looks',
      kind: MediaKind.image,
      prompt: 'Same frame at three grain strengths, side by side.',
      model: 'Image · fast',
      createdAt: DateTime(2026, 9, 10, 8, 5),
      credits: 3,
      aspect: 3 / 2,
      width: 1536,
      height: 1024,
    ),
    VaultItem(
      id: 'v-title-card',
      title: 'Title card, black',
      kind: MediaKind.image,
      prompt: 'Title card, wordmark centred on black, generous clear space.',
      model: 'Image · standard',
      createdAt: DateTime(2026, 9, 9, 22, 47),
      credits: 2,
      aspect: 16 / 9,
      published: true,
      width: 1920,
      height: 1080,
    ),
    VaultItem(
      id: 'v-store-tile',
      title: 'Store tile loop, 6s',
      kind: MediaKind.video,
      prompt: 'Six second loop for the store tile, no cut visible at the seam.',
      model: 'HeyGen · video v2',
      createdAt: DateTime(2026, 9, 8, 15, 19),
      credits: 18,
      aspect: 1,
      durationSeconds: 6,
      width: 1080,
      height: 1080,
    ),
    VaultItem(
      id: 'v-crowd-plate',
      title: 'Crowd plate, wide',
      kind: MediaKind.image,
      prompt: 'Wide empty venue before doors, house lights half up.',
      model: 'Image · standard',
      createdAt: DateTime(2026, 9, 7, 19, 3),
      credits: 4,
      aspect: 21 / 9,
      width: 2100,
      height: 900,
    ),
  ];

  // EcoVault ------------------------------------------------------------

  /// What other members have published. Your own published pieces join
  /// this list at read time, so the gallery reads the same for everyone.
  ///
  /// `saved` is the viewer's own heart, which is why it lives on the row
  /// rather than on the piece: the same work comes back saved for one
  /// account and not for another.
  static final List<VaultItem> ecoVault = <VaultItem>[
    VaultItem(
      id: 'e-tide-clock',
      title: 'Tide clock, slow dissolve',
      kind: MediaKind.video,
      prompt: 'A tide clock on a weathered wall, light moving across it '
          'over a whole afternoon, one slow dissolve.',
      model: 'HeyGen · video v2',
      createdAt: DateTime(2026, 9, 17, 8, 12),
      credits: 18,
      aspect: 16 / 9,
      published: true,
      durationSeconds: 12,
      width: 1920,
      height: 1080,
      byHandle: 'marisol',
      byName: 'Marisol Vega',
      hearts: 1284,
      saved: true,
    ),
    VaultItem(
      id: 'e-salt-flats',
      title: 'Salt flats, first light',
      kind: MediaKind.image,
      prompt: 'Salt flats at first light, the crust cracked into hexagons, '
          'nothing on the horizon.',
      model: 'Image · standard',
      createdAt: DateTime(2026, 9, 16, 6, 40),
      credits: 5,
      aspect: 3 / 2,
      published: true,
      width: 2400,
      height: 1600,
      byHandle: 'tomas',
      byName: 'Tomas Lindqvist',
      hearts: 342,
    ),
    VaultItem(
      id: 'e-night-market',
      title: 'Night market, handheld',
      kind: MediaKind.video,
      prompt: 'Walking through a night market, handheld, neon on wet '
          'ground, no faces held longer than a beat.',
      model: 'HeyGen · video v2',
      createdAt: DateTime(2026, 9, 15, 21, 5),
      credits: 22,
      aspect: 9 / 16,
      published: true,
      durationSeconds: 15,
      width: 1080,
      height: 1920,
      byHandle: 'dee',
      byName: 'Dee Okonkwo',
      hearts: 97,
    ),
    VaultItem(
      id: 'e-paper-type',
      title: 'Paper type study',
      kind: MediaKind.image,
      prompt: 'Letterpress type study on heavy paper, one ink, raking '
          'light so the impression reads.',
      model: 'Image · standard',
      createdAt: DateTime(2026, 9, 15, 11, 30),
      credits: 4,
      aspect: 1,
      published: true,
      width: 2000,
      height: 2000,
      byHandle: 'ayesha',
      byName: 'Ayesha Rahman',
      hearts: 2051,
    ),
    VaultItem(
      id: 'e-kiln',
      title: 'Kiln opening, 30s',
      kind: MediaKind.video,
      prompt: 'A kiln opened while still warm, heat haze over glaze, the '
          'first look at what survived.',
      model: 'HeyGen · video v2',
      createdAt: DateTime(2026, 9, 14, 17, 55),
      credits: 26,
      aspect: 4 / 3,
      published: true,
      durationSeconds: 30,
      width: 1600,
      height: 1200,
      byHandle: 'grant',
      byName: 'Grant Whitlock',
      hearts: 618,
    ),
    VaultItem(
      id: 'e-ferry',
      title: 'Ferry wake at dusk',
      kind: MediaKind.image,
      prompt: 'The wake behind a ferry at dusk, long exposure, the water '
          'gone to glass.',
      model: 'Image · standard',
      createdAt: DateTime(2026, 9, 13, 19, 20),
      credits: 5,
      aspect: 2 / 3,
      published: true,
      width: 1600,
      height: 2400,
      byHandle: 'priya',
      byName: 'Priya Balan',
      hearts: 45,
      saved: true,
    ),
  ];
}
