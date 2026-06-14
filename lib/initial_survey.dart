import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class InitialSurveyScreen extends StatefulWidget {
  const InitialSurveyScreen({super.key});

  @override
  State<InitialSurveyScreen> createState() => _InitialSurveyScreenState();
}

class _InitialSurveyScreenState extends State<InitialSurveyScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSubmitting = false;

  // Respuestas del usuario (índice de pregunta a valor)
  // Las preguntas van del 1 al 38 para coincidir con la nomenclatura del formulario.
  Map<int, int> _answers = {};

  // Opciones generales
  final List<String> _generalOptions = [
    'Nunca', // 0
    'Sólo alguna vez', // 1
    'Algunas veces', // 2
    'Muchas veces', // 3
    'Siempre', // 4
  ];

  // Opciones Apartado 3
  final List<String> _preocupadoOptions = [
    'Nada preocupado', // 0
    'Poco preocupado', // 1
    'Más o menos preocupado', // 2
    'Bastante preocupado', // 3
    'Muy preocupado', // 4
  ];

  void _nextPage() {
    if (_currentPage < 5) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submitSurvey();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _submitSurvey() async {
    // Validar que estén todas las 38 preguntas respondidas
    if (_answers.length < 38) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, responde todas las preguntas.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Calcular puntajes por dimensión
      int dim1 = _calcSum(1, 6);
      int dim2 = _calcSum(7, 16);
      int dim3 = _calcSum(17, 20);
      int dim4 = _calcSum(21, 30);
      int dim5 = _calcSum(31, 34);
      int dim6 = _calcSum(35, 38);

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Guardar resultados en initial_survey_results
        await Supabase.instance.client.schema('calmwork').from('initial_survey_results').insert({
          'employee_id': user.id,
          'dim1_score': dim1,
          'dim2_score': dim2,
          'dim3_score': dim3,
          'dim4_score': dim4,
          'dim5_score': dim5,
          'dim6_score': dim6,
        });

        // Marcar al empleado como completado (y crearlo si es nuevo)
        await Supabase.instance.client
            .schema('calmwork')
            .from('employees')
            .upsert({
              'id': user.id,
              'has_completed_initial_survey': true
            });
      }

      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainNavigator()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al enviar: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  int _calcSum(int start, int end) {
    int sum = 0;
    for (int i = start; i <= end; i++) {
      sum += _answers[i] ?? 0;
    }
    return sum;
  }

  void _onAnswered(int questionIndex, int value, bool inverted) {
    setState(() {
      if (inverted) {
        // Si es invertida, el valor visual (0,1,2,3,4) ya es el que corresponde porque
        // las opciones siempre se muestran de "Nunca" a "Siempre".
        // Espera, si es invertida: Siempre=0, Nunca=4.
        // Si el usuario elige "Siempre" (index 4 en la lista normal), debemos guardar 0.
        // Por tanto, value a guardar = 4 - index.
        _answers[questionIndex] = 4 - value;
      } else {
        _answers[questionIndex] = value;
      }
    });
  }

  bool _canProceed() {
    int start = 1;
    int end = 6;
    if (_currentPage == 1) { start = 7; end = 16; }
    else if (_currentPage == 2) { start = 17; end = 20; }
    else if (_currentPage == 3) { start = 21; end = 30; }
    else if (_currentPage == 4) { start = 31; end = 34; }
    else if (_currentPage == 5) { start = 35; end = 38; }

    for (int i = start; i <= end; i++) {
      if (!_answers.containsKey(i)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cuestionario Inicial',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ProgressBar
          LinearProgressIndicator(
            value: (_currentPage + 1) / 6,
            backgroundColor: AppColors.primaryLight.withOpacity(0.3),
            color: AppColors.primary,
            minHeight: 8,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildApartado1(),
                _buildApartado2(),
                _buildApartado3(),
                _buildApartado4(),
                _buildApartado5(),
                _buildApartado6(),
              ],
            ),
          ),
          // Botones de Navegación
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _isSubmitting ? null : _previousPage,
                    child: const Text('Atrás',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  const SizedBox(width: 60),
                ElevatedButton(
                  onPressed: (_isSubmitting || !_canProceed()) ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(_currentPage == 5 ? 'Finalizar' : 'Siguiente'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Helpers para construir las preguntas
  Widget _buildQuestionCard(int index, String question,
      {bool inverted = false, List<String>? customOptions}) {
    final options = customOptions ?? _generalOptions;
    final int? currentValue = inverted && _answers.containsKey(index)
        ? 4 - _answers[index]!
        : _answers[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$index. $question',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Column(
            children: List.generate(options.length, (i) {
              // Si es la pregunta 31 (customOptions), el valor directo es 4 - i (pues las opciones van de mayor a menor en el PDF)
              // Pero manejaremos Q31 especialmente o mapearemos visualmente.
              // Para simplificar, i va de 0 a 4 visualmente (abajo a arriba o arriba a abajo).
              // En general options[0] es la opción con valor 0 (Nunca), options[4] es 4 (Siempre).
              return RadioListTile<int>(
                title: Text(options[i], style: const TextStyle(fontSize: 14)),
                value: i,
                groupValue: currentValue,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
                onChanged: (val) {
                  if (val != null) _onAnswered(index, val, inverted);
                },
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildSection(String title, String subtitle, List<Widget> questions) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ...questions,
      ],
    );
  }

  Widget _buildApartado1() {
    return _buildSection(
        'Apartado 1', 'Elige una sola respuesta para cada pregunta:', [
      _buildQuestionCard(1, '¿Tienes que trabajar muy rápido?'),
      _buildQuestionCard(2,
          '¿La distribución de tareas es irregular y provoca que se te acumule el trabajo?'),
      _buildQuestionCard(3, '¿Tienes tiempo de llevar al día tu trabajo?',
          inverted: true),
      _buildQuestionCard(4, '¿Te cuesta olvidar los problemas del trabajo?'),
      _buildQuestionCard(
          5, '¿Tu trabajo, en general, es desgastador emocionalmente?'),
      _buildQuestionCard(6, '¿Tu trabajo requiere que escondas tus emociones?'),
    ]);
  }

  Widget _buildApartado2() {
    return _buildSection(
        'Apartado 2', 'Elige una sola respuesta para cada pregunta:', [
      _buildQuestionCard(
          7, '¿Tienes influencia sobre la cantidad de trabajo que se te asigna?'),
      _buildQuestionCard(8,
          '¿Se tiene en cuenta tu opinión cuando se te asignan tareas?'),
      _buildQuestionCard(
          9, '¿Tienes influencia sobre el orden en el que realizas las tareas?'),
      _buildQuestionCard(10, '¿Puedes decidir cuándo haces un descanso?'),
      _buildQuestionCard(11,
          'Si tienes algún asunto personal o familiar ¿puedes dejar tu puesto de trabajo al menos una hora sin tener que pedir un permiso especial?'),
      _buildQuestionCard(12, '¿Tu trabajo requiere que tengas iniciativa?'),
      _buildQuestionCard(
          13, '¿Tu trabajo permite que aprendas cosas nuevas?'),
      _buildQuestionCard(14, '¿Te sientes comprometido con tu profesión?'),
      _buildQuestionCard(15, '¿Tienen sentido tus tareas?'),
      _buildQuestionCard(
          16, '¿Hablas con entusiasmo de tu empresa a otras personas?'),
    ]);
  }

  Widget _buildApartado3() {
    return _buildSection('Apartado 3',
        'En estos momentos, ¿estás preocupado/a por...', [
      _buildQuestionCard(17,
          '¿lo difícil que sería encontrar otro trabajo en el caso de que te quedaras en paro?',
          customOptions: _preocupadoOptions),
      _buildQuestionCard(18, '¿si te cambian de tareas contra tu voluntad?',
          customOptions: _preocupadoOptions),
      _buildQuestionCard(19,
          '¿si te cambian el horario (turno, días de la semana, horas) contra tu voluntad?',
          customOptions: _preocupadoOptions),
      _buildQuestionCard(20,
          '¿si te varían el salario (que no te lo actualicen, que te lo bajen, etc.)?',
          customOptions: _preocupadoOptions),
    ]);
  }

  Widget _buildApartado4() {
    return _buildSection(
        'Apartado 4', 'Elige una sola respuesta para cada pregunta:', [
      _buildQuestionCard(
          21, '¿Sabes exactamente qué margen de autonomía tienes en tu trabajo?'),
      _buildQuestionCard(
          22, '¿Sabes exactamente qué tareas son de tu responsabilidad?'),
      _buildQuestionCard(23,
          '¿En tu empresa se te informa con suficiente antelación de los cambios que pueden afectar tu futuro?'),
      _buildQuestionCard(24,
          '¿Recibes toda la información que necesitas para realizar bien tu trabajo?'),
      _buildQuestionCard(
          25, '¿Recibes ayuda y apoyo de tus compañeras o compañeros?'),
      _buildQuestionCard(
          26, '¿Recibes ayuda y apoyo de tu inmediato o inmediata superior?'),
      _buildQuestionCard(27,
          '¿Tu puesto de trabajo se encuentra aislado del de tus compañeros/as?',
          inverted: true),
      _buildQuestionCard(
          28, 'En el trabajo, ¿sientes que formas parte de un grupo?'),
      _buildQuestionCard(
          29, '¿Tus actuales jefes inmediatos planifican bien el trabajo?'),
      _buildQuestionCard(30,
          '¿Tus actuales jefes inmediatos se comunican bien con los trabajadores y trabajadoras?'),
    ]);
  }

  Widget _buildApartado5() {
    // La Q31 es especial. Valores de 0 a 4 de forma directa, la opción 4 es la principal, etc.
    final q31Options = [
      'No hago ninguna o casi ninguna de estas tareas', // 0
      'Sólo hago tareas muy puntuales', // 1
      'Hago más o menos una cuarta parte', // 2
      'Hago aproximadamente la mitad', // 3
      'Soy la/el principal responsable (la mayor parte)', // 4
    ];

    return _buildSection(
        'Apartado 5', 'De la siguiente pregunta, elige la respuesta que mejor describa tu situación:', [
      _buildQuestionCard(31, '¿Qué parte del trabajo familiar y doméstico haces tú?',
          customOptions: q31Options),
      _buildQuestionCard(32,
          'Si faltas algún día de casa, ¿las tareas domésticas que realizas se quedan sin hacer?'),
      _buildQuestionCard(33,
          'Cuando estás en la empresa ¿piensas en las tareas domésticas y familiares?'),
      _buildQuestionCard(34,
          '¿Hay momentos en los que necesitarías estar en la empresa y en casa a la vez?'),
    ]);
  }

  Widget _buildApartado6() {
    return _buildSection(
        'Apartado 6', 'Elige una sola respuesta para cada pregunta:', [
      _buildQuestionCard(35, 'Mis superiores me dan el reconocimiento que merezco'),
      _buildQuestionCard(36,
          'En las situaciones difíciles en el trabajo recibo el apoyo necesario'),
      _buildQuestionCard(37, 'En mi trabajo me tratan injustamente',
          inverted: true),
      _buildQuestionCard(38,
          'Si pienso en todo el trabajo y esfuerzo que he realizado, el reconocimiento que recibo en mi trabajo me parece adecuado'),
    ]);
  }
}
