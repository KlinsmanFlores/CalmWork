import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._internal();
  LocalDbService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (kIsWeb) {
      dbPath = 'calmwork_local.db';
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docDir.path, 'calmwork_local.db');
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // Tabla de Empleados / Usuarios
        await db.execute('''
          CREATE TABLE employees (
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE,
            password TEXT,
            first_name TEXT,
            last_name TEXT,
            department TEXT,
            has_completed_initial_survey INTEGER DEFAULT 0
          )
        ''');

        // Tabla de Reportes Anónimos
        await db.execute('''
          CREATE TABLE reports (
            id TEXT PRIMARY KEY,
            module_title TEXT,
            answers TEXT,
            department TEXT,
            created_at TEXT
          )
        ''');

        // Tabla de Resultados de Encuesta Inicial
        await db.execute('''
          CREATE TABLE initial_survey_results (
            id TEXT PRIMARY KEY,
            employee_id TEXT,
            dim1_score INTEGER,
            dim2_score INTEGER,
            dim3_score INTEGER,
            dim4_score INTEGER,
            dim5_score INTEGER,
            dim6_score INTEGER,
            created_at TEXT
          )
        ''');

        // Tabla de Sesiones de Chat
        await db.execute('''
          CREATE TABLE chatbot_sessions (
            id TEXT PRIMARY KEY,
            department TEXT,
            status TEXT,
            created_at TEXT
          )
        ''');

        // Tabla de Mensajes de Chat
        await db.execute('''
          CREATE TABLE chatbot_messages (
            id TEXT PRIMARY KEY,
            session_id TEXT,
            role TEXT,
            content TEXT,
            created_at TEXT
          )
        ''');

        // Tabla de Conclusiones de Chat (Insights)
        await db.execute('''
          CREATE TABLE chatbot_insights (
            id TEXT PRIMARY KEY,
            session_id TEXT,
            topic TEXT,
            urgency TEXT,
            summary TEXT,
            recommendations TEXT,
            created_at TEXT
          )
        ''');

        // Insertar usuario de prueba predeterminado
        await db.insert('employees', {
          'id': 'usr_demo_1',
          'email': 'colaborador@calmwork.com',
          'password': '123456',
          'first_name': 'Juan',
          'last_name': 'Pérez',
          'department': 'Operaciones',
          'has_completed_initial_survey': 0,
        });
      },
    );
  }

  // --- AUTENTICACIÓN LOCAL ---

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final db = await database;
    final results = await db.query(
      'employees',
      where: 'LOWER(email) = ? AND password = ?',
      whereArgs: [email.trim().toLowerCase(), password],
      limit: 1,
    );

    if (results.isEmpty) {
      throw Exception('Credenciales incorrectas o usuario no registrado');
    }

    final user = Map<String, dynamic>.from(results.first);
    await _saveCurrentSession(user);
    return user;
  }

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    String firstName = 'Colaborador',
    String lastName = '',
    String department = 'Operaciones',
  }) async {
    final db = await database;
    final cleanEmail = email.trim().toLowerCase();

    final existing = await db.query(
      'employees',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw Exception('Este correo ya se encuentra registrado');
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

    await db.insert('employees', newUser);
    return newUser;
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
        // Refrescar desde DB
        final db = await database;
        final res = await db.query('employees', where: 'id = ?', whereArgs: [cached['id']], limit: 1);
        if (res.isNotEmpty) {
          final refreshed = Map<String, dynamic>.from(res.first);
          await _saveCurrentSession(refreshed);
          return refreshed;
        }
        return cached;
      } catch (_) {}
    }
    return null;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }

  Future<void> updateSurveyCompleted(String employeeId) async {
    final db = await database;
    await db.update(
      'employees',
      {'has_completed_initial_survey': 1},
      where: 'id = ?',
      whereArgs: [employeeId],
    );

    final current = await getCurrentUser();
    if (current != null && current['id'] == employeeId) {
      current['has_completed_initial_survey'] = 1;
      await _saveCurrentSession(current);
    }
  }

  // --- ENCUESTA INICIAL ---

  Future<void> saveInitialSurvey({
    required String employeeId,
    required int dim1,
    required int dim2,
    required int dim3,
    required int dim4,
    required int dim5,
    required int dim6,
  }) async {
    final db = await database;
    await db.insert('initial_survey_results', {
      'id': 'surv_${DateTime.now().millisecondsSinceEpoch}',
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
  }

  // --- REPORTES ANÓNIMOS ---

  Future<String> saveAnonymousReport({
    required String moduleTitle,
    required Map<String, dynamic> answers,
    required String department,
  }) async {
    final db = await database;
    final reportId = 'rep_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('reports', {
      'id': reportId,
      'module_title': moduleTitle,
      'answers': jsonEncode(answers),
      'department': department,
      'created_at': DateTime.now().toIso8601String(),
    });

    return reportId;
  }

  // --- ASISTENTE CHATBOT ---

  Future<String> createChatSession(String department) async {
    final db = await database;
    final sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('chatbot_sessions', {
      'id': sessionId,
      'department': department,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    });

    return sessionId;
  }

  Future<void> saveChatMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    final db = await database;
    await db.insert('chatbot_messages', {
      'id': 'msg_${DateTime.now().microsecondsSinceEpoch}',
      'session_id': sessionId,
      'role': role,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> saveChatInsights({
    required String sessionId,
    required Map<String, dynamic> insights,
  }) async {
    final db = await database;
    await db.insert('chatbot_insights', {
      'id': 'ins_${DateTime.now().millisecondsSinceEpoch}',
      'session_id': sessionId,
      'topic': insights['tema'] ?? 'General',
      'urgency': insights['urgencia'] ?? 'low',
      'summary': insights['resumen'] ?? '',
      'recommendations': jsonEncode(insights['recomendaciones'] ?? []),
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.update(
      'chatbot_sessions',
      {'status': 'closed'},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }
}
