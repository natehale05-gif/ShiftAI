import 'package:flutter/foundation.dart';

/// What the real client reads from the `connections` table over PostgREST.
/// The OAuth flow itself lives in `server-patch/connection/index.js`; until
/// that is wired up the catalogue is static and only three are live.
@immutable
class Connector {
  const Connector(this.name, {this.live = false});

  final String name;
  final bool live;

  String get initials {
    final List<String> words = name
        .split(RegExp(r'[\s/]+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

abstract final class ConnectorCatalog {
  static const List<Connector> all = <Connector>[
    Connector('Gmail', live: true),
    Connector('Google Calendar', live: true),
    Connector('GitHub', live: true),
    Connector('Google Drive'),
    Connector('Slack'),
    Connector('Notion'),
    Connector('Dropbox'),
    Connector('Figma'),
    Connector('Linear'),
    Connector('Stripe'),
    Connector('Shopify'),
    Connector('YouTube'),
    Connector('Instagram'),
    Connector('TikTok'),
    Connector('Discord'),
    Connector('Zoom'),
    Connector('Airtable'),
    Connector('Asana'),
    Connector('Trello'),
    Connector('Jira'),
    Connector('Confluence'),
    Connector('HubSpot'),
    Connector('Salesforce'),
    Connector('Mailchimp'),
    Connector('Zapier'),
    Connector('Webflow'),
    Connector('WordPress'),
    Connector('Squarespace'),
    Connector('Vimeo'),
    Connector('Twitch'),
    Connector('Spotify'),
    Connector('SoundCloud'),
    Connector('Adobe Creative Cloud'),
    Connector('Canva'),
    Connector('Frame io'),
    Connector('Box'),
    Connector('OneDrive'),
    Connector('SharePoint'),
    Connector('Outlook'),
    Connector('Microsoft Teams'),
    Connector('Telegram'),
    Connector('Reddit'),
    Connector('Pinterest'),
    Connector('LinkedIn'),
    Connector('Patreon'),
    Connector('Substack'),
    Connector('Ghost'),
    Connector('Gumroad'),
    Connector('Etsy'),
    Connector('Printful'),
    Connector('QuickBooks'),
    Connector('Xero'),
    Connector('Calendly'),
    Connector('Typeform'),
    Connector('Intercom'),
    Connector('Zendesk'),
    Connector('Supabase'),
    Connector('Cloudflare'),
    Connector('Vercel'),
  ];

  static List<Connector> get live =>
      all.where((Connector c) => c.live).toList(growable: false);

  static int get count => all.length;
}
