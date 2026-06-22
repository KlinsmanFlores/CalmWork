import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroqService {
  final String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  String get _apiKey {
    final key = dotenv.env['GROQ_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GROQ_API_KEY no está configurada en .env');
    }
    return key;
  }

  final String _systemPrompt = '''
Eres un asistente de apoyo emocional confidencial para los empleados de la empresa CalmWORK.
Tu objetivo es escuchar, brindar empatía y contención emocional ante problemas laborales como sobrecarga, acoso, discriminación, estrés o problemas personales.
NO puedes resolver problemas administrativos, legales ni tomar acciones directas en la empresa. Si el usuario menciona un problema que requiere intervención formal (ej. acoso grave, problemas de pago), sugiérele amablemente que utilice los canales formales de Recursos Humanos y ofrécele apoyo emocional para afrontar la situación.
Responde de manera concisa (no más de 2-3 párrafos), empática, cálida y profesional. Mantén un tono de comprensión absoluta. Este es un espacio seguro y 100% anónimo.
''';

  Future<String> sendMessage(List<Map<String, String>> conversationHistory) async {
    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ...conversationHistory,
    ];

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': messages,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Error en Groq API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error al comunicar con Groq: $e');
      return 'Error para debug: $e';
    }
  }

  Future<Map<String, dynamic>> analyzeConversation(List<Map<String, String>> conversationHistory) async {
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
Ejemplo: {"tema": "Acoso", "urgencia": "high", "recomendaciones": ["Hablar con supervisor"], "resumen": "El empleado relata que..."}
''';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        final Map<String, dynamic> result = jsonDecode(content);
        return {
          'tema': result['tema']?.toString() ?? 'Desconocido',
          'urgencia': result['urgencia']?.toString() ?? 'low',
          'recomendaciones': result['recomendaciones'] ?? [],
          'resumen': result['resumen']?.toString() ?? 'Sin resumen',
        };
      }
    } catch (e) {
      print('Error al analizar la conversación: $e');
    }
    
    return {'tema': 'Error de análisis', 'urgencia': 'low', 'recomendaciones': [], 'resumen': ''};
  }
}
