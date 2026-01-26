/// Content filter utility to prevent offensive language
class ContentFilter {
  // Lista de palabras prohibidas (español e inglés)
  static const List<String> _bannedWords = [
    // Español
    'puto', 'puta', 'mierda', 'carajo', 'coño', 'verga',
    'pendejo', 'idiota', 'imbécil', 'estúpido', 'tonto',
    'marica', 'maricon', 'joto', 'culiao', 'concha',
    // Inglés
    'fuck', 'shit', 'bitch', 'ass', 'damn', 'crap',
    'dick', 'cock', 'pussy', 'bastard', 'slut',
    // Términos ofensivos generales
    'nazi', 'hitler', 'racista', 'racist',
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
