import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The signed-in creator.
@immutable
class Creator {
  const Creator({
    required this.handle,
    required this.name,
    required this.email,
    required this.initials,
  });

  final String handle;
  final String name;
  final String email;
  final String initials;

  /// The handle with no leading `@`, whatever the engine sent. Every
  /// screen draws the `@` itself, so one arriving in the value would be
  /// shown twice — which is exactly what `@@shiftai` was.
  String get bareHandle =>
      handle.startsWith('@') ? handle.substring(1) : handle;

  Creator copyWith({String? handle, String? name, String? email}) => Creator(
        handle: handle ?? this.handle,
        name: name ?? this.name,
        email: email ?? this.email,
        initials: initials,
      );
}

/// Trophy and leaderboard tiers. Points come from the tier, so a trophy
/// cannot be worth an amount its rank does not allow.
enum TrophyTier {
  bronze('Bronze', 10, TierColors.bronze),
  silver('Silver', 25, TierColors.silver),
  gold('Gold', 50, TierColors.gold),
  platinum('Platinum', 100, TierColors.platinum);

  const TrophyTier(this.label, this.points, this.color);

  final String label;
  final int points;

  /// The colour for a dark ground. Use [colorOn] wherever the theme can
  /// be a light one.
  final Color color;

  /// The tier colour for the theme in play.
  Color colorOn(ShiftColors c) {
    if (c.isDarkGround) return color;
    return switch (this) {
      TrophyTier.bronze => TierColors.bronzeOnLight,
      TrophyTier.silver => TierColors.silverOnLight,
      TrophyTier.gold => TierColors.goldOnLight,
      TrophyTier.platinum => TierColors.platinumOnLight,
    };
  }
}

@immutable
class Trophy {
  const Trophy({
    required this.id,
    required this.name,
    required this.requirement,
    required this.glyph,
    required this.tier,
    required this.progressLabel,
    required this.memberPercent,
    this.progress = 0,
    this.earnedOn,
  });

  final String id;
  final String name;

  /// Reads as the description once earned and as the requirement before —
  /// the same sentence works for both.
  final String requirement;
  final IconData glyph;
  final TrophyTier tier;

  /// The short line under the bar: "1 of 1", "Best #13", or what is
  /// missing before the trophy can be scored at all. Sentence case, as
  /// sent — the client decides how to set it.
  final String progressLabel;

  /// How many members hold it.
  final int memberPercent;

  /// 0 to 1, for the bar.
  final double progress;
  final DateTime? earnedOn;

  bool get earned => earnedOn != null;
  int get points => tier.points;

  /// The same trophy with nothing achieved against it: the artwork and
  /// the requirement, none of the progress. This is what a trophy is
  /// before a server says otherwise.
  Trophy unearned() => Trophy(
        id: id,
        name: name,
        requirement: requirement,
        glyph: glyph,
        tier: tier,
        // "8 of 10" becomes "0 of 10": the target is part of the trophy,
        // the count is not. Anything else (a "Best #13") is the server's
        // sentence and there is nothing to keep.
        progressLabel: _zeroed(progressLabel),
        // How many members hold it is a fact about everyone else, which
        // only the server knows. Zero reads as "not said" in the UI.
        memberPercent: 0,
        progress: 0,
      );

  static final RegExp _outOf = RegExp(r'^\s*\d+\s+OF\s+(\d+)\s*$');

  static String _zeroed(String label) {
    final RegExpMatch? m = _outOf.firstMatch(label.toUpperCase());
    // Matched case-blind, so a server that still shouts is understood,
    // but written back in the case everything else on the shelf is in.
    return m == null ? '' : '0 of ${m.group(1)}';
  }

  /// The catalogue — name, glyph, tier — is the client's; how far along
  /// you are is the server's, so those are the fields that can be replaced.
  Trophy copyWith({
    DateTime? earnedOn,
    double? progress,
    String? progressLabel,
    int? memberPercent,
  }) =>
      Trophy(
        id: id,
        name: name,
        requirement: requirement,
        glyph: glyph,
        tier: tier,
        progressLabel: progressLabel ?? this.progressLabel,
        memberPercent: memberPercent ?? this.memberPercent,
        progress: progress ?? this.progress,
        earnedOn: earnedOn ?? this.earnedOn,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'earnedOn': earnedOn?.toIso8601String(),
      };
}

/// One row of the weekly board.
@immutable
class StandingRow {
  const StandingRow({
    required this.rank,
    required this.name,
    required this.earnings,
    required this.movement,
    this.tier,
    this.isYou = false,
    this.avatarUrl,
  });

  final int rank;
  final String name;
  final double earnings;

  /// Places gained (positive) or lost (negative) since the week opened.
  final int movement;

  /// The payout band this creator is in this week, when they are in one.
  final TrophyTier? tier;
  final bool isYou;

  /// The personal avatar HeyGen rendered for this creator, when they have
  /// one. Hosted by the server, not carried in bytes, so a stranger's face
  /// showing up here costs nothing on your device.
  final String? avatarUrl;

  String get initials {
    final List<String> words =
        name.split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rank': rank,
        'name': name,
        'earnings': earnings,
        'movement': movement,
        'tier': tier?.name,
        'isYou': isYou,
        'avatarUrl': avatarUrl,
      };

  factory StandingRow.fromJson(Map<String, dynamic> json) => StandingRow(
        rank: (json['rank'] as num).toInt(),
        name: json['name'] as String,
        earnings: (json['earnings'] as num).toDouble(),
        movement: (json['movement'] as num?)?.toInt() ?? 0,
        tier: json['tier'] == null
            ? null
            : TrophyTier.values.firstWhere(
                (TrophyTier t) => t.name == json['tier'],
                orElse: () => TrophyTier.bronze,
              ),
        isYou: json['isYou'] as bool? ?? false,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

/// Where a HeyGen avatar is in its lifecycle. Training is not instant, so
/// a freshly created one sits here until the render is ready to watch.
enum AvatarStatus { training, ready, failed }

/// An animated likeness a creator can use as their profile picture, on the
/// leaderboard, and to generate with in the Suite.
///
/// Everyone starts with none. Exactly one — the personal one — stands in
/// for the static photo everywhere the app used to draw one; the rest sit
/// in the gallery for the Suite to call on.
@immutable
class Avatar {
  const Avatar({
    required this.id,
    required this.name,
    required this.status,
    this.personal = false,
    this.previewUrl,
  });

  final String id;
  final String name;
  final AvatarStatus status;

  /// The server enforces that only one avatar is personal at a time; this
  /// just reflects whichever one it last said was.
  final bool personal;

  /// A still or looping clip HeyGen rendered for it. Null while [status]
  /// is `training`.
  final String? previewUrl;

  bool get ready => status == AvatarStatus.ready;

  Avatar copyWith({
    AvatarStatus? status,
    bool? personal,
    String? previewUrl,
  }) =>
      Avatar(
        id: id,
        name: name,
        status: status ?? this.status,
        personal: personal ?? this.personal,
        previewUrl: previewUrl ?? this.previewUrl,
      );
}

/// A small board of people near this account in both rank and location —
/// a fair fight instead of the whole board, the same idea as Duolingo's
/// weekly leagues. Division is a rung on a ladder, promoted or relegated
/// week to week; reusing [TrophyTier] for it is a second, unrelated use
/// of the same four names and colours, not the same thing as a payout
/// band.
@immutable
class League {
  const League({
    required this.division,
    required this.regionLabel,
    required this.rows,
    required this.promoteCount,
    required this.relegateCount,
  });

  final TrophyTier division;

  /// Wherever the server resolved this account's location to — a metro
  /// area, not a street address.
  final String regionLabel;

  /// Same row shape as the global board, scoped to this cohort.
  final List<StandingRow> rows;

  /// How many of the top and bottom ranks move divisions when the week
  /// closes.
  final int promoteCount;
  final int relegateCount;

  StandingRow? get you => rows.where((StandingRow r) => r.isYou).firstOrNull;

  static League? fromJson(Map<String, dynamic> json) {
    final Object? divisionRaw = json['division'];
    final Object? rowsRaw = json['rows'];
    // An account with nowhere placed yet is `{}`, not an error — same
    // reasoning as an empty list everywhere else in this contract. Reading
    // that as a league with no rows would draw an empty board instead of
    // the "share your location" prompt the person actually needs to see.
    if (divisionRaw is! String || rowsRaw is! List) return null;
    return League(
      division: TrophyTier.values.firstWhere(
        (TrophyTier t) => t.name == divisionRaw,
        orElse: () => TrophyTier.bronze,
      ),
      regionLabel: json['regionLabel'] as String? ?? '',
      rows: rowsRaw
          .map((Object? r) => StandingRow.fromJson(r! as Map<String, dynamic>))
          .toList(),
      promoteCount: (json['promoteCount'] as num?)?.toInt() ?? 0,
      relegateCount: (json['relegateCount'] as num?)?.toInt() ?? 0,
    );
  }
}

enum MediaKind { image, video }

enum VaultScope {
  mine('My vault'),
  eco('EcoVault');

  const VaultScope(this.label);
  final String label;
}

@immutable
class VaultItem {
  const VaultItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.prompt,
    required this.model,
    required this.createdAt,
    required this.credits,
    required this.aspect,
    this.published = false,
    this.durationSeconds,
    this.width,
    this.height,
    this.byHandle,
    this.byName,
    this.saved = false,
  });

  final String id;
  final String title;
  final MediaKind kind;
  final String prompt;
  final String model;
  final DateTime createdAt;
  final int credits;
  final double aspect;
  final bool published;
  final int? durationSeconds;
  final int? width;
  final int? height;

  /// Who made it. Null means you did — a piece in your own vault carries
  /// no author because the vault is the answer.
  final String? byHandle;
  final String? byName;

  /// Whether *the person looking* has hearted it. This is a fact about
  /// the viewer, not about the piece, which is why the same row can come
  /// back saved for one account and not for another.
  final bool saved;

  /// True for your own work. Everything that edits a piece — rename,
  /// publish, delete — is gated on this: someone else's published work is
  /// theirs, and saving it does not make it yours.
  bool get mine => byHandle == null;

  String get dimensions {
    if (width == null || height == null) return '';
    return '$width × $height';
  }

  VaultItem copyWith({String? title, bool? published, bool? saved}) =>
      VaultItem(
        id: id,
        title: title ?? this.title,
        kind: kind,
        prompt: prompt,
        model: model,
        createdAt: createdAt,
        credits: credits,
        aspect: aspect,
        published: published ?? this.published,
        durationSeconds: durationSeconds,
        width: width,
        height: height,
        byHandle: byHandle,
        byName: byName,
        saved: saved ?? this.saved,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'kind': kind.name,
        'prompt': prompt,
        'model': model,
        'createdAt': createdAt.toIso8601String(),
        'credits': credits,
        'aspect': aspect,
        'published': published,
        'durationSeconds': durationSeconds,
        'width': width,
        'height': height,
        'byHandle': byHandle,
        'byName': byName,
        'saved': saved,
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
        id: json['id'] as String,
        title: json['title'] as String,
        kind: MediaKind.values.firstWhere(
          (MediaKind k) => k.name == json['kind'],
          orElse: () => MediaKind.image,
        ),
        prompt: json['prompt'] as String? ?? '',
        model: json['model'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        credits: (json['credits'] as num?)?.toInt() ?? 0,
        aspect: (json['aspect'] as num?)?.toDouble() ?? 1,
        published: json['published'] as bool? ?? false,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        byHandle: json['byHandle'] as String?,
        byName: json['byName'] as String?,
        saved: json['saved'] as bool? ?? false,
      );
}

@immutable
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.editedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime editedAt;

  String get snippet {
    final String flat = body.replaceAll('\n', ' ').trim();
    return flat;
  }

  Note copyWith({String? title, String? body, DateTime? editedAt}) => Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        editedAt: editedAt ?? this.editedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'editedAt': editedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        body: json['body'] as String? ?? '',
        editedAt: DateTime.tryParse(json['editedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// What an agent run is doing right now.
enum RunStatus {
  working('Working'),
  needsYou('Needs you'),
  inReview('In review'),
  done('Done'),
  failed('Failed');

  const RunStatus(this.label);
  final String label;
}

/// A row on the Agents tab: one run against one repository.
@immutable
class AgentRun {
  const AgentRun({
    required this.id,
    required this.title,
    required this.detail,
    required this.status,
    this.checksPassed = false,
    this.diff,
    this.scope,
  });

  final String id;
  final String title;

  /// The line under the title, when it is not built from the other fields.
  final String detail;
  final RunStatus status;
  final bool checksPassed;

  /// "+128 -14", when the run produced a change.
  final String? diff;
  final String? scope;
}

/// A row on the Jobs tab: work running in a folder rather than a repo.
@immutable
class JobRow {
  const JobRow({
    required this.id,
    required this.title,
    required this.detail,
    required this.status,
    this.scope,
  });

  final String id;
  final String title;
  final String detail;
  final RunStatus status;

  /// The folder the job runs in. Null means it predates scoping and is
  /// shown under whichever scope is selected.
  final String? scope;
}

/// One saved piece in the Design hub.
@immutable
class DesignDoc {
  const DesignDoc({
    required this.id,
    required this.title,
    required this.versions,
    required this.kindLabel,
  });

  final String id;
  final String title;
  final int versions;

  /// What shows on the thumbnail: PAGE, DECK, BRAND.
  final String kindLabel;

  String get versionLabel =>
      versions == 1 ? 'One version' : '$versions versions';
}

/// The four things the Design hub can start.
enum DesignKind {
  slides('Slides', 'Paste your notes and turn them into slides',
      Icons.slideshow_outlined),
  design('Design', 'Describe an idea and turn it into a design',
      Icons.design_services_outlined),
  codebase('Design in codebase', 'What should this design change in the repo?',
      Icons.terminal_rounded),
  brand(
      'Brand', 'What should this brand be built from?', Icons.palette_outlined);

  const DesignKind(this.label, this.prompt, this.icon);

  final String label;

  /// The headline on the editor's left pane.
  final String prompt;
  final IconData icon;

  /// What a new one is called before it is named.
  String get untitled => switch (this) {
        DesignKind.slides => 'Untitled slides',
        DesignKind.design => 'Untitled design',
        DesignKind.codebase => 'Untitled branch',
        DesignKind.brand => 'Untitled brand',
      };

  /// The label on the right pane's own header.
  String get paneLabel => switch (this) {
        DesignKind.slides => 'Slides',
        DesignKind.design => 'Design',
        DesignKind.codebase => 'Codebase',
        DesignKind.brand => 'Brand',
      };

  String get emptyLine => switch (this) {
        DesignKind.slides => 'This deck has no slides yet. Add one, or let '
            'SHIFT add some.',
        DesignKind.design => 'This canvas has no artboards yet. Add one, or '
            'let SHIFT add some.',
        DesignKind.codebase =>
          'No branch yet. Pick a repository and SHIFT opens one.',
        DesignKind.brand => 'This brand has no pages yet. Add one, or let '
            'SHIFT draft them.',
      };

  String get emptyAction => switch (this) {
        DesignKind.slides => 'Add a slide',
        DesignKind.design => 'Add an artboard',
        DesignKind.codebase => 'Open a branch',
        DesignKind.brand => 'Add a page',
      };

  /// Slides and Design start from a brand; the other two start from a source.
  bool get startsFromBrand =>
      this == DesignKind.slides || this == DesignKind.design;
}

/// How a Brand or Codebase editor can be seeded.
@immutable
class SourceOption {
  const SourceOption({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;
}

enum MessageAuthor { you, shift }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.body,
    this.eyebrow,
    this.bullets = const <String>[],
    this.attachment,
    this.failure,
  });

  final String id;
  final MessageAuthor author;
  final String body;
  final String? eyebrow;
  final List<String> bullets;
  final MessageAttachment? attachment;
  final FailureInfo? failure;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'author': author.name,
        'body': body,
        'eyebrow': eyebrow,
        'bullets': bullets,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        author: MessageAuthor.values.firstWhere(
          (MessageAuthor a) => a.name == json['author'],
          orElse: () => MessageAuthor.you,
        ),
        body: json['body'] as String? ?? '',
        eyebrow: json['eyebrow'] as String?,
        bullets: (json['bullets'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic b) => b as String)
            .toList(),
      );
}

@immutable
class MessageAttachment {
  const MessageAttachment({
    required this.fileName,
    required this.meta,
    required this.kind,
    required this.vaultItemId,
  });

  final String fileName;
  final String meta;
  final MediaKind kind;
  final String vaultItemId;
}

/// The shape of the plan-check failure. A 503 here is
/// `shift.within_ceiling` being unreachable (migration 0011) — never a
/// verdict about the plan, and the card says so.
@immutable
class FailureInfo {
  const FailureInfo({
    required this.sentence,
    required this.reassurance,
    required this.details,
  });

  final String sentence;
  final String reassurance;
  final String details;

  static const FailureInfo planCheckUnreachable = FailureInfo(
    sentence: 'Could not check your plan right now.',
    reassurance:
        'Nothing was charged. This is the plan check being unreachable, '
        'not a decision about your plan — the next run will try again.',
    details: '503 · shift.within_ceiling unreachable · migration 0011',
  );
}
