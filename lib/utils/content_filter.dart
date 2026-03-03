/// Content filter utility to prevent offensive language
class ContentFilter {
  // Lista de palabras prohibidas (español e inglés)
  static const List<String> _bannedWords = [
    // Español (General y Latam)
    'puto', 'puta', 'mierda', 'carajo', 'coño', 'verga', 'pendejo', 'pendeja', 'idiota', 'imbécil',
    'estúpido', 'estupida', 'tonto', 'tonta', 'marica', 'maricon', 'joto', 'culiao', 'concha',
    'cabron', 'cabrona', 'ramera', 'zorra', 'perra', 'bastardo', 'malparido', 'gonorrea',
    'huevon', 'weon', 'weona', 'ctm', 'conchetumare', 'culia', 'qlo', 'qla', 'xuxa', 'chucha',
    'pinga', 'pito', 'polla', 'chocho', 'pucha', 'putamadre', 'hdp', 'hijueputa', 'hijodeputa',
    // Inglés
    'fuck', 'shit', 'bitch', 'ass', 'damn', 'crap', 'dick', 'cock', 'pussy', 'bastard', 'slut',
    'whore', 'cunt', 'faggot', 'nigger', 'nigga', 'motherfucker', 'asshole', 'douchebag', 'retard',
    // Términos ofensivos generales / Discriminación
    'nazi', 'hitler', 'racista', 'racist', 'fascista', 'pedofilo', 'violador', 'terrorista',
  ];

  /// Verifica si el texto contiene palabras prohibidas
  static bool containsBannedWords(String text) {
    final lowerText = text.toLowerCase();
    
    for (final word in _bannedWords) {
      // Busca la palabra completa (no como parte de otra palabra)
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(lowerText)) {
        return true;
      }
    }
    
    return false;
  }

  /// Filtra el texto reemplazando palabras prohibidas con asteriscos
  static String filterText(String text) {
    String filtered = text;
    
    for (final word in _bannedWords) {
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      filtered = filtered.replaceAllMapped(pattern, (match) {
        return '*' * match.group(0)!.length;
      });
    }
    
    return filtered;
  }

  /// Obtiene un mensaje de error amigable
  static String getErrorMessage() {
    return 'Tu mensaje contiene palabras no permitidas. Por favor, sé respetuoso.';
  }
}
