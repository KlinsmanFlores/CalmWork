import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroqService {
  final String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  String? get _apiKey {
    return dotenv.env['GROQ_API_KEY'];
  }

  final String _systemPrompt = '''
Eres un asistente de apoyo emocional confidencial para los empleados de la empresa CalmWORK.
Tu objetivo es escuchar, brindar empatía y contención emocional ante problemas laborales como sobrecarga, acoso, discriminación, estrés o problemas personales.
NO puedes resolver problemas administrativos, legales ni tomar acciones directas en la empresa. Si el usuario menciona un problema que requiere intervención formal (ej. acoso grave, problemas de pago), sugiérele amablemente que utilice los canales formales de Recursos Humanos y ofrécele apoyo emocional para afrontar la situación.
Responde de manera concisa (no más de 2-3 párrafos), empática, cálida y profesional. Mantén un tono de comprensión absoluta. Este es un espacio seguro y 100% anónimo.
''';

  Future<String> sendMessage(List<Map<String, String>> conversationHistory) async {
    final key = _apiKey;
    if (key != null && key.isNotEmpty && !key.startsWith('gsk_placeholder')) {
      final messages = [
        {'role': 'system', 'content': _systemPrompt},
        ...conversationHistory,
      ];

      try {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'llama-3.1-8b-instant',
            'messages': messages,
            'temperature': 0.7,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'];
        }
      } catch (e) {
        // Fallback a respuesta local asistida
      }
    }

    // --- RESPUESTA LOCAL INTELIGENTE DE CONTENCIÓN EMOCIONAL ---
    final lastMessage = conversationHistory.isNotEmpty 
        ? conversationHistory.last['content']?.toLowerCase() ?? '' 
        : '';

    return _generateLocalEmpatheticResponse(lastMessage);
  }

  String _generateLocalEmpatheticResponse(String text) {
    if (text.contains('estrés') || text.contains('estres') || text.contains('cansad') || text.contains('agotad') || text.contains('presion') || text.contains('presión')) {
      return 'Comprendo perfectamente lo que estás sintiendo. Sentir una carga pesada o agotamiento en el trabajo es una señal válida de que necesitas hacer una pausa consciente.\n\nRecuerda que tu bienestar personal está primero. ¿Hay alguna tarea puntual que podamos desglosar juntos, o sientes que es una sobrecarga general en tus jornadas?';
    } else if (text.contains('jefe') || text.contains('líder') || text.contains('compañer') || text.contains('acoso') || text.contains('injust')) {
      return 'Lamento mucho que estés experimentando esta situación tan incómoda en tu entorno de trabajo. Las relaciones laborales difíciles impactan profundamente en nuestro estado de ánimo.\n\nEste es un espacio totalmente seguro y anónimo para desahogarte. Si consideras que se están vulnerando tus derechos, recuerda que también tienes a disposición el canal de denuncias anónimas en los módulos de reporte de la app. ¿Te gustaría contarme un poco más de lo sucedido?';
    } else if (text.contains('gracias') || text.contains('bueno') || text.contains('ok') || text.contains('entendido')) {
      return 'Siempre estoy aquí para ti cuando necesites conversar, desahogarte o encontrar calma durante tu día de trabajo. No dudes en regresar cuando lo sientas necesario.';
    } else {
      return 'Te escucho con total atención y respeto. Es completamente comprensible que te sientas así frente a lo que estás viviendo en tu rutina laboral.\n\nTomarte este momento para expresar lo que sientes ya es un gran paso. Cuéntame con confianza, ¿desde hace cuánto tiempo te vienes sintiendo de esta manera?';
    }
  }

  Future<Map<String, dynamic>> analyzeConversation(List<Map<String, String>> conversationHistory) async {
    final key = _apiKey;
    if (key != null && key.isNotEmpty && !key.startsWith('gsk_placeholder')) {
      final transcript = conversationHistory.map((m) => '${m['role']}: ${m['content']}').join('\n');
      
      final prompt = '''
Analiza la siguiente transcripción de una conversación anónima de apoyo emocional de un empleado.
Determina:
1. El "tema principal" de la conversación en 2-4 palabras.
2. El "nivel de urgencia" (solo responde "low", "medium" o "high" en inglés).
3. Una "lista de recomendaciones" (máximo 3 acciones accionables).
4. Un "resumen" (1 o 2 párrafos breves resumiendo la situación del empleado).

Transcripción:
$transcript

Responde ÚNICAMENTE en formato JSON estricto con las claves "tema", "urgencia", "recomendaciones" (array) y "resumen" (string).
''';

      try {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'llama-3.1-8b-instant',
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'temperature': 0.1,
            'response_format': {'type': 'json_object'},
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content = data['choices'][0]['message']['content'];
          final Map<String, dynamic> result = jsonDecode(content);
          return {
            'tema': result['tema']?.toString() ?? 'Bienestar Laboral',
            'urgencia': result['urgencia']?.toString() ?? 'low',
            'recomendaciones': result['recomendaciones'] ?? [],
            'resumen': result['resumen']?.toString() ?? 'Conversación de apoyo emocional completada.',
          };
        }
      } catch (e) {
        // Fallback a análisis local
      }
    }

    // Análisis local de respaldo
    final fullText = conversationHistory.map((m) => m['content'] ?? '').join(' ').toLowerCase();
    String tema = 'Bienestar General';
    String urgencia = 'low';
    List<String> recs = ['Tomar descansos activos breves', 'Establecer prioridades en las tareas'];

    if (fullText.contains('acoso') || fullText.contains('agres') || fullText.contains('discrimin')) {
      tema = 'Convivencia y Trato';
      urgencia = 'high';
      recs = ['Utilizar el módulo de reporte confidencial', 'Buscar apoyo en el comité de convivencia', 'Documentar incidentes'];
    } else if (fullText.contains('estrés') || fullText.contains('sobrecarga') || fullText.contains('cansan')) {
      tema = 'Sobrecarga y Estrés';
      urgencia = 'medium';
      recs = ['Revisar límites de horarios laborales', 'Comunicar la carga de trabajo al líder', 'Practicar respiración consciente'];
    }

    return {
      'tema': tema,
      'urgencia': urgencia,
      'recomendaciones': recs,
      'resumen': 'El colaborador mantuvo una sesión de contención emocional anónima sobre $tema.',
    };
  }
}
