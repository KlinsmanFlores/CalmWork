import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db_service.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  /// Retorna el cliente de Supabase si está inicializado
  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Verifica si Supabase está listo para ser utilizado
  bool get isReady => client != null;

  // --- AUTENTICACIÓN Y SESIÓN ---

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    
    if (isReady) {
      try {
        final res = await client!
            .from('employees')
            .select()
            .ilike('email', cleanEmail)
            .eq('password', password)
            .maybeSingle();

        if (res != null) {
          final user = Map<String, dynamic>.from(res);
          await _saveCurrentSession(user);
          return user;
        } else {
          throw Exception('Credenciales incorrectas o usuario no registrado en Supabase');
        }
      } catch (e) {
        debugPrint('Supabase signIn error: $e. Intentando fallback local...');
        // Si hay error de red o configuración, intenta local
        return await LocalDbService.instance.signIn(email, password);
      }
    }

    return await LocalDbService.instance.signIn(email, password);
  }

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    String firstName = 'Colaborador',
    String lastName = '',
    String department = 'Operaciones',
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (isReady) {
      try {
        // Verificar si ya existe
        final existing = await client!
            .from('employees')
            .select('id')
            .ilike('email', cleanEmail)
            .maybeSingle();

        if (existing != null) {
          throw Exception('Este correo ya se encuentra registrado en el sistema');
        }

        final newId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
        final newUser = {
          'id': newId,
          'email': cleanEmail,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'department': department,
          'has_completed_initial_survey': 0,
        };

        await client!.from('employees').insert(newUser);
        await _saveCurrentSession(newUser);

        // Guardar también una copia local por redundancia
        try {
          await LocalDbService.instance.signUp(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            department: department,
          );
        } catch (_) {}

        return newUser;
      } catch (e) {
        debugPrint('Supabase signUp error: $e');
        rethrow;
      }
    }

    return await LocalDbService.instance.signUp(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      department: department,
    );
  }

  Future<void> _saveCurrentSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      try {
        final cached = jsonDecode(userJson) as Map<String, dynamic>;
        if (isReady) {
          try {
            final res = await client!
                .from('employees')
                .select()
                .eq('id', cached['id'])
                .maybeSingle();
            if (res != null) {
              final refreshed = Map<String, dynamic>.from(res);
              await _saveCurrentSession(refreshed);
              return refreshed;
            }
          } catch (_) {}
        }
        return cached;
      } catch (_) {}
    }
    return await LocalDbService.instance.getCurrentUser();
  }

  Future<void> signOut() async {
    try {
      if (isReady) {
        await client?.auth.signOut();
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await LocalDbService.instance.signOut();
  }

  Future<void> updateSurveyCompleted(String employeeId) async {
    if (isReady) {
      try {
        await client!
            .from('employees')
            .update({'has_completed_initial_survey': 1})
            .eq('id', employeeId);
      } catch (e) {
        debugPrint('Error actualizando estado de encuesta en Supabase: $e');
      }
    }
    await LocalDbService.instance.updateSurveyCompleted(employeeId);
  }

  // --- ENCUESTA INICIAL (COPSOQ) ---

  Future<void> saveInitialSurvey({
    required String employeeId,
    required int dim1,
    required int dim2,
    required int dim3,
    required int dim4,
    required int dim5,
    required int dim6,
  }) async {
    final surveyId = 'surv_${DateTime.now().millisecondsSinceEpoch}';

    if (isReady) {
      try {
        await client!.from('initial_survey_results').insert({
          'id': surveyId,
          'employee_id': employeeId,
          'dim1_score': dim1,
          'dim2_score': dim2,
          'dim3_score': dim3,
          'dim4_score': dim4,
          'dim5_score': dim5,
          'dim6_score': dim6,
          'created_at': DateTime.now().toIso8601String(),
        });
        await updateSurveyCompleted(employeeId);
        return;
      } catch (e) {
        debugPrint('Error guardando encuesta en Supabase: $e. Guardando localmente...');
      }
    }

    await LocalDbService.instance.saveInitialSurvey(
      employeeId: employeeId,
      dim1: dim1,
      dim2: dim2,
      dim3: dim3,
      dim4: dim4,
      dim5: dim5,
      dim6: dim6,
    );
  }

  // --- REPORTES CONFIDENCIALES ---

  Future<String> saveAnonymousReport({
    required String moduleTitle,
    required Map<String, dynamic> answers,
    required String department,
  }) async {
    final reportId = 'rep_${DateTime.now().millisecondsSinceEpoch}';

    if (isReady) {
      try {
        // Buscar el ID del módulo si existe
        String? moduleId;
        try {
          final modRes = await client!
              .from('modules')
              .select('id')
              .ilike('title', '%${moduleTitle.split('\n').first}%')
              .limit(1)
              .maybeSingle();
          if (modRes != null) {
            moduleId = modRes['id'];
          }
        } catch (_) {}

        await client!.from('reports').insert({
          'id': reportId,
          'module_id': moduleId,
          'module_title': moduleTitle.replaceAll('\n', ' '),
          'answers': answers,
          'department': department,
          'status': 'new',
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('Reporte guardado exitosamente en Supabase: $reportId');
        return reportId;
      } catch (e) {
        debugPrint('Error guardando reporte en Supabase: $e. Guardando localmente...');
      }
    }

    return await LocalDbService.instance.saveAnonymousReport(
      moduleTitle: moduleTitle,
      answers: answers,
      department: department,
    );
  }

  // --- ASISTENTE DE APOYO EMOCIONAL (CHATBOT) ---

  Future<String> createChatSession(String department) async {
    final sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';

    if (isReady) {
      try {
        await client!.from('chatbot_sessions').insert({
          'id': sessionId,
          'department': department,
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        });
        return sessionId;
      } catch (e) {
        debugPrint('Error creando sesión en Supabase: $e');
      }
    }

    return await LocalDbService.instance.createChatSession(department);
  }

  Future<void> saveChatMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    if (isReady) {
      try {
        await client!.from('chatbot_messages').insert({
          'id': 'msg_${DateTime.now().microsecondsSinceEpoch}',
          'session_id': sessionId,
          'role': role,
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
        });
        return;
      } catch (e) {
        debugPrint('Error guardando mensaje en Supabase: $e');
      }
    }

    await LocalDbService.instance.saveChatMessage(
      sessionId: sessionId,
      role: role,
      content: content,
    );
  }

  Future<void> saveChatInsights({
    required String sessionId,
    required Map<String, dynamic> insights,
  }) async {
    if (isReady) {
      try {
        final topic = insights['tema'] ?? 'General';
        final urgency = insights['urgencia'] ?? 'low';
        final summary = insights['resumen'] ?? '';
        final recommendations = insights['recomendaciones'] ?? [];

        await client!.from('chatbot_insights').insert({
          'id': 'ins_${DateTime.now().millisecondsSinceEpoch}',
          'session_id': sessionId,
          'topic': topic,
          'topic_detected': topic,
          'urgency': urgency,
          'urgency_level': urgency,
          'summary': summary,
          'ai_summary': summary,
          'recommendations': recommendations,
          'sentiment_score': urgency == 'high' ? 3.0 : (urgency == 'medium' ? 5.5 : 8.0),
          'status': 'unread',
          'created_at': DateTime.now().toIso8601String(),
        });

        await client!
            .from('chatbot_sessions')
            .update({'status': 'closed'})
            .eq('id', sessionId);

        debugPrint('Insights guardados exitosamente en Supabase para sesión $sessionId');
        return;
      } catch (e) {
        debugPrint('Error guardando insights en Supabase: $e');
      }
    }

    await LocalDbService.instance.saveChatInsights(
      sessionId: sessionId,
      insights: insights,
    );
  }

  // --- CONSULTAS AUXILIARES ---

  Future<List<Map<String, dynamic>>> fetchModules() async {
    if (isReady) {
      try {
        final res = await client!.from('modules').select('*').order('created_at');
        return List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Error obteniendo módulos de Supabase: $e');
      }
    }
    return [];
  }
}
