import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'initial_survey.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

Future<String> submitAnonymousReport(String moduleTitle, Map<String, dynamic> answers) async {
  try {
    final supabase = SupabaseClient(
      dotenv.env['SUPABASE_URL'] ?? '',
      dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );

    // 1. Get or create module
    final moduleRes = await supabase.schema('calmwork').from('modules').select('id').eq('title', moduleTitle).maybeSingle();
    String moduleId;
    if (moduleRes == null) {
      final newModule = await supabase.schema('calmwork').from('modules').insert({'title': moduleTitle, 'icon_name': 'AlertTriangle', 'color_hex': '#e2e8f0'}).select('id').single();
      moduleId = newModule['id'];
    } else {
      moduleId = moduleRes['id'];
    }

    // 2. Create report
    final newReport = await supabase.schema('calmwork').from('reports').insert({'module_id': moduleId, 'status': 'new'}).select('id').single();

    // 3. Get or create question
    final questionRes = await supabase.schema('calmwork').from('questions').select('id').eq('module_id', moduleId).eq('question_type', 'text').maybeSingle();
    String questionId;
    if (questionRes == null) {
      final newQuestion = await supabase.schema('calmwork').from('questions').insert({'module_id': moduleId, 'question_text': 'Respuestas Consolidadas del Formulario', 'question_type': 'text'}).select('id').single();
      questionId = newQuestion['id'];
    } else {
      questionId = questionRes['id'];
    }

    // 4. Save answers
    await supabase.schema('calmwork').from('report_answers').insert({
      'report_id': newReport['id'],
      'question_id': questionId,
      'selected_options': answers
    });

    // 5. Save local history
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'anonymous';
    final historyKey = 'history_$userId';
    
    List<String> historyList = prefs.getStringList(historyKey) ?? [];
    
    // Add new report to history
    final reportEntry = {
      'id': newReport['id'],
      'module': moduleTitle,
      'date': DateTime.now().toIso8601String(),
    };
    
    historyList.insert(0, jsonEncode(reportEntry));
    await prefs.setStringList(historyKey, historyList);

    return 'ok';
  } catch (e) {
    debugPrint('Error submitting report to Supabase: $e');
    return e.toString();
  }
}

List<String> globalCompanyAreas = [
  'Administración',
  'Finanzas',
  'Legal',
  'Marketing',
  'Operaciones',
  'Recursos Humanos',
  'Tecnología (TI)',
  'Ventas'
];

Future<void> fetchCompanyAreas() async {
  try {
    final supabase = SupabaseClient(
      dotenv.env['SUPABASE_URL'] ?? '',
      dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    final res = await supabase.schema('calmwork').from('employees').select('department');
    final Set<String> areas = Set.from(globalCompanyAreas);
    for (var row in res) {
      if (row['department'] != null && row['department'].toString().trim().isNotEmpty) {
        areas.add(row['department'].toString().trim());
      }
    }
    final list = areas.toList();
    list.sort();
    globalCompanyAreas = list;
  } catch (e) {
    debugPrint('Error fetching areas: $e');
  }
}

void showSuccessDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: const Icon(Icons.check_circle, color: AppColors.primary, size: 80),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text('¡Reporte Enviado!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              const Text('Gracias por tu tiempo. Tu bienestar es nuestra prioridad y tus respuestas son 100% confidenciales.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Entendido', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Cargar variables de entorno (.env)
  await dotenv.load(fileName: ".env");

  // 2. Inicializar conexión a Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  
  // 3. Fetch areas
  fetchCompanyAreas();

  runApp(const SicoApp());
}

class AppColors {
  static const primary = Color(0xFF246672); // Verde azulado oscuro
  static const primaryLight = Color(0xFF6AB2BB); // Verde azulado claro
  static const background = Color(0xFFCBEAF1); // Celeste claro
  static const cardColor = Colors.white;
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF246672);
}

class SicoApp extends StatelessWidget {
  const SicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalmWORK',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Logo placeholder (Shield)
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: const Icon(Icons.health_and_safety, size: 100, color: Colors.white),
            ),
            const SizedBox(height: 32),
            // CalmWORK Title
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 36, color: AppColors.primary),
                children: [
                  TextSpan(text: 'Calm'),
                  TextSpan(text: 'WORK', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu bienestar importa',
              style: TextStyle(fontSize: 16, color: AppColors.primaryLight, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 48),
            // Heart Icon
            const Icon(Icons.monitor_heart, size: 64, color: AppColors.primaryLight),
            const Spacer(flex: 3),
            // Footer Text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              child: Text(
                'Escuchamos, comprendemos y actuamos por ti',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.primaryLight, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
  bool _isLoading = false;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      final user = res.user;
      if (user != null) {
        // Consultar has_completed_initial_survey
        final employeeRes = await Supabase.instance.client
            .schema('calmwork')
            .from('employees')
            .select('has_completed_initial_survey')
            .eq('id', user.id)
            .maybeSingle();
            
        bool hasCompleted = false;
        if (employeeRes != null && employeeRes['has_completed_initial_survey'] == true) {
          hasCompleted = true;
        }

        if (mounted) {
          if (hasCompleted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigator()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const InitialSurveyScreen()));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Llene los campos para registrarse'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Registro exitoso! Ahora inicia sesión.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Header: Heart and Title
            const Icon(Icons.monitor_heart, size: 60, color: AppColors.primaryLight),
            const SizedBox(height: 16),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 32, color: AppColors.primary),
                children: [
                  TextSpan(text: 'Calm'),
                  TextSpan(text: 'WORK', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Form Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32.0),
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Email Field
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Correo electrónico',
                          hintStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.email, color: Colors.white70),
                          filled: true,
                          fillColor: AppColors.primaryLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Password Field
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          hintStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                          filled: true,
                          fillColor: AppColors.primaryLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Forgot password
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _signIn,
                          child: _isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                              : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Social Login
                      const Text('O inicia sesión con:', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialButton(Icons.g_mobiledata, AppColors.primaryLight),
                          const SizedBox(width: 16),
                          _buildSocialButton(Icons.window, AppColors.primaryLight),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(height: 24),
                      // Solo iniciar sesión, no hay registro
                    ],
                  ),
                ),
              ),
            ),
            // Footer Text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              child: Text(
                'Escuchamos, comprendemos y actuamos por ti',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.primaryLight, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: () {},
      ),
    );
  }
}

// --- MAIN NAVIGATOR (Bottom Nav Bar) ---
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  
  List<Widget> get _screens => [
    HomeScreen(onChatbotPressed: () => setState(() => _currentIndex = 2)),
    const HistoryScreen(),
    const MockChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Historial'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Asistente'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// --- HOME SCREEN ---
class HomeScreen extends StatelessWidget {
  final VoidCallback? onChatbotPressed;
  const HomeScreen({super.key, this.onChatbotPressed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: onChatbotPressed ?? () {},
        backgroundColor: AppColors.primaryLight,
        elevation: 6,
        child: const Icon(Icons.support_agent, color: Colors.white, size: 32),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.monitor_heart, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 24, color: AppColors.primary),
                          children: [
                            TextSpan(text: 'Calm'),
                            TextSpan(text: 'WORK', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Text('Tu bienestar importa', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w500)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 32),
              // Salutation
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hola, ¿cómo te sientes hoy?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 8),
                        const Text('Selecciona la opción que mejor describa lo que estás viviendo.', style: TextStyle(color: AppColors.primary, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.self_improvement, size: 80, color: Color(0xFFE59866)),
                ],
              ),
              const SizedBox(height: 32),
              // Grid of modules
              Row(
                children: [
                  Expanded(child: _buildModuleCard('SOBRECARGA LABORAL', 'Exceso de tareas y carga de trabajo', Icons.inventory_2, const Color(0xFFFDE8D4), AppColors.textPrimary, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SobrecargaScreen()));
                  })),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModuleCard('ACOSO LABORAL', 'Situaciones de hostigamiento o maltrato', Icons.record_voice_over, const Color(0xFFE8C4FA), AppColors.textPrimary, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AcosoScreen()));
                  })),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildModuleCard('DISCRIMINACIÓN Y EXCLUSIÓN', 'Trato desigual o exclusión laboral.', Icons.groups, const Color(0xFFFF6B6B), Colors.white, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DiscriminacionScreen()));
                  })),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModuleCard('PROBLEMAS PERSONALES', 'Situaciones personales que afectan el trabajo.', Icons.psychology, const Color(0xFFFDCB61), AppColors.textPrimary, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProblemasPersonalesScreen()));
                  })),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(flex: 1, child: SizedBox()),
                  Expanded(flex: 2, child: _buildModuleCard('SUGERENCIAS Y MEJORAS', 'Ideas para mejorar el ambiente laboral.', Icons.lightbulb_outline, const Color(0xFFBFFC6F), AppColors.textPrimary, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SugerenciasScreen()));
                  })),
                  const Expanded(flex: 1, child: SizedBox()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(String title, String subtitle, IconData icon, Color bgColor, Color textColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
            const SizedBox(height: 12),
            Icon(icon, size: 40, color: textColor),
            const SizedBox(height: 12),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: textColor)),
          ],
        ),
      ),
    );
  }
}

// --- HISTORY SCREEN ---
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? 'anonymous';
      final historyKey = 'history_$userId';
      
      final historyList = prefs.getStringList(historyKey) ?? [];
      setState(() {
        _history = historyList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mis Reportes', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _history.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 80, color: Colors.black12),
                        SizedBox(height: 16),
                        Text('No has enviado ningún reporte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        SizedBox(height: 8),
                        Text('Tus reportes enviados aparecerán aquí de forma privada.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final report = _history[index];
                    final dateStr = report['date'] as String;
                    final date = DateTime.tryParse(dateStr);
                    final formattedDate = date != null ? '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}' : dateStr;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                        ),
                        title: Text(report['module'] ?? 'Reporte', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text('Enviado el $formattedDate', style: const TextStyle(fontSize: 12)),
                        ),
                        trailing: const Icon(Icons.privacy_tip, color: Colors.black26),
                      ),
                    );
                  },
                ),
    );
  }
}

// --- CHAT SCREEN (MOCKED, NO BACKEND) ---
class MockChatScreen extends StatefulWidget {
  const MockChatScreen({super.key});

  @override
  State<MockChatScreen> createState() => _MockChatScreenState();
}

class _MockChatScreenState extends State<MockChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"role": "bot", "content": "Hola, soy el asistente de bienestar de la empresa. Este espacio es anónimo. ¿Cómo te has sentido últimamente en el trabajo?"}
  ];

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    
    final userText = _controller.text;
    setState(() {
      _messages.add({"role": "user", "content": userText});
      _controller.clear();
    });

    // Simulador estático local
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add({"role": "bot", "content": "Entiendo. Esta es una respuesta estática visual para propósitos de diseño. No hay conexión al backend en este momento."});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente Anónimo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false, // Quitar botón atrás ya que está en el nav inferior
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primaryLight : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    child: Text(
                      msg["content"]!,
                      style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Escribe tu mensaje...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- PROFILE SCREEN ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _firstName = '';
  String _lastName = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _email = user.email ?? '';
        final res = await Supabase.instance.client
            .schema('calmwork')
            .from('employees')
            .select('first_name, last_name')
            .eq('id', user.id)
            .maybeSingle();

        if (res != null) {
          _firstName = res['first_name'] ?? '';
          _lastName = res['last_name'] ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get _initials {
    if (_firstName.isEmpty && _lastName.isEmpty) return '?';
    String ini = '';
    if (_firstName.isNotEmpty) ini += _firstName[0];
    if (_lastName.isNotEmpty) ini += _lastName[0];
    return ini.toUpperCase();
  }

  String get _fullName {
    if (_firstName.isEmpty && _lastName.isEmpty) return 'Usuario';
    return '$_firstName $_lastName'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      _initials,
                      style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(child: Text(_fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                Center(child: Text(_email, style: const TextStyle(color: AppColors.textSecondary))),
                const SizedBox(height: 40),
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                  title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                  onTap: () {},
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.security_outlined, color: AppColors.textPrimary),
                  title: const Text('Privacidad y Anonimato', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                  onTap: () {},
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: AppColors.textPrimary),
                  title: const Text('Centro de Ayuda', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                  onTap: () {},
                ),
                const Divider(),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Supabase.instance.client.auth.signOut();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                ),
              ],
            ),
    );
  }
}

// --- SOBRECARGA SCREEN ---



class SobrecargaScreen extends StatefulWidget {
  const SobrecargaScreen({super.key});

  @override
  State<SobrecargaScreen> createState() => _SobrecargaScreenState();
}

class _SobrecargaScreenState extends State<SobrecargaScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _descController = TextEditingController();
  bool _isSubmitting = false;
  int _currentPage = 0;
  final int _totalPages = 8;
  Map<String, dynamic> _responses = {};

  void _record(String q, String a) {
    setState(() => _responses[q] = a);
    Future.delayed(const Duration(milliseconds: 300), _nextPage);
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_currentPage + 1) / _totalPages;
    String motivationalText = '';
    if (progress <= 0.3) motivationalText = '¡Excelente inicio!';
    else if (progress <= 0.6) motivationalText = 'Vas por la mitad, ¡sigue así!';
    else if (progress < 1.0) motivationalText = '¡Ya casi terminas, un poco más!';
    else motivationalText = '¡Último paso!';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primary), onPressed: () {
          if (_currentPage > 0) {
            _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
          } else {
            Navigator.pop(context);
          }
        }),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Módulo: Sobrecarga Laboral', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.normal)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Pregunta ${_currentPage + 1} de $_totalPages', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                  color: AppColors.primary,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(motivationalText, style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // El usuario debe responder para avanzar
              onPageChanged: (idx) => setState(() => _currentPage = idx),
        children: [
          _buildFacesQuestion('¿Con qué frecuencia siente que tiene más trabajo del que puede realizar?'),
          _buildBinaryQuestion('¿Considera que el tiempo asignado para sus tareas es suficiente?'),
          _buildClocksQuestion('¿Con qué frecuencia debe trabajar fuera de su horario laboral?'),
          _buildFacesQuestion('¿Siente agotamiento físico o mental al finalizar su jornada?'),
          _buildBinaryQuestion('¿La carga laboral afecta su vida personal o familiar?'),
          _buildLevelsQuestion('¿Qué nivel de afectación le genera esta situación?'),
          _buildDropdownsQuestion(),
          _buildTextQuestion(),
        ],
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContainer({required String title, String? subtitle, required Widget child, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
  Widget _buildFacesQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      icon: Icons.sentiment_satisfied_alt,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 24,
          children: [
            _buildFaceOption(Icons.sentiment_very_satisfied, Colors.green, 'Nunca', () => _record(title, 'Nunca')),
            _buildFaceOption(Icons.sentiment_satisfied, Colors.lightGreen, 'Rara vez', () => _record(title, 'Rara vez')),
            _buildFaceOption(Icons.sentiment_neutral, Colors.amber, 'A veces', () => _record(title, 'A veces')),
            _buildFaceOption(Icons.sentiment_dissatisfied, Colors.orange, 'Frecuente', () => _record(title, 'Frecuente')),
            _buildFaceOption(Icons.sentiment_very_dissatisfied, Colors.red, 'Siempre', () => _record(title, 'Siempre')),
          ],
        ),
      ),
    );
  }
  Widget _buildFaceOption(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Icon(icon, color: color, size: 36)
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
  Widget _buildClocksQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      icon: Icons.access_time_filled,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 24,
          children: [
            _buildFaceOption(Icons.access_time, Colors.green, 'Nunca', () => _record(title, 'Nunca')),
            _buildFaceOption(Icons.timelapse, Colors.amber, 'Ocasional', () => _record(title, 'Ocasional')),
            _buildFaceOption(Icons.history_toggle_off, Colors.orange, 'Frecuente', () => _record(title, 'Frecuente')),
            _buildFaceOption(Icons.alarm_on, Colors.red, 'Siempre', () => _record(title, 'Siempre')),
          ],
        ),
      ),
    );
  }
  Widget _buildBinaryQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      child: Row(
        children: [
          Expanded(child: _buildBigButton('Sí', Colors.green, () => _record(title, 'Sí'))),
          const SizedBox(width: 16),
          Expanded(child: _buildBigButton('No', Colors.red, () => _record(title, 'No'))),
        ],
      ),
    );
  }

  Widget _buildBigButton(String label, Color color, VoidCallback onTap, {IconData? icon}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 2,
        shadowColor: color.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 28), const SizedBox(width: 12)],
          Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
        ],
      ),
    );
  }
  Widget _buildLevelsQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      child: Column(
        children: [
          _buildLevelButton('Bajo', Colors.green, () => _record(title, 'Bajo')),
          const SizedBox(height: 12),
          _buildLevelButton('Medio', Colors.amber, () => _record(title, 'Medio')),
          const SizedBox(height: 12),
          _buildLevelButton('Alto', Colors.orange, () => _record(title, 'Alto')),
          const SizedBox(height: 12),
          _buildLevelButton('Crítico', Colors.red, () => _record(title, 'Crítico')),
        ],
      ),
    );
  }

  Widget _buildLevelButton(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
      ),
    );
  }

  Widget _buildDropdownsQuestion() {
    return _buildQuestionContainer(
      title: 'Casi terminamos. Por favor, selecciona tu área y antigüedad.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Área de trabajo', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            items: globalCompanyAreas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
            onChanged: (val) { if(val!=null) setState(() => _responses['Área'] = val); },
            hint: const Text('Seleccionar área'),
          ),
          const SizedBox(height: 24),
          const Text('Antigüedad en la empresa', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            items: const [DropdownMenuItem(value: '<1', child: Text('Menos de 1 año')), DropdownMenuItem(value: '1-3', child: Text('1 a 3 años')), DropdownMenuItem(value: '>3', child: Text('Más de 3 años'))],
            onChanged: (val) { if(val!=null) setState(() => _responses['Antigüedad'] = val); },
            hint: const Text('Seleccionar'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: (_responses['Área'] == null || _responses['Antigüedad'] == null) ? null : _nextPage,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildTextQuestion() {
    return _buildQuestionContainer(
      title: 'Descripción del problema',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Cuéntanos qué está ocurriendo. Describe brevemente la situación que consideras que está generando sobrecarga laboral.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              onChanged: (_) => setState((){}),
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Escribe aquí...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isSubmitting || _descController.text.trim().isEmpty) ? null : () async {
                  setState(() => _isSubmitting = true);
                  _responses['Descripción'] = _descController.text;
                  String result = await submitAnonymousReport('Sobrecarga Laboral', _responses);
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                    if (result == 'ok') {
                      showSuccessDialog(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar el reporte: $result')));
                    }
                  }
                },
                icon: _isSubmitting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
                label: Text(_isSubmitting ? 'Enviando...' : 'Enviar reporte confidencial', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ACOSO SCREEN ---
class AcosoScreen extends StatefulWidget {
  const AcosoScreen({super.key});

  @override
  State<AcosoScreen> createState() => _AcosoScreenState();
}

class _AcosoScreenState extends State<AcosoScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _descController1 = TextEditingController();
  final TextEditingController _descController2 = TextEditingController();
  bool _isSubmitting = false;
  int _currentPage = 0;
  final int _totalPages = 8;

  // States for interactive widgets
  Set<String> _selectedAcosoTypes = {};
  String? _selectedAggressor;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Set<String> _selectedAffections = {};

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_currentPage + 1) / _totalPages;
    String motivationalText = '';
    if (progress <= 0.3) motivationalText = 'Tu valentía cuenta.';
    else if (progress <= 0.6) motivationalText = 'Estamos aquí para ayudarte.';
    else if (progress < 1.0) motivationalText = 'Casi terminamos, continúa.';
    else motivationalText = 'Último paso. No estás solo(a).';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primary), onPressed: () {
          if (_currentPage > 0) {
            _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
          } else {
            Navigator.pop(context);
          }
        }),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Módulo: Acoso Laboral', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.normal)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pan_tool, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Text('Pregunta ${_currentPage + 1} de $_totalPages', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                  color: Colors.redAccent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(motivationalText, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              children: [
                _buildQ1(),
                _buildQ2(),
                _buildQ3(),
                _buildQ4(),
                _buildQ5(),
                _buildQ6(),
                _buildQ7(),
                _buildQ8(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContainer({required String title, String? subtitle, required Widget child, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
  Widget _buildQ1() {
    return _buildQuestionContainer(
      title: '¿Has sido víctima de acoso laboral?',
      icon: Icons.shield_outlined,
      subtitle: 'Entendemos que puede ser difícil hablar de esto. Tu reporte será tratado con la máxima confidencialidad.',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBigButton('Sí, he sido víctima', Colors.green, () => Future.delayed(const Duration(milliseconds: 300), _nextPage), icon: Icons.check_circle_outline),
          const SizedBox(height: 16),
          _buildBigButton('Reportar por alguien más', Colors.red, () => Future.delayed(const Duration(milliseconds: 300), _nextPage), icon: Icons.group_add_outlined),
        ],
      ),
    );
  }

  Widget _buildQ2() {
    return _buildQuestionContainer(
      title: '¿Qué tipo de acoso has experimentado?',
      icon: Icons.warning_amber_rounded,
      subtitle: 'Puedes seleccionar más de una opción.',
      child: Column(
        children: [
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildAcosoCard('Acoso verbal', 'Insultos, humillaciones', Icons.record_voice_over),
                _buildAcosoCard('Acoso psicológico', 'Amenazas, intimidación', Icons.psychology),
                _buildAcosoCard('Acoso físico', 'Contacto físico no deseado', Icons.pan_tool),
                _buildAcosoCard('Discriminación', 'Trato injusto', Icons.group_remove),
                _buildAcosoCard('Acoso sexual', 'Comentarios o acciones', Icons.visibility_off),
                _buildAcosoCard('Otro', 'Especifica en la descripción', Icons.add_circle_outline),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildAcosoCard(String title, String subtitle, IconData icon) {
    bool isSelected = _selectedAcosoTypes.contains(title);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) _selectedAcosoTypes.remove(title);
          else _selectedAcosoTypes.add(title);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight.withOpacity(0.2) : Colors.white,
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 32),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildQ3() {
    List<String> options = ['Compañero(a) de trabajo', 'Jefe(a) o superior inmediato', 'Subordinado(a)', 'Cliente o proveedor', 'Otra persona (especificar en la descripción)'];
    return _buildQuestionContainer(
      title: '¿Quién es la persona agresora?',
      icon: Icons.person_search_outlined,
      subtitle: 'Selecciona la opción que corresponda.',
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: options.map((opt) {
                return RadioListTile<String>(
                  title: Text(opt),
                  value: opt,
                  groupValue: _selectedAggressor,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => _selectedAggressor = val);
                  },
                );
              }).toList(),
            ),
          ),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildQ4() {
    return _buildQuestionContainer(
      title: '¿Cuándo ocurrió?',
      icon: Icons.event_note,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              DateTime? d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
              if (d != null) setState(() => _selectedDate = d);
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(_selectedDate == null ? 'Seleccionar fecha' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300))),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (t != null) setState(() => _selectedTime = t);
            },
            icon: const Icon(Icons.access_time),
            label: Text(_selectedTime == null ? 'Seleccionar hora' : _selectedTime!.format(context)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300))),
          ),
          const SizedBox(height: 40),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildQ5() {
    return _buildQuestionContainer(
      title: '¿Hay testigos de la situación?',
      icon: Icons.visibility_outlined,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildBigButton('Sí', Colors.green, () => Future.delayed(const Duration(milliseconds: 300), _nextPage))),
          const SizedBox(width: 16),
          Expanded(child: _buildBigButton('No', Colors.red, () => Future.delayed(const Duration(milliseconds: 300), _nextPage))),
        ],
      ),
    );
  }

  Widget _buildQ6() {
    return _buildQuestionContainer(
      title: 'Descripción del hecho',
      icon: Icons.edit_note,
      subtitle: 'Cuéntanos qué ocurrió. Incluye detalles que consideres importantes.',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descController1,
              onChanged: (val) => setState((){}),
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(hintText: 'Describe brevemente la situación...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            ),
            const SizedBox(height: 24),
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildQ7() {
    List<String> options = ['Estrés', 'Ansiedad', 'Tristeza', 'Bajo rendimiento', 'Problemas de sueño', 'Otro'];
    return _buildQuestionContainer(
      title: '¿Cómo te ha afectado esta situación?',
      icon: Icons.healing,
      subtitle: 'Puedes seleccionar más de una opción.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: options.map((opt) {
                  bool isSel = _selectedAffections.contains(opt);
                  return FilterChip(
                    label: Text(opt),
                    selected: isSel,
                    onSelected: (val) {
                      setState(() {
                        if (val) _selectedAffections.add(opt);
                        else _selectedAffections.remove(opt);
                      });
                    },
                    selectedColor: AppColors.primaryLight.withOpacity(0.3),
                    checkmarkColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),
            ),
          ),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildQ8() {
    return _buildQuestionContainer(
      title: 'Sugerencias o medidas que consideras podrían ayudar',
      icon: Icons.lightbulb_outline,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descController2,
              onChanged: (val) => setState((){}),
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(hintText: 'Escribe aquí tus sugerencias...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.security, color: AppColors.primary, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('No estás solo(a).\nTu reporte será atendido por el área de Recursos Humanos o el comité correspondiente.', style: TextStyle(fontSize: 12, color: AppColors.primary))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isSubmitting || _descController2.text.trim().isEmpty) ? null : () async {
                  setState(() => _isSubmitting = true);
                  Map<String, dynamic> payload = {
                    'Tipos de acoso': _selectedAcosoTypes.toList(),
                    'Agresor': _selectedAggressor,
                    'Fecha': _selectedDate?.toIso8601String(),
                    'Hora': _selectedTime?.format(context),
                    'Afectaciones': _selectedAffections.toList(),
                    'Descripción del hecho': _descController1.text,
                    'Sugerencias': _descController2.text
                  };
                  String result = await submitAnonymousReport('Acoso Laboral', payload);
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                    if (result == 'ok') {
                      showSuccessDialog(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar el reporte: $result')));
                    }
                  }
                },
                icon: _isSubmitting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.security),
                label: Text(_isSubmitting ? 'Enviando...' : 'Enviar reporte confidencial', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton(String label, Color color, VoidCallback onTap, {IconData? icon}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 2,
        shadowColor: color.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 28), const SizedBox(width: 12)],
          Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
        ],
      ),
    );
  }
  bool _canProceed() {
    if (_currentPage == 1) return _selectedAcosoTypes.isNotEmpty;
    if (_currentPage == 2) return _selectedAggressor != null;
    if (_currentPage == 3) return _selectedDate != null && _selectedTime != null;
    if (_currentPage == 5) return _descController1.text.trim().isNotEmpty;
    if (_currentPage == 6) return _selectedAffections.isNotEmpty;
    return true;
  }

  Widget _buildNextButton() {
    return ElevatedButton(
      onPressed: _canProceed() ? _nextPage : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, 
        padding: const EdgeInsets.symmetric(vertical: 18), 
        elevation: 4,
        shadowColor: AppColors.primary.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Siguiente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
        ],
      ),
    );
  }
}

// --- DISCRIMINACION SCREEN ---
class DiscriminacionScreen extends StatefulWidget {
  const DiscriminacionScreen({super.key});

  @override
  State<DiscriminacionScreen> createState() => _DiscriminacionScreenState();
}

class _DiscriminacionScreenState extends State<DiscriminacionScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _descController = TextEditingController();
  bool _isSubmitting = false;
  int _currentPage = 0;
  Map<String, dynamic> _responses = {};

  void _record(String q, String a) {
    setState(() => _responses[q] = a);
    Future.delayed(const Duration(milliseconds: 300), _nextPage);
  }
  final int _totalPages = 8;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_currentPage + 1) / _totalPages;
    String motivationalText = '';
    if (progress <= 0.3) motivationalText = 'Tu voz es importante.';
    else if (progress <= 0.6) motivationalText = 'Gracias por compartir tu experiencia.';
    else if (progress < 1.0) motivationalText = 'Ya falta poco, continúa.';
    else motivationalText = 'Último paso. Juntos mejoramos.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primary), onPressed: () {
          if (_currentPage > 0) {
            _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
          } else {
            Navigator.pop(context);
          }
        }),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Módulo: Discriminación y Exclusión', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.normal)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.work, color: Colors.deepPurpleAccent, size: 20),
                const SizedBox(width: 8),
                Text('Pregunta ${_currentPage + 1} de $_totalPages', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                  color: Colors.deepPurpleAccent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(motivationalText, style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              children: [
                _buildFacesQuestion('¿Has sido tratado(a) de manera diferente por tu género, edad, origen, religión, apariencia u otra condición?'),
                _buildFacesQuestion('¿Has escuchado comentarios ofensivos, burlas o palabras que te hagan sentir menos o excluido(a)?'),
                _buildBinaryQuestion('¿Te han excluido de actividades, reuniones o decisiones importantes?'),
                _buildLevelsQuestion('¿Cómo te ha afectado esta situación emocionalmente?'),
                _buildDropdownArea(),
                _buildDropdownAntiguedad(),
                _buildTextQuestion('Descripción del problema', 'Cuéntanos qué está ocurriendo. Describe brevemente la situación que consideras que está generando discriminación o exclusión...'),
                _buildSugerencias(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContainer({required String title, String? subtitle, required Widget child, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
  Widget _buildFacesQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      icon: Icons.sentiment_satisfied_alt,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 24,
          children: [
            _buildFaceOption(Icons.sentiment_very_satisfied, Colors.green, 'Nunca', () => _record(title, 'Nunca')),
            _buildFaceOption(Icons.sentiment_satisfied, Colors.lightGreen, 'Rara vez', () => _record(title, 'Rara vez')),
            _buildFaceOption(Icons.sentiment_neutral, Colors.amber, 'A veces', () => _record(title, 'A veces')),
            _buildFaceOption(Icons.sentiment_dissatisfied, Colors.orange, 'Frecuente', () => _record(title, 'Frecuente')),
            _buildFaceOption(Icons.sentiment_very_dissatisfied, Colors.red, 'Siempre', () => _record(title, 'Siempre')),
          ],
        ),
      ),
    );
  }
  Widget _buildFaceOption(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Icon(icon, color: color, size: 36)
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
  Widget _buildBinaryQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      child: Row(
        children: [
          Expanded(child: _buildBigButton('Sí', Colors.green, () => _record(title, 'Sí'))),
          const SizedBox(width: 16),
          Expanded(child: _buildBigButton('No', Colors.red, () => _record(title, 'No'))),
        ],
      ),
    );
  }

  Widget _buildBigButton(String label, Color color, VoidCallback onTap, {IconData? icon}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 2,
        shadowColor: color.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 28), const SizedBox(width: 12)],
          Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
        ],
      ),
    );
  }
  Widget _buildLevelsQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      child: Column(
        children: [
          _buildLevelButton('Poco', Colors.green, () => _record(title, 'Poco')),
          const SizedBox(height: 12),
          _buildLevelButton('Moderado', Colors.amber, () => _record(title, 'Moderado')),
          const SizedBox(height: 12),
          _buildLevelButton('Mucho', Colors.orange, () => _record(title, 'Mucho')),
          const SizedBox(height: 12),
          _buildLevelButton('Extremadamente', Colors.red, () => _record(title, 'Extremadamente')),
        ],
      ),
    );
  }

  Widget _buildLevelButton(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
      ),
    );
  }

  Widget _buildDropdownArea() {
    return _buildQuestionContainer(
      title: 'Área de trabajo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Selecciona tu área', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.apartment),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            items: globalCompanyAreas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
            onChanged: (val) { if (val != null) setState(() => _responses['Área'] = val); },
            hint: const Text('Seleccionar área'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _responses['Área'] == null ? null : _nextPage,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildDropdownAntiguedad() {
    return _buildQuestionContainer(
      title: 'Antigüedad en la empresa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('¿Cuánto tiempo llevas trabajando aquí?', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.date_range),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            items: const [DropdownMenuItem(value: '1', child: Text('Menos de 1 año')), DropdownMenuItem(value: '2', child: Text('1 a 3 años'))],
            onChanged: (val) { if (val != null) setState(() => _responses['Antigüedad'] = val); },
            hint: const Text('Seleccionar'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _responses['Antigüedad'] == null ? null : _nextPage,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildTextQuestion(String title, String hint) {
    return _buildQuestionContainer(
      title: title,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: (val) => setState(() => _responses[title] = val),
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_responses[title] ?? '').trim().isEmpty ? null : _nextPage,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSugerencias() {
    return _buildQuestionContainer(
      title: 'Sugerencias del trabajador',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Qué medida consideras que podría ayudar a mejorar esta situación?', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              onChanged: (val) => setState(() => _responses['Sugerencias adicionales'] = val),
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Escribe aquí tus sugerencias...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.send_rounded, color: Colors.deepPurpleAccent, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Tu reporte es importante.\nGracias por ayudarnos a construir un mejor ambiente laboral para todos.', style: TextStyle(fontSize: 12, color: Colors.deepPurpleAccent))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isSubmitting || (_responses['Sugerencias adicionales'] ?? '').trim().isEmpty) ? null : () async {
                  setState(() => _isSubmitting = true);
                  String result = await submitAnonymousReport('Discriminación y Exclusión', _responses);
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                    if (result == 'ok') {
                      showSuccessDialog(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar el reporte: $result')));
                    }
                  }
                },
                icon: _isSubmitting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.group_off),
                label: Text(_isSubmitting ? 'Enviando...' : 'Enviar reporte confidencial', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PROBLEMAS PERSONALES SCREEN ---
class ProblemasPersonalesScreen extends StatefulWidget {
  const ProblemasPersonalesScreen({super.key});

  @override
  State<ProblemasPersonalesScreen> createState() => _ProblemasPersonalesScreenState();
}

class _ProblemasPersonalesScreenState extends State<ProblemasPersonalesScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _descController = TextEditingController();
  bool _isSubmitting = false;
  int _currentPage = 0;
  Map<String, dynamic> _responses = {};

  void _record(String q, String a) {
    setState(() => _responses[q] = a);
    Future.delayed(const Duration(milliseconds: 300), _nextPage);
  }
  final int _totalPages = 8;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_currentPage + 1) / _totalPages;
    String motivationalText = '';
    if (progress <= 0.3) motivationalText = 'Estamos aquí para ti.';
    else if (progress <= 0.6) motivationalText = 'Gracias por la confianza.';
    else if (progress < 1.0) motivationalText = 'Ya falta poco, continúa.';
    else motivationalText = 'Último paso. Tu bienestar importa.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primary), onPressed: () {
          if (_currentPage > 0) {
            _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
          } else {
            Navigator.pop(context);
          }
        }),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Módulo: Problemas Personales', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.normal)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, color: Colors.deepPurpleAccent, size: 20),
                const SizedBox(width: 8),
                Text('Pregunta ${_currentPage + 1} de $_totalPages', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                  color: Colors.deepPurpleAccent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(motivationalText, style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              children: [
                _buildFacesQuestion('¿Consideras que tus problemas personales están afectando tu desempeño laboral?'),
                _buildFacesQuestion('¿Te sientes emocionalmente agotado(a) debido a situaciones personales?'),
                _buildFacesQuestion('¿Te cuesta concentrarte o mantener el rendimiento en el trabajo?'),
                _buildBinaryQuestion('¿Has necesitado ausentarte o pedir permisos por esta situación?'),
                _buildDropdownArea(),
                _buildDropdownAntiguedad(),
                _buildTextQuestion('Descripción del problema', 'Describe brevemente la situación personal que consideras que está afectando tu bienestar y trabajo...'),
                _buildSugerencias(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContainer({required String title, String? subtitle, required Widget child, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
  Widget _buildFacesQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      icon: Icons.sentiment_satisfied_alt,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 24,
          children: [
            _buildFaceOption(Icons.sentiment_very_satisfied, Colors.green, 'Nunca', () => _record(title, 'Nunca')),
            _buildFaceOption(Icons.sentiment_satisfied, Colors.lightGreen, 'Rara vez', () => _record(title, 'Rara vez')),
            _buildFaceOption(Icons.sentiment_neutral, Colors.amber, 'A veces', () => _record(title, 'A veces')),
            _buildFaceOption(Icons.sentiment_dissatisfied, Colors.orange, 'Frecuente', () => _record(title, 'Frecuente')),
            _buildFaceOption(Icons.sentiment_very_dissatisfied, Colors.red, 'Siempre', () => _record(title, 'Siempre')),
          ],
        ),
      ),
    );
  }
  Widget _buildFaceOption(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Icon(icon, color: color, size: 36)
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
  Widget _buildBinaryQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      child: Row(
        children: [
          Expanded(child: _buildBigButton('Sí', Colors.green, () => _record(title, 'Sí'))),
          const SizedBox(width: 16),
          Expanded(child: _buildBigButton('No', Colors.red, () => _record(title, 'No'))),
        ],
      ),
    );
  }

  Widget _buildBigButton(String label, Color color, VoidCallback onTap, {IconData? icon}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 2,
        shadowColor: color.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 28), const SizedBox(width: 12)],
          Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
        ],
      ),
    );
  }
  Widget _buildDropdownArea() {
    return _buildQuestionContainer(
      title: 'Área de trabajo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Selecciona tu área', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.apartment),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            items: globalCompanyAreas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
            onChanged: (val) { if (val != null) setState(() => _responses['Área'] = val); },
            hint: const Text('Seleccionar área'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _responses['Área'] == null ? null : _nextPage,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildDropdownAntiguedad() {
    return _buildQuestionContainer(
      title: 'Antigüedad en la empresa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('¿Cuánto tiempo llevas trabajando aquí?', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.date_range),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            items: const [DropdownMenuItem(value: '1', child: Text('Menos de 1 año')), DropdownMenuItem(value: '2', child: Text('1 a 3 años'))],
            onChanged: (val) { if (val != null) setState(() => _responses['Antigüedad'] = val); },
            hint: const Text('Seleccionar'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _responses['Antigüedad'] == null ? null : _nextPage,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildTextQuestion(String title, String hint) {
    return _buildQuestionContainer(
      title: title,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: (val) => setState(() => _responses[title] = val),
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_responses[title] ?? '').trim().isEmpty ? null : _nextPage,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSugerencias() {
    return _buildQuestionContainer(
      title: 'Sugerencias del trabajador',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Qué tipo de apoyo o medida consideras que podría ayudarte?', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              onChanged: (val) => setState(() => _responses['Sugerencias adicionales'] = val),
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Escribe aquí tus sugerencias...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.send_rounded, color: Colors.deepPurpleAccent, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Tu reporte es importante.\nGracias por ayudarnos a construir un mejor ambiente laboral para todos.', style: TextStyle(fontSize: 12, color: Colors.deepPurpleAccent))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isSubmitting || (_responses['Sugerencias adicionales'] ?? '').trim().isEmpty) ? null : () async {
                  setState(() => _isSubmitting = true);
                  String result = await submitAnonymousReport('Problemas Personales', _responses);
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                    if (result == 'ok') {
                      showSuccessDialog(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar el reporte: $result')));
                    }
                  }
                },
                icon: _isSubmitting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.psychology),
                label: Text(_isSubmitting ? 'Enviando...' : 'Enviar reporte confidencial', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SUGERENCIAS Y MEJORAS SCREEN ---
class SugerenciasScreen extends StatefulWidget {
  const SugerenciasScreen({super.key});

  @override
  State<SugerenciasScreen> createState() => _SugerenciasScreenState();
}

class _SugerenciasScreenState extends State<SugerenciasScreen> {
  final Map<String, dynamic> _responses = {};
  bool _isSubmitting = false;
  final PageController _pageController = PageController();
  final TextEditingController _descController = TextEditingController();
  int _currentPage = 0;
  void _record(String q, String a) {
    setState(() => _responses[q] = a);
    Future.delayed(const Duration(milliseconds: 300), _nextPage);
  }
  final int _totalPages = 10;

  // States
  Set<String> _selectedMejoras = {};
  Set<String> _selectedBeneficios = {};

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_currentPage + 1) / _totalPages;
    String motivationalText = '';
    if (progress <= 0.3) motivationalText = 'Tus ideas valen mucho.';
    else if (progress <= 0.6) motivationalText = 'Tu opinión nos importa.';
    else if (progress < 1.0) motivationalText = 'Excelente aporte, continúa.';
    else motivationalText = 'Último paso. Juntos crecemos.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.primary), onPressed: () {
          if (_currentPage > 0) {
            _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
          } else {
            Navigator.pop(context);
          }
        }),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Módulo: Sugerencias y Mejoras', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.normal)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb, color: Colors.deepPurpleAccent, size: 20),
                const SizedBox(width: 8),
                Text('Pregunta ${_currentPage + 1} de $_totalPages', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                  color: Colors.deepPurpleAccent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(motivationalText, style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              children: [
                _buildFacesQuestion('¿Considera que existen aspectos del trabajo que podrían mejorarse?'),
                _buildFacesQuestion('¿Siente que sus opiniones o propuestas son escuchadas por la empresa?'),
                _buildBinaryQuestion('¿Ha identificado problemas que afectan el bienestar o desempeño de los trabajadores?'),
                _buildLevelsQuestion('¿Qué impacto tendría la mejora que propone?'),
                _buildDropdownArea(),
                _buildDropdownAntiguedad(),
                _buildGridMejoras(),
                _buildTextQuestion('Descripción de la sugerencia', 'Cuéntanos tu propuesta de mejora. Describe brevemente tu sugerencia...'),
                _buildGridBeneficios(),
                _buildSugerencias(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContainer({required String title, String? subtitle, required Widget child, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
  Widget _buildFacesQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      icon: Icons.sentiment_satisfied_alt,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 24,
          children: [
            _buildFaceOption(Icons.sentiment_very_satisfied, Colors.green, 'Nunca', () => _record(title, 'Nunca')),
            _buildFaceOption(Icons.sentiment_satisfied, Colors.lightGreen, 'Rara vez', () => _record(title, 'Rara vez')),
            _buildFaceOption(Icons.sentiment_neutral, Colors.amber, 'A veces', () => _record(title, 'A veces')),
            _buildFaceOption(Icons.sentiment_dissatisfied, Colors.orange, 'Frecuente', () => _record(title, 'Frecuente')),
            _buildFaceOption(Icons.sentiment_very_dissatisfied, Colors.red, 'Siempre', () => _record(title, 'Siempre')),
          ],
        ),
      ),
    );
  }
  Widget _buildFaceOption(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Icon(icon, color: color, size: 36)
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
  Widget _buildBinaryQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildBigButton('Sí', Colors.green, () => _record(title, 'Sí'))),
          const SizedBox(width: 16),
          Expanded(child: _buildBigButton('No', Colors.red, () => _record(title, 'No'))),
        ],
      ),
    );
  }

  Widget _buildBigButton(String label, Color color, VoidCallback onTap, {IconData? icon}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 2,
        shadowColor: color.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 28), const SizedBox(width: 12)],
          Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
        ],
      ),
    );
  }
  Widget _buildLevelsQuestion(String title) {
    return _buildQuestionContainer(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLevelButton('Bajo', Colors.green, () => _record(title, 'Bajo')),
          const SizedBox(height: 12),
          _buildLevelButton('Medio', Colors.amber, () => _record(title, 'Medio')),
          const SizedBox(height: 12),
          _buildLevelButton('Alto', Colors.orange, () => _record(title, 'Alto')),
          const SizedBox(height: 12),
          _buildLevelButton('Muy alto', Colors.red, () => _record(title, 'Muy alto')),
        ],
      ),
    );
  }

  Widget _buildLevelButton(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
      ),
    );
  }

  Widget _buildDropdownArea() {
    return _buildQuestionContainer(
      title: 'Área de trabajo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Seleccione el área a la que pertenece:', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.apartment),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            items: globalCompanyAreas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
            onChanged: (val) { if (val != null) setState(() => _responses['Área'] = val); },
            hint: const Text('Seleccionar área'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _responses['Área'] == null ? null : _nextPage,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildDropdownAntiguedad() {
    return _buildQuestionContainer(
      title: 'Antigüedad en la empresa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('¿Cuánto tiempo lleva trabajando en la empresa?', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.date_range),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
            items: const [DropdownMenuItem(value: '1', child: Text('Menos de 1 año')), DropdownMenuItem(value: '2', child: Text('1 a 3 años'))],
            onChanged: (val) { if (val != null) setState(() => _responses['Antigüedad'] = val); },
            hint: const Text('Seleccionar'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _responses['Antigüedad'] == null ? null : _nextPage,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildGridMejoras() {
    return _buildQuestionContainer(
      title: 'Tipo de mejora sugerida',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Seleccione una opción:', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildMejoraOption('Carga laboral', Icons.work),
                _buildMejoraOption('Comunicación', Icons.chat),
                _buildMejoraOption('Clima laboral', Icons.favorite),
                _buildMejoraOption('Seguridad', Icons.health_and_safety),
                _buildMejoraOption('Capacitaciones', Icons.school),
                _buildMejoraOption('Infraestructura', Icons.business),
                _buildMejoraOption('Beneficios', Icons.card_giftcard),
                _buildMejoraOption('Liderazgo', Icons.person),
                _buildMejoraOption('Otro', Icons.add_circle),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selectedMejoras.isEmpty ? null : _nextPage,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildMejoraOption(String label, IconData icon) {
    bool isSel = _selectedMejoras.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSel) _selectedMejoras.remove(label);
          else _selectedMejoras.add(label);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSel ? Colors.deepPurpleAccent.withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSel ? Colors.deepPurpleAccent : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSel ? Colors.deepPurpleAccent : Colors.grey),
            const SizedBox(width: 4),
            Expanded(child: Text(label, style: TextStyle(fontSize: 10, color: isSel ? Colors.deepPurpleAccent : Colors.black87))),
            Checkbox(
              value: isSel,
              onChanged: (v) {
                setState(() {
                  if (v == true) _selectedMejoras.add(label);
                  else _selectedMejoras.remove(label);
                });
              },
              activeColor: Colors.deepPurpleAccent,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridBeneficios() {
    List<String> opciones = [
      'Menor estrés laboral', 'Mayor motivación',
      'Mayor productividad', 'Menor rotación de personal',
      'Mejor comunicación', 'Otro',
      'Mejor clima laboral'
    ];
    return _buildQuestionContainer(
      title: 'Beneficio esperado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('¿Qué resultados cree que generaría esta mejora?', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: opciones.map((opt) {
                bool isSel = _selectedBeneficios.contains(opt);
                return CheckboxListTile(
                  title: Text(opt, style: const TextStyle(fontSize: 14)),
                  value: isSel,
                  activeColor: Colors.deepPurpleAccent,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) _selectedBeneficios.add(opt);
                      else _selectedBeneficios.remove(opt);
                    });
                  },
                );
              }).toList(),
            ),
          ),
          ElevatedButton(
            onPressed: _selectedBeneficios.isEmpty ? null : _nextPage,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildTextQuestion(String title, String hint) {
    return _buildQuestionContainer(
      title: title,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: (val) => setState(() => _responses[title] = val),
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_responses[title] ?? '').trim().isEmpty ? null : _nextPage,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Siguiente', style: TextStyle(fontSize: 18, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSugerencias() {
    return _buildQuestionContainer(
      title: 'Comentarios adicionales',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Desea agregar alguna recomendación adicional?', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              onChanged: (val) => _responses['Sugerencias adicionales'] = val,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Escribe aquí tus comentarios...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.send_rounded, color: Colors.deepPurpleAccent, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Tu opinión es muy importante.\nGracias por ayudarnos a mejorar el ambiente laboral para todos.', style: TextStyle(fontSize: 12, color: Colors.deepPurpleAccent))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () async {
                  setState(() => _isSubmitting = true);
                  String result = await submitAnonymousReport('Sugerencias y Mejoras', _responses);
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                    if (result == 'ok') {
                      showSuccessDialog(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar el reporte: $result')));
                    }
                  }
                },
                icon: _isSubmitting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.psychology),
                label: Text(_isSubmitting ? 'Enviando...' : 'Enviar sugerencia confidencial', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
