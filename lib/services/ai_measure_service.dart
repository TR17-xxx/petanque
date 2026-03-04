import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:petanque_score/models/game.dart';
import 'package:petanque_score/services/secure_storage_service.dart';
import 'package:petanque_score/utils/image_utils.dart';

class AiMeasureService {
  /// Analyze a pétanque photo with Claude AI to determine scores.
  static Future<MeasureResult> analyzeWithAI(
    String photoUri,
    String team1Name,
    String team2Name,
  ) async {
    // Load API key
    final apiKey = await SecureStorageService.loadApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Clé API non configurée. Allez dans Paramètres.');
    }

    // Resize image and convert to base64
    final base64Image = await ImageUtils.resizeForAI(photoUri);

    // Build prompt (same French prompt as original)
    final prompt =
        'Tu es un arbitre expert de pétanque. Analyse cette photo prise au-dessus d\'un terrain de pétanque.\n'
        '\n'
        '1. Identifie le cochonnet (petite boule en bois, souvent rouge ou colorée)\n'
        '2. Identifie chaque boule métallique et détermine à quelle équipe elle appartient (les boules d\'une même équipe ont généralement des stries/rayures similaires)\n'
        '3. Estime visuellement quelle boule est la plus proche du cochonnet\n'
        '4. Compte combien de boules de l\'équipe la plus proche sont PLUS PROCHES du cochonnet que la meilleure boule de l\'autre équipe — c\'est le nombre de points marqués\n'
        '\n'
        'Si tu ne peux pas distinguer clairement les équipes, base-toi sur les différences visuelles (brillance, taille, stries, position).\n'
        '\n'
        'Réponds UNIQUEMENT avec ce JSON, sans aucun autre texte :\n'
        '{"closest_team": 1, "points": 2, "total_boules_team1": 3, "total_boules_team2": 3, "analysis": "Description courte de ce que tu vois et de ton raisonnement", "confidence": "high"}\n'
        '\n'
        'Le champ closest_team vaut 1 ($team1Name) ou 2 ($team2Name). Le champ confidence vaut "high", "medium" ou "low".';

    // Make API request
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': base64Image,
                },
              },
              {
                'type': 'text',
                'text': prompt,
              },
            ],
          },
        ],
      }),
    );

    // Handle HTTP errors
    if (response.statusCode == 401) {
      throw Exception('Clé API invalide. Vérifiez-la dans les Paramètres.');
    }
    if (response.statusCode == 429) {
      throw Exception('Trop de requêtes. Réessayez dans quelques secondes.');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur du service d\'analyse (${response.statusCode}). Réessayez plus tard.',
      );
    }

    // Parse API response
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final contentList = data['content'] as List?;
    if (contentList == null || contentList.isEmpty) {
      throw Exception('Réponse vide de l\'API. Réessayez.');
    }

    final content = contentList[0]['text'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('Réponse vide de l\'API. Réessayez.');
    }

    // Parse JSON (handle ```json code fences)
    String jsonStr = content.trim();
    if (jsonStr.startsWith('```')) {
      // Remove opening ```json or ``` and closing ```
      jsonStr = jsonStr.replaceFirst(RegExp(r'^```json?\n?'), '');
      jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
        'Réponse IA invalide. Essayez le mode manuel.',
      );
    }

    // Validate closest_team
    final closestTeam = parsed['closest_team'];
    if (closestTeam != 1 && closestTeam != 2) {
      throw Exception(
        'Réponse IA incorrecte (équipe invalide). Essayez le mode manuel.',
      );
    }

    // Validate and clamp points
    int points = (parsed['points'] as num?)?.toInt() ?? 1;
    if (points < 1) points = 1;
    if (points > 6) points = 6;

    // Extract analysis and confidence
    final analysis = parsed['analysis'] as String?;
    final confidence = parsed['confidence'] as String? ?? 'medium';

    return MeasureResult(
      mode: 'ai',
      closestTeamId: closestTeam as int,
      pointsScored: points,
      aiAnalysis: analysis,
      photoUri: photoUri,
      confidence: confidence,
    );
  }
}
