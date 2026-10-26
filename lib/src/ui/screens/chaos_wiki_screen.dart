import 'package:flutter/material.dart';
import '../../models/chaos_magic_wiki_articles.dart';
import '../../models/chaos_magic_wiki_data.dart';
import '../theme/sigil_skins.dart';
import '../widgets/ignosis_mark.dart';

/// Screen presenting the comprehensive Chaos Magic Wiki & Philosophical Interview Framework
class ChaosWikiScreen extends StatefulWidget {
  final SigilSkinTheme theme;

  const ChaosWikiScreen({super.key, required this.theme});

  @override
  State<ChaosWikiScreen> createState() => _ChaosWikiScreenState();
}

class _ChaosWikiScreenState extends State<ChaosWikiScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < ChaosMagicWikiData.questions.length; i++) {
      _controllers[i.toString()] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    // Group questions by category
    final categories = <String, List<WikiQuestion>>{};
    for (final q in ChaosMagicWikiData.questions) {
      categories.putIfAbsent(q.category, () => []).add(q);
    }

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CHAOS MAGIC ARCHIVES',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: theme.inkPrimary,
              ),
            ),
            Text(
              'Personal Philosophy & Rites Interview Repository',
              style: TextStyle(fontSize: 12, color: theme.inkTertiary),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.record_voice_over, size: 14, color: theme.accent),
                const SizedBox(width: 6),
                Text(
                  'INTERVIEW MODE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IgnosisMark(skin: theme, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'THE CODEX & THE INTERVIEW',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: theme.inkPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The codex comes first: how each of the seven systems works, where it comes from, and why the '
                    'studio was built the way it was. '
                    'This section establishes the definitive body of knowledge for IGNOSIS. '
                    'After it comes the structured questionnaire, designed to distill your personal understanding '
                    'of esoterica, Austin Osman Spare\'s method, gnosis, and the symbolic act of combustion. '
                    'As we develop this through long-form discussion, answers recorded here become the permanent app wiki.',
                    style: TextStyle(fontSize: 14, height: 1.5, color: theme.inkSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // The codex: the systems and the studio's history.
            ..._buildArticleSections(theme),

            // Render Questions by Category
            ...categories.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: theme.accent,
                      ),
                    ),
                  ),
                  ...entry.value.map((q) => _buildQuestionCard(q, theme)),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  /// The codex sections (the systems, then the studio's history).
  List<Widget> _buildArticleSections(SigilSkinTheme theme) {
    final sections = <String, List<WikiArticle>>{};
    for (final a in ChaosMagicWikiArticles.articles) {
      sections.putIfAbsent(a.category, () => []).add(a);
    }
    return [
      for (final entry in sections.entries) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            entry.key.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: theme.accent),
          ),
        ),
        for (final a in entry.value) _buildArticleCard(a, theme),
        const SizedBox(height: 16),
      ],
    ];
  }

  /// An article, collapsed to its title and summary until opened.
  Widget _buildArticleCard(WikiArticle a, SigilSkinTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.hairline),
      ),
      child: Theme(
        // The card is the boundary: no extra divider lines when expanded.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          minTileHeight: 44,
          iconColor: theme.inkSecondary,
          collapsedIconColor: theme.inkTertiary,
          leading: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: theme.seal),
          ),
          title: Text(
            a.title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: theme.inkPrimary),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(a.summary, style: TextStyle(fontSize: 12, height: 1.4, color: theme.inkTertiary)),
          ),
          children: [
            for (final p in a.body)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(p, style: TextStyle(fontSize: 14, height: 1.6, color: theme.inkSecondary)),
              ),
            if (a.sources.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in a.sources)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          s,
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, height: 1.4, color: theme.inkTertiary),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(WikiQuestion q, SigilSkinTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2, right: 10),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accent,
                ),
              ),
              Expanded(
                child: Text(
                  q.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: theme.inkPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            q.prompt,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: theme.inkSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: theme.inkTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prompts for discussion: ${q.hint}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: theme.inkTertiary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
