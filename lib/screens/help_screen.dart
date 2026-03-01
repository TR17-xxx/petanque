import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:petanque_score/providers/theme_provider.dart';
import 'package:petanque_score/utils/colors.dart';

/// Data model for a single help item within a section.
class _HelpItem {
  final String subtitle;
  final String text;

  const _HelpItem({required this.subtitle, required this.text});
}

/// Data model for a help section (accordion).
class _HelpSection {
  final IconData icon;
  final String title;
  final List<_HelpItem> items;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.items,
  });
}

/// All help content in French.
const _helpSections = <_HelpSection>[
  _HelpSection(
    icon: LucideIcons.bookOpen,
    title: 'Règles de la pétanque',
    items: [
      _HelpItem(
        subtitle: 'But du jeu',
        text:
            'Le but est de placer ses boules le plus près possible du cochonnet '
            '(petit). L\'équipe ayant la boule la plus proche du cochonnet marque '
            'des points à chaque mène.',
      ),
      _HelpItem(
        subtitle: 'Déroulement',
        text:
            'L\'équipe qui a lancé le cochonnet joue sa première boule. '
            'L\'autre équipe joue ensuite. L\'équipe qui n\'a pas le point '
            'continue de jouer jusqu\'à reprendre le point ou épuiser ses boules.',
      ),
      _HelpItem(
        subtitle: 'Comptage des points',
        text:
            'À la fin d\'une mène, l\'équipe qui a la boule la plus proche du '
            'cochonnet marque autant de points qu\'elle a de boules placées '
            'plus près que la meilleure boule adverse.',
      ),
      _HelpItem(
        subtitle: 'Fin de partie',
        text:
            'La partie se joue en 13 points. La première équipe à atteindre '
            '13 points remporte la partie.',
      ),
      _HelpItem(
        subtitle: 'La Fanny',
        text:
            'Lorsqu\'une équipe perd 13 à 0, on dit qu\'elle "fait fanny". '
            'C\'est une défaite particulièrement marquante dans la tradition '
            'de la pétanque !',
      ),
    ],
  ),
  _HelpSection(
    icon: LucideIcons.target,
    title: 'Compteur de points',
    items: [
      _HelpItem(
        subtitle: 'Nouvelle partie',
        text:
            'Depuis l\'écran d\'accueil, appuyez sur "Partie" pour créer une '
            'nouvelle partie. Personnalisez les noms et couleurs des équipes.',
      ),
      _HelpItem(
        subtitle: 'Saisie des mènes',
        text:
            'Après chaque mène, sélectionnez l\'équipe qui a marqué, puis le '
            'nombre de points. Validez pour enregistrer la mène.',
      ),
      _HelpItem(
        subtitle: 'Annulation',
        text:
            'Vous pouvez annuler la dernière mène en cas d\'erreur. '
            'Appuyez sur "Annuler la dernière mène" sous le formulaire de saisie.',
      ),
      _HelpItem(
        subtitle: 'Historique',
        text:
            'L\'historique des mènes est accessible depuis l\'écran de jeu '
            '(icône liste). Les parties terminées sont visibles depuis l\'accueil.',
      ),
    ],
  ),
  _HelpSection(
    icon: LucideIcons.camera,
    title: 'Mesure des distances (IA)',
    items: [
      _HelpItem(
        subtitle: 'Configuration',
        text:
            'Pour utiliser la mesure par IA, vous devez d\'abord configurer '
            'votre clé API Anthropic dans les paramètres de l\'application.',
      ),
      _HelpItem(
        subtitle: 'Prise de photo',
        text:
            'Prenez une photo du jeu en vue de dessus. Essayez de cadrer '
            'toutes les boules et le cochonnet. Une vue bien centrée et '
            'perpendiculaire donne les meilleurs résultats.',
      ),
      _HelpItem(
        subtitle: 'Placement des marqueurs',
        text:
            'Placez les marqueurs sur la photo : le cochonnet (jaune), '
            'les boules de l\'équipe 1 et de l\'équipe 2. Utilisez le '
            'pinch pour zoomer et ajuster la précision.',
      ),
      _HelpItem(
        subtitle: 'Analyse IA',
        text:
            'L\'IA analyse la photo et les positions des marqueurs pour '
            'déterminer quelle équipe est la plus proche et combien de '
            'points elle marque.',
      ),
      _HelpItem(
        subtitle: 'Précision',
        text:
            'La mesure par IA est une aide indicative. En cas de doute, '
            'utilisez toujours une mesure physique (mètre, ficelle) pour '
            'les cas litigieux.',
      ),
    ],
  ),
  _HelpSection(
    icon: LucideIcons.trophy,
    title: 'Tournois',
    items: [
      _HelpItem(
        subtitle: 'Création',
        text:
            'Créez un tournoi en définissant le nom, le type de jeu '
            '(triplette, doublette, tête-à-tête), et en ajoutant les '
            'équipes participantes. Choisissez le nombre d\'équipes par '
            'poule et le nombre de poules, les équipes sont créées '
            'automatiquement.',
      ),
      _HelpItem(
        subtitle: 'Phase de poules (round-robin)',
        text:
            'Chaque équipe affronte toutes les autres équipes de sa poule. '
            'Les matchs se jouent en 13 points. À la fin de la phase de '
            'poules, les 2 meilleures équipes de chaque poule sont '
            'qualifiées pour la phase éliminatoire.',
      ),
      _HelpItem(
        subtitle: 'Phase éliminatoire',
        text:
            'Les équipes qualifiées s\'affrontent en matchs à élimination '
            'directe. Le 1er d\'une poule affronte le 2ème d\'une autre '
            'poule (croisement). Les matchs se jouent en quarts de finale, '
            'demi-finales puis finale. Un match pour la 3ème place peut '
            'être activé à la création.',
      ),
      _HelpItem(
        subtitle: 'Classement des poules',
        text:
            'Le classement prend en compte dans l\'ordre : le nombre de '
            'victoires, la différence de points (marqués - encaissés), '
            'puis le total de points marqués en cas d\'égalité.',
      ),
      _HelpItem(
        subtitle: 'Tournoi actif',
        text:
            'Un seul tournoi peut être actif à la fois. Il est accessible '
            'directement depuis l\'écran d\'accueil. Appui long sur la '
            'bannière pour le supprimer.',
      ),
    ],
  ),
  _HelpSection(
    icon: LucideIcons.award,
    title: 'Championnat (FFPJP)',
    items: [
      _HelpItem(
        subtitle: 'Principe',
        text:
            'Le championnat utilise le format éliminatoire de la FFPJP '
            '(Fédération Française de Pétanque et Jeu Provençal). '
            'Contrairement au tournoi classique où toutes les équipes '
            'd\'une poule se rencontrent, le championnat fonctionne avec '
            'un système de matchs gagnants/perdants à l\'intérieur de '
            'chaque poule.',
      ),
      _HelpItem(
        subtitle: 'Tour 1 — Matchs initiaux',
        text:
            'Les équipes de chaque poule sont appairées pour les matchs '
            'initiaux. Dans une poule de 4 : Équipe 1 vs Équipe 2 et '
            'Équipe 3 vs Équipe 4. Dans une poule de 3 : Équipe 1 vs '
            'Équipe 2 et l\'Équipe 3 est exemptée (bye automatique, '
            'elle passe directement au tour suivant côté gagnants).',
      ),
      _HelpItem(
        subtitle: 'Tour 2 — Gagnants et Perdants',
        text:
            'Les gagnants du Tour 1 s\'affrontent entre eux (match des '
            'Gagnants). Les perdants du Tour 1 s\'affrontent entre eux '
            '(match des Perdants). Le perdant du match des Perdants est '
            'éliminé de la poule (classé dernier).',
      ),
      _HelpItem(
        subtitle: 'Tour 3 — Barrage',
        text:
            'Le perdant du match des Gagnants affronte le gagnant du '
            'match des Perdants dans un match de barrage. Le gagnant du '
            'barrage se qualifie (2ème de la poule). Le perdant du '
            'barrage est éliminé (3ème de la poule).',
      ),
      _HelpItem(
        subtitle: 'Qualification',
        text:
            '2 équipes se qualifient par poule : le gagnant du match des '
            'Gagnants (1er) et le gagnant du Barrage (2ème). Ces équipes '
            'passent ensuite en phase éliminatoire (quarts, demis, '
            'finale) comme dans un tournoi classique.',
      ),
      _HelpItem(
        subtitle: 'Score cible',
        text:
            'Le championnat permet de définir un score cible différent '
            'pour les poules et pour le bracket. Par défaut : 11 points '
            'en poules et 13 points en phase éliminatoire. Ces valeurs '
            'sont ajustables à la création.',
      ),
    ],
  ),
];

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  // Track which sections are expanded
  final Set<int> _expandedSections = {};

  void _toggleSection(int index) {
    setState(() {
      if (_expandedSections.contains(index)) {
        _expandedSections.remove(index);
      } else {
        _expandedSections.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final themeColor600 = theme.colors.shade600;

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      LucideIcons.arrowLeft,
                      size: 22,
                      color: slate800,
                    ),
                    tooltip: 'Retour',
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Aide',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: slate800,
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _helpSections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final section = _helpSections[index];
                  final isExpanded = _expandedSections.contains(index);

                  return _HelpSectionCard(
                    section: section,
                    isExpanded: isExpanded,
                    themeColor600: themeColor600,
                    onToggle: () => _toggleSection(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single expandable help section card.
class _HelpSectionCard extends StatelessWidget {
  const _HelpSectionCard({
    required this.section,
    required this.isExpanded,
    required this.themeColor600,
    required this.onToggle,
  });

  final _HelpSection section;
  final bool isExpanded;
  final Color themeColor600;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header (tappable) ──
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(section.icon, size: 22, color: themeColor600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: slate800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: slate400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable content ──
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              heightFactor: isExpanded ? 1.0 : 0.0,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        const Divider(height: 1, color: slate100),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: section.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: slate800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.text,
                      style: const TextStyle(
                        fontSize: 13,
                        color: slate500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
