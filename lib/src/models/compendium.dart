import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// The Compendium: the history of chaos magic and the traditions it adapted,
/// told only in short, verified quotations from its sources. Exported from the
/// literature review in the vault by `tool/compendium/export.py`.
class Compendium {
  Compendium({
    required this.parts,
    required this.glossary,
    required this.studyGuide,
    required this.bibliography,
    required this.authors,
  });

  final List<CompendiumPart> parts;
  final List<GlossaryTerm> glossary;
  final List<StudyGuidePart> studyGuide;
  final List<BibliographyEntry> bibliography;
  final List<AuthorSite> authors;

  static const asset = 'assets/compendium/compendium.json';
  static Future<Compendium>? _loaded;

  /// Loads the bundled compendium once.
  static Future<Compendium> load() => _loaded ??= rootBundle.loadString(asset).then(parse);

  static Compendium parse(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final parts = [for (final p in j['parts'] as List) CompendiumPart.fromJson(p as Map<String, dynamic>)];
    return Compendium(
      parts: parts,
      glossary: [
        for (final t in j['glossary'] as List)
          GlossaryTerm(
            (t as Map)['term'] as String,
            [
              for (final r in t['refs'] as List)
                parts[(r as List)[0] as int].sections[r[1] as int].quotes[r[2] as int],
            ],
          ),
      ],
      studyGuide: [
        for (final g in j['study_guide'] as List)
          StudyGuidePart(
            (g as Map)['numeral'] as String,
            g['title'] as String,
            [for (final w in g['works'] as List) StudyGuideWork.fromJson(w as Map<String, dynamic>)],
          ),
      ],
      bibliography: [
        for (final b in j['bibliography'] as List)
          BibliographyEntry((b as Map)['citation'] as String, b['url'] as String?, b['public_domain'] == true),
      ],
      authors: [for (final a in j['authors'] as List) AuthorSite((a as Map)['name'] as String, a['website'] as String)],
    );
  }

  int get quoteCount => parts.fold(0, (n, p) => n + p.quoteCount);

  /// The distinct works quoted.
  int get workCount => {
        for (final p in parts)
          for (final s in p.sections)
            for (final q in s.quotes) (q.author, q.work),
      }.length;
}

class CompendiumPart {
  CompendiumPart(this.numeral, this.title, this.sections);

  factory CompendiumPart.fromJson(Map<String, dynamic> j) => CompendiumPart(
        j['numeral'] as String,
        j['title'] as String,
        [
          for (final s in j['sections'] as List)
            CompendiumSection(
              (s as Map)['title'] as String,
              [for (final q in s['quotes'] as List) Quotation.fromJson(q as Map<String, dynamic>)],
            ),
        ],
      );

  final String numeral;
  final String title;
  final List<CompendiumSection> sections;

  int get quoteCount => sections.fold(0, (n, s) => n + s.quotes.length);
}

class CompendiumSection {
  CompendiumSection(this.title, this.quotes);

  final String title;
  final List<Quotation> quotes;
}

/// One verified quotation and where it comes from.
class Quotation {
  Quotation({
    required this.text,
    required this.author,
    required this.work,
    this.year,
    this.translator,
    this.locator,
    this.publicDomain = false,
    this.sourceUrl,
    this.learnMoreUrl,
  });

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        text: j['text'] as String,
        author: j['author'] as String? ?? '',
        work: j['work'] as String? ?? '',
        year: j['year']?.toString(),
        translator: j['translator'] as String?,
        locator: j['locator'] as String?,
        publicDomain: j['public_domain'] == true,
        sourceUrl: j['source_url'] as String?,
        learnMoreUrl: j['learn_more_url'] as String?,
      );

  final String text;
  final String author;
  final String work;
  final String? year;
  final String? translator;
  final String? locator;
  final bool publicDomain;

  /// Where the wording was verified.
  final String? sourceUrl;

  /// A free text, the author's website, or the publisher.
  final String? learnMoreUrl;
}

class GlossaryTerm {
  GlossaryTerm(this.term, this.quotes);

  final String term;
  final List<Quotation> quotes;
}

class StudyGuidePart {
  StudyGuidePart(this.numeral, this.title, this.works);

  final String numeral;
  final String title;
  final List<StudyGuideWork> works;
}

class StudyGuideWork {
  StudyGuideWork(this.author, this.work, this.year, this.url, this.publicDomain);

  factory StudyGuideWork.fromJson(Map<String, dynamic> j) => StudyGuideWork(
        j['author'] as String? ?? '',
        j['work'] as String? ?? '',
        j['year']?.toString(),
        j['url'] as String?,
        j['public_domain'] == true,
      );

  final String author;
  final String work;
  final String? year;
  final String? url;
  final bool publicDomain;
}

class BibliographyEntry {
  BibliographyEntry(this.citation, this.url, this.publicDomain);

  final String citation;
  final String? url;
  final bool publicDomain;
}

class AuthorSite {
  AuthorSite(this.name, this.website);

  final String name;
  final String website;
}
