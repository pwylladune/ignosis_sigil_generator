import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/compendium.dart';
import '../theme/sigil_skins.dart';
import '../widgets/ignosis_mark.dart';

/// The Compendium: chaos magic and the traditions it adapted, in its sources'
/// own words. Nine parts of quotations, then the glossary, study guide,
/// bibliography and the authors' websites.
class CompendiumScreen extends StatelessWidget {
  const CompendiumScreen({super.key, required this.theme, this.compendium});

  final SigilSkinTheme theme;

  /// The loaded compendium; when null it is read from the bundled asset.
  final Compendium? compendium;

  @override
  Widget build(BuildContext context) {
    return _CompendiumPage(
      theme: theme,
      title: 'THE COMPENDIUM',
      mark: true,
      body: compendium != null
          ? _home(context, compendium!)
          : FutureBuilder<Compendium>(
              future: Compendium.load(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('The Compendium could not be opened.', style: TextStyle(color: theme.inkTertiary)),
                  );
                }
                if (!snap.hasData) return Center(child: CircularProgressIndicator(color: theme.inkTertiary));
                return _home(context, snap.data!);
              },
            ),
    );
  }

  Widget _home(BuildContext context, Compendium c) {
    void open(String title, Widget body) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _CompendiumPage(theme: theme, title: title, body: body)),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Text(
          '${c.quoteCount} quotations from ${c.workCount} works',
          style: TextStyle(fontSize: 12, letterSpacing: 0.5, color: theme.inkTertiary),
        ),
        _heading(theme, 'PARTS'),
        for (final p in c.parts)
          _tile(
            theme,
            leading: p.numeral,
            title: p.title,
            subtitle: '${p.quoteCount} quotations',
            onTap: () => open('${p.numeral}. ${p.title.toUpperCase()}', _PartView(theme: theme, part: p)),
          ),
        _heading(theme, 'REFERENCE'),
        _tile(theme,
            title: 'Glossary',
            subtitle: '${c.glossary.length} terms',
            onTap: () => open('GLOSSARY', _GlossaryView(theme: theme, terms: c.glossary))),
        _tile(theme,
            title: 'Study guide',
            subtitle: 'The works, part by part',
            onTap: () => open('STUDY GUIDE', _StudyGuideView(theme: theme, parts: c.studyGuide))),
        _tile(theme,
            title: 'Bibliography',
            subtitle: '${c.bibliography.length} entries',
            onTap: () => open('BIBLIOGRAPHY', _BibliographyView(theme: theme, entries: c.bibliography))),
        _tile(theme,
            title: 'Authors and websites',
            subtitle: '${c.authors.length} authors',
            onTap: () => open('AUTHORS AND WEBSITES', _AuthorsView(theme: theme, authors: c.authors))),
      ],
    );
  }
}

/// The shared page frame: a hairline app bar on the skin's background.
class _CompendiumPage extends StatelessWidget {
  const _CompendiumPage({required this.theme, required this.title, required this.body, this.mark = false});

  final SigilSkinTheme theme;
  final String title;
  final Widget body;
  final bool mark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        foregroundColor: theme.inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: theme.hairline)),
        title: Row(
          children: [
            if (mark) ...[IgnosisMark(skin: theme, size: 28), const SizedBox(width: 10)],
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: theme.inkPrimary),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _PartView extends StatelessWidget {
  const _PartView({required this.theme, required this.part});

  final SigilSkinTheme theme;
  final CompendiumPart part;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        for (final s in part.sections) ...[
          _heading(theme, s.title.toUpperCase()),
          for (final q in s.quotes) QuotationCard(theme: theme, quote: q),
        ],
      ],
    );
  }
}

class _GlossaryView extends StatelessWidget {
  const _GlossaryView({required this.theme, required this.terms});

  final SigilSkinTheme theme;
  final List<GlossaryTerm> terms;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        for (final t in terms)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: _card(theme),
            // Its own transparent Material, so the tile's ripple shows above the card.
            child: Material(
              type: MaterialType.transparency,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.fromLTRB(18, 2, 12, 2),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  expandedAlignment: Alignment.centerLeft,
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  minTileHeight: 44,
                  iconColor: theme.inkSecondary,
                  collapsedIconColor: theme.inkTertiary,
                  title: Text(
                    t.term,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.inkPrimary),
                  ),
                  children: [for (final q in t.quotes) QuotationCard(theme: theme, quote: q, flat: true)],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StudyGuideView extends StatelessWidget {
  const _StudyGuideView({required this.theme, required this.parts});

  final SigilSkinTheme theme;
  final List<StudyGuidePart> parts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        for (final g in parts) ...[
          _heading(theme, '${g.numeral}. ${g.title.toUpperCase()}'),
          for (final w in g.works)
            _entry(
              theme,
              primary: w.work,
              secondary: [w.author, if (w.year != null) w.year!].join(' · '),
              url: w.url,
              publicDomain: w.publicDomain,
            ),
        ],
      ],
    );
  }
}

class _BibliographyView extends StatelessWidget {
  const _BibliographyView({required this.theme, required this.entries});

  final SigilSkinTheme theme;
  final List<BibliographyEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        for (final b in entries) _entry(theme, primary: b.citation, url: b.url, publicDomain: b.publicDomain, plain: true),
      ],
    );
  }
}

class _AuthorsView extends StatelessWidget {
  const _AuthorsView({required this.theme, required this.authors});

  final SigilSkinTheme theme;
  final List<AuthorSite> authors;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [for (final a in authors) _entry(theme, primary: a.name, url: a.website)],
    );
  }
}

/// One quotation: the words, then who said them, where, and links to the
/// page it was checked against and to read more.
class QuotationCard extends StatelessWidget {
  const QuotationCard({super.key, required this.theme, required this.quote, this.flat = false});

  final SigilSkinTheme theme;
  final Quotation quote;

  /// Inside another card (the glossary): no border of its own.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final cite = [
      q.author,
      q.work,
      if (q.year != null && q.year!.isNotEmpty) q.year!,
      if (q.translator != null && q.translator!.isNotEmpty) 'tr. ${q.translator}',
      if (q.locator != null && q.locator!.isNotEmpty) q.locator!,
    ].where((s) => s.isNotEmpty).join(', ');
    return Container(
      margin: EdgeInsets.only(bottom: flat ? 4 : 12),
      padding: EdgeInsets.fromLTRB(flat ? 6 : 18, flat ? 4 : 16, flat ? 6 : 18, flat ? 4 : 10),
      decoration: flat ? null : _card(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.seal, width: 2))),
            child: SelectableText(
              '“${q.text.trim()}”',
              style: TextStyle(fontSize: 15, height: 1.6, color: theme.inkPrimary),
            ),
          ),
          const SizedBox(height: 10),
          Text('— $cite', style: TextStyle(fontSize: 12, height: 1.4, color: theme.inkTertiary)),
          Wrap(
            spacing: 20,
            children: [
              if (q.sourceUrl != null) _link(theme, 'Source', q.sourceUrl!),
              if (q.learnMoreUrl != null && q.learnMoreUrl != q.sourceUrl)
                _link(theme, q.publicDomain ? 'Read the text' : 'Learn more', q.learnMoreUrl!),
            ],
          ),
        ],
      ),
    );
  }
}

BoxDecoration _card(SigilSkinTheme theme) => BoxDecoration(
      color: theme.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: theme.hairline),
    );

Widget _heading(SigilSkinTheme theme, String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: theme.accent),
      ),
    );

Widget _tile(SigilSkinTheme theme,
    {String? leading, required String title, required String subtitle, required VoidCallback onTap}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: _card(theme),
    child: Material(
      type: MaterialType.transparency,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.fromLTRB(18, 4, 12, 4),
        leading: leading == null
            ? null
            : SizedBox(
                width: 36,
                child: Text(
                  leading,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.seal),
                ),
              ),
        minLeadingWidth: 36,
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.inkPrimary)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.inkTertiary)),
        trailing: Icon(Icons.chevron_right, size: 20, color: theme.inkTertiary),
        onTap: onTap,
      ),
    ),
  );
}

/// A work, citation or author, with its link.
Widget _entry(SigilSkinTheme theme,
    {required String primary, String? secondary, String? url, bool publicDomain = false, bool plain = false}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
    decoration: _card(theme),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: plain ? FontWeight.normal : FontWeight.bold,
            fontStyle: plain ? FontStyle.normal : FontStyle.italic,
            color: theme.inkPrimary,
          ),
        ),
        if (secondary != null && secondary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(secondary, style: TextStyle(fontSize: 12, color: theme.inkTertiary)),
          ),
        if (url != null) _link(theme, publicDomain ? 'Read the text' : _host(url), url) else const SizedBox(height: 8),
      ],
    ),
  );
}

Widget _link(SigilSkinTheme theme, String label, String url) => TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: theme.accent,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        minimumSize: const Size(44, 36),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
      icon: const Icon(Icons.north_east, size: 13),
      label: Text(label),
      onPressed: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
    );

String _host(String url) => Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
