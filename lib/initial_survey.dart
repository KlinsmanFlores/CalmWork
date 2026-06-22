import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

// Opciones generales
const List<String> generalOptions = [
  'Nunca',
  'Sólo alguna vez',
  'Algunas veces',
  'Muchas veces',
  'Siempre',
];

// Opciones Apartado 3
const List<String> preocupadoOptions = [
  'Nada preocupado',
  'Poco preocupado',
  'Más o menos preocupado',
  'Bastante preocupado',
  'Muy preocupado',
];

const List<String> q31Options = [
  'Ninguna o casi ninguna',
  'Sólo tareas muy puntuales',
  'Más o menos una cuarta parte',
  'Aproximadamente la mitad',
  'Soy responsable de la mayor parte',
];

class SurveyQuestion {
  final int id;
  final String apartado;
  final String subtitle;
  final String text;
  final List<String> options;
  final bool inverted;
  final IconData icon;

  SurveyQuestion({
    required this.id,
    required this.apartado,
    required this.subtitle,
    required this.text,
    this.options = generalOptions,
    this.inverted = false,
    required this.icon,
  });
}

final List<SurveyQuestion> surveyQuestions = [
  // Apartado 1: Exigencias Psicológicas
  SurveyQuestion(id: 1, apartado: 'Apartado 1', subtitle: 'Exigencias del Trabajo', icon: Icons.psychology_alt, text: '¿Tienes que trabajar muy rápido?'),
  SurveyQuestion(id: 2, apartado: 'Apartado 1', subtitle: 'Exigencias del Trabajo', icon: Icons.psychology_alt, text: '¿La distribución de tareas es irregular y provoca que se te acumule el trabajo?'),
  SurveyQuestion(id: 3, apartado: 'Apartado 1', subtitle: 'Exigencias del Trabajo', icon: Icons.psychology_alt, text: '¿Tienes tiempo de llevar al día tu trabajo?', inverted: true),
  SurveyQuestion(id: 4, apartado: 'Apartado 1', subtitle: 'Exigencias del Trabajo', icon: Icons.psychology_alt, text: '¿Te cuesta olvidar los problemas del trabajo?'),
  SurveyQuestion(id: 5, apartado: 'Apartado 1', subtitle: 'Exigencias del Trabajo', icon: Icons.psychology_alt, text: '¿Tu trabajo, en general, es desgastador emocionalmente?'),
  SurveyQuestion(id: 6, apartado: 'Apartado 1', subtitle: 'Exigencias del Trabajo', icon: Icons.psychology_alt, text: '¿Tu trabajo requiere que escondas tus emociones?'),

  // Apartado 2: Trabajo Activo
  SurveyQuestion(id: 7, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: '¿Tienes influencia sobre la cantidad de trabajo que se te asigna?'),
  SurveyQuestion(id: 8, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: '¿Se tiene en cuenta tu opinión cuando se te asignan tareas?'),
  SurveyQuestion(id: 9, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: '¿Tienes influencia sobre el orden en el que realizas las tareas?'),
  SurveyQuestion(id: 10, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: '¿Puedes decidir cuándo haces un descanso?'),
  SurveyQuestion(id: 11, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: 'Si tienes algún asunto personal o familiar ¿puedes dejar tu puesto de trabajo al menos una hora sin pedir permiso especial?'),
  SurveyQuestion(id: 12, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: '¿Tu trabajo requiere que tengas iniciativa?'),
  SurveyQuestion(id: 13, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: '¿Tu trabajo permite que aprendas cosas nuevas?'),
  SurveyQuestion(id: 14, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: '¿Te sientes comprometido con tu profesión?'),
  SurveyQuestion(id: 15, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: '¿Tienen sentido tus tareas?'),
  SurveyQuestion(id: 16, apartado: 'Apartado 2', subtitle: 'Trabajo Activo y Desarrollo', icon: Icons.lightbulb_outline, text: '¿Hablas con entusiasmo de tu empresa a otras personas?'),

  // Apartado 3: Inseguridad
  SurveyQuestion(id: 17, apartado: 'Apartado 3', subtitle: 'Preocupaciones e Inseguridad', icon: Icons.security_update_warning_outlined, text: 'En estos momentos, ¿estás preocupado/a por lo difícil que sería encontrar otro trabajo en el caso de que te quedaras en paro?', options: preocupadoOptions),
  SurveyQuestion(id: 18, apartado: 'Apartado 3', subtitle: 'Preocupaciones e Inseguridad', icon: Icons.security_update_warning_outlined, text: 'En estos momentos, ¿estás preocupado/a por si te cambian de tareas contra tu voluntad?', options: preocupadoOptions),
  SurveyQuestion(id: 19, apartado: 'Apartado 3', subtitle: 'Preocupaciones e Inseguridad', icon: Icons.security_update_warning_outlined, text: 'En estos momentos, ¿estás preocupado/a por si te cambian el horario (turno, días) contra tu voluntad?', options: preocupadoOptions),
  SurveyQuestion(id: 20, apartado: 'Apartado 3', subtitle: 'Preocupaciones e Inseguridad', icon: Icons.security_update_warning_outlined, text: 'En estos momentos, ¿estás preocupado/a por si te varían el salario (bajada, no actualización)?', options: preocupadoOptions),

  // Apartado 4: Apoyo Social y Calidad de Liderazgo
  SurveyQuestion(id: 21, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: '¿Sabes exactamente qué margen de autonomía tienes en tu trabajo?'),
  SurveyQuestion(id: 22, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: '¿Sabes exactamente qué tareas son de tu responsabilidad?'),
  SurveyQuestion(id: 23, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: '¿En tu empresa se te informa con antelación de cambios que afectan tu futuro?'),
  SurveyQuestion(id: 24, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: '¿Recibes toda la información que necesitas para realizar bien tu trabajo?'),
  SurveyQuestion(id: 25, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: '¿Recibes ayuda y apoyo de tus compañeras o compañeros?'),
  SurveyQuestion(id: 26, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: '¿Recibes ayuda y apoyo de tu inmediato o inmediata superior?'),
  SurveyQuestion(id: 27, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: '¿Tu puesto de trabajo se encuentra aislado del de tus compañeros/as?', inverted: true),
  SurveyQuestion(id: 28, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: 'En el trabajo, ¿sientes que formas parte de un grupo?'),
  SurveyQuestion(id: 29, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: '¿Tus actuales jefes inmediatos planifican bien el trabajo?'),
  SurveyQuestion(id: 30, apartado: 'Apartado 4', subtitle: 'Apoyo y Liderazgo', icon: Icons.groups_outlined, text: '¿Tus actuales jefes inmediatos se comunican bien con el equipo?'),

  // Apartado 5: Doble Presencia
  SurveyQuestion(id: 31, apartado: 'Apartado 5', subtitle: 'Equilibrio Trabajo y Familia', icon: Icons.balance, text: '¿Qué parte del trabajo familiar y doméstico haces tú?', options: q31Options),
  SurveyQuestion(id: 32, apartado: 'Apartado 5', subtitle: 'Equilibrio Trabajo y Familia', icon: Icons.balance, text: 'Si faltas algún día de casa, ¿las tareas domésticas se quedan sin hacer?'),
  SurveyQuestion(id: 33, apartado: 'Apartado 5', subtitle: 'Equilibrio Trabajo y Familia', icon: Icons.balance, text: 'Cuando estás en la empresa ¿piensas en las tareas domésticas y familiares?'),
  SurveyQuestion(id: 34, apartado: 'Apartado 5', subtitle: 'Equilibrio Trabajo y Familia', icon: Icons.balance, text: '¿Hay momentos en los que necesitarías estar en la empresa y en casa a la vez?'),

  // Apartado 6: Estima
  SurveyQuestion(id: 35, apartado: 'Apartado 6', subtitle: 'Estima y Reconocimiento', icon: Icons.verified_user_outlined, text: 'Mis superiores me dan el reconocimiento que merezco'),
  SurveyQuestion(id: 36, apartado: 'Apartado 6', subtitle: 'Estima y Reconocimiento', icon: Icons.verified_user_outlined, text: 'En las situaciones difíciles en el trabajo recibo el apoyo necesario'),
  SurveyQuestion(id: 37, apartado: 'Apartado 6', subtitle: 'Estima y Reconocimiento', icon: Icons.verified_user_outlined, text: 'En mi trabajo me tratan injustamente', inverted: true),
  SurveyQuestion(id: 38, apartado: 'Apartado 6', subtitle: 'Estima y Reconocimiento', icon: Icons.verified_user_outlined, text: 'Pensando en mi esfuerzo, el reconocimiento que recibo me parece adecuado'),
];


class InitialSurveyScreen extends StatefulWidget {
  const InitialSurveyScreen({super.key});

  @override
  State<InitialSurveyScreen> createState() => _InitialSurveyScreenState();
}

class _InitialSurveyScreenState extends State<InitialSurveyScreen> {
  int _currentPage = 0;
  bool _isSubmitting = false;
  final Map<int, int> _answers = {};

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  void _onAnswered(int value) async {
    final question = surveyQuestions[_currentPage];
    
    setState(() {
      if (question.inverted) {
        _answers[question.id] = 4 - value;
      } else {
        _answers[question.id] = value;
      }
    });

    // Pequeña pausa para que se vea el glow de selección
    await Future.delayed(const Duration(milliseconds: 350));
    
    if (mounted) {
      if (_currentPage < surveyQuestions.length - 1) {
        setState(() {
          _currentPage++;
        });
      } else {
        _submitSurvey();
      }
    }
  }

  Future<void> _submitSurvey() async {
    if (_answers.length < surveyQuestions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, responde todas las preguntas.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      int dim1 = _calcSum(1, 6);
      int dim2 = _calcSum(7, 16);
      int dim3 = _calcSum(17, 20);
      int dim4 = _calcSum(21, 30);
      int dim5 = _calcSum(31, 34);
      int dim6 = _calcSum(35, 38);

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.schema('calmwork').from('initial_survey_results').insert({
          'employee_id': user.id,
          'dim1_score': dim1,
          'dim2_score': dim2,
          'dim3_score': dim3,
          'dim4_score': dim4,
          'dim5_score': dim5,
          'dim6_score': dim6,
        });

        await Supabase.instance.client.schema('calmwork').from('employees').upsert({
          'id': user.id,
          'has_completed_initial_survey': true
        });
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigator()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  int _calcSum(int start, int end) {
    int sum = 0;
    for (int i = start; i <= end; i++) {
      sum += _answers[i] ?? 0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = surveyQuestions[_currentPage];
    final progress = (_currentPage + 1) / surveyQuestions.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F4F8), Colors.white],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header animado
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(currentQ.icon, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentQ.apartado,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                    ),
                                    Text(
                                      currentQ.subtitle,
                                      style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w800),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text('${_currentPage + 1} / ${surveyQuestions.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        Container(height: 8, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4))),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          height: 8,
                          width: (MediaQuery.of(context).size.width * progress - 48) > 0 ? (MediaQuery.of(context).size.width * progress - 48) : 0,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primaryLight, AppColors.primary]),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Reemplazamos AnimatedSwitcher por una transición tipo Typeform (Slide suave horizontal)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  reverseDuration: const Duration(milliseconds: 400),
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final isEntering = child.key == ValueKey<int>(_currentPage);
                    
                    // Retrasamos el fade-in del widget nuevo para que el viejo tenga tiempo de irse
                    // y no se vean sobrepuestos ni aparezca "de golpe".
                    final fadeAnimation = CurvedAnimation(
                      parent: animation,
                      curve: isEntering ? const Interval(0.3, 1.0, curve: Curves.easeIn) : const Interval(0.4, 1.0, curve: Curves.easeOut),
                    );

                    return ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)
                      ),
                      child: FadeTransition(
                        opacity: fadeAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: _QuestionSlide(
                    key: ValueKey<int>(_currentPage),
                    question: currentQ,
                    selectedValue: currentQ.inverted && _answers.containsKey(currentQ.id) ? 4 - _answers[currentQ.id]! : _answers[currentQ.id],
                    onSelect: _onAnswered,
                  ),
                ),
              ),

              // Controles Inferiores (Eliminamos botón Continuar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _currentPage > 0 ? _previousPage : null,
                      icon: Icon(Icons.arrow_back_ios_new, color: _currentPage > 0 ? AppColors.textSecondary : Colors.transparent),
                    ),
                    if (_isSubmitting)
                      const CircularProgressIndicator(color: AppColors.primary)
                    else 
                      const SizedBox(width: 48), // Espaciador para centrar
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionSlide extends StatelessWidget {
  final SurveyQuestion question;
  final int? selectedValue;
  final Function(int) onSelect;

  const _QuestionSlide({
    super.key,
    required this.question,
    required this.selectedValue,
    required this.onSelect,
  });

  IconData _getIconForOption(int index, String text) {
    text = text.toLowerCase();
    if (text.contains('nunca') || text.contains('ninguna') || text.contains('nada')) return Icons.close;
    if (text.contains('siempre') || text.contains('principal') || text.contains('muy')) return Icons.done_all;
    if (text.contains('alguna') || text.contains('puntuales') || text.contains('poco')) return Icons.keyboard_arrow_right;
    if (text.contains('muchas') || text.contains('mitad') || text.contains('bastante')) return Icons.keyboard_double_arrow_right;
    return Icons.drag_handle; // neutral
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Text(
              question.text,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          ...List.generate(question.options.length, (index) {
            final isSelected = selectedValue == index;
            final optionText = question.options[index];
            return GestureDetector(
              onTap: () => onSelect(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200, width: 2),
                  boxShadow: isSelected
                      ? [BoxShadow(color: AppColors.primaryLight.withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 4))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconForOption(index, optionText),
                      color: isSelected ? Colors.white : AppColors.primaryLight,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        optionText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Colors.white)
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
