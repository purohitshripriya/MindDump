import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'services/app_storage.dart';
import 'services/thought_analyzer.dart';

void main() {
  runApp(const MindDumpApp());
}

class MindDumpApp extends StatelessWidget {
  const MindDumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF9B8CFF);
    return MaterialApp(
      title: 'MindDump',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090B17),
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF15182A),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF252941),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          bodyMedium: TextStyle(color: Color(0xFFA8ADC3), height: 1.5),
        ),
      ),
      home: const MindDumpShell(),
    );
  }
}

class MindDumpShell extends StatefulWidget {
  const MindDumpShell({super.key});

  @override
  State<MindDumpShell> createState() => _MindDumpShellState();
}

class _MindDumpShellState extends State<MindDumpShell> {
  final _storage = AppStorage();
  List<ThoughtTask> _tasks = [];
  List<ThoughtDump> _history = [];
  ThoughtDump? _latestDump;
  int _selectedTab = 0;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final tasks = await _storage.loadTasks();
      final history = await _storage.loadHistory();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _history = history;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Your saved data could not be opened. Please try again.';
      });
      _showMessage('Could not load saved data: $error');
    }
  }

  Future<void> _analyze(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _showMessage('Write a thought first, and we’ll help sort it out.');
      return;
    }
    if (trimmed.length > 5000) {
      _showMessage('Keep each brain dump under 5,000 characters.');
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final analysis = ThoughtAnalyzer.analyze(trimmed);
      final now = DateTime.now();
      final dump = ThoughtDump(
        id: now.microsecondsSinceEpoch.toString(),
        text: trimmed,
        createdAt: now,
        thoughts: analysis.thoughts,
        tinyStep: analysis.tinyStep,
      );
      final knownTaskTitles = _tasks.map((task) => task.title.toLowerCase()).toSet();
      final newTasks = analysis.tasks
          .where((task) => !knownTaskTitles.contains(task.title.toLowerCase()))
          .toList();
      final updatedTasks = [...newTasks, ..._tasks];
      final updatedHistory = [dump, ..._history];

      setState(() {
        _latestDump = dump;
        _tasks = updatedTasks;
        _history = updatedHistory;
        _isAnalyzing = false;
      });
      await Future.wait([
        _storage.saveTasks(updatedTasks),
        _storage.saveHistory(updatedHistory),
      ]);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showMessage('We couldn’t save this brain dump: $error');
    }
  }

  Future<void> _saveTasks(List<ThoughtTask> tasks) async {
    setState(() => _tasks = tasks);
    try {
      await _storage.saveTasks(tasks);
    } catch (error) {
      if (mounted) _showMessage('Could not save your task changes: $error');
    }
  }

  Future<void> _saveHistory(List<ThoughtDump> history) async {
    setState(() => _history = history);
    try {
      await _storage.saveHistory(history);
    } catch (error) {
      if (mounted) _showMessage('Could not save your history changes: $error');
    }
  }

  Future<void> _editTask([ThoughtTask? existing]) async {
    final result = await showDialog<ThoughtTask>(
      context: context,
      builder: (context) => TaskEditorDialog(task: existing),
    );
    if (result == null || !mounted) return;
    final tasks = [..._tasks];
    final index = tasks.indexWhere((task) => task.id == result.id);
    if (index == -1) {
      tasks.insert(0, result);
    } else {
      tasks[index] = result;
    }
    await _saveTasks(tasks);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onHome: () => setState(() => _selectedTab = 0),
                  taskCount: _tasks.where((task) => !task.isComplete).length,
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.lavender),
                        )
                      : _loadError != null
                          ? _LoadError(onRetry: _loadData)
                          : IndexedStack(
                              index: _selectedTab,
                              children: [
                                HomePage(
                                  dump: _latestDump,
                                  isAnalyzing: _isAnalyzing,
                                  onAnalyze: _analyze,
                                  onGoToTasks: () => setState(() => _selectedTab = 1),
                                ),
                                TasksPage(
                                  tasks: _tasks,
                                  onTasksChanged: _saveTasks,
                                  onEdit: _editTask,
                                  onAdd: () => _editTask(),
                                ),
                                InsightsPage(tasks: _tasks, history: _history),
                                HistoryPage(
                                  history: _history,
                                  onDelete: (dump) => _saveHistory(
                                    _history.where((item) => item.id != dump.id).toList(),
                                  ),
                                  onOpen: (dump) {
                                    setState(() {
                                      _latestDump = dump;
                                      _selectedTab = 0;
                                    });
                                  },
                                ),
                              ],
                            ),
                ),
                _BottomNavigation(
                  selectedIndex: _selectedTab,
                  onSelected: (index) => setState(() => _selectedTab = index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppColors {
  static const navy = Color(0xFF090B17);
  static const panel = Color(0xCC171A2D);
  static const panelBorder = Color(0xFF292D46);
  static const lavender = Color(0xFFB8A7FF);
  static const violet = Color(0xFF8A71F6);
  static const muted = Color(0xFF9CA2BA);
  static const mint = Color(0xFF73E0C1);
}

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF101127), AppColors.navy, Color(0xFF0D0E1D)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            top: -190,
            right: -110,
            child: _BlurGlow(color: const Color(0xFF795BDF).withValues(alpha: .15)),
          ),
          Positioned(
            bottom: 60,
            left: -170,
            child: _BlurGlow(color: const Color(0xFF5C65C8).withValues(alpha: .10)),
          ),
        ],
      ),
    );
  }
}

class _BlurGlow extends StatelessWidget {
  const _BlurGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 380,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 110, spreadRadius: 35)],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onHome, required this.taskCount});

  final VoidCallback onHome;
  final int taskCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      child: Row(
        children: [
          InkWell(
            onTap: onHome,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA99AFF), Color(0xFF755CE5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: .25),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.blur_on_rounded, color: Colors.white, size: 23),
                ),
                const SizedBox(width: 11),
                const Text(
                  'minddump',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.5),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .045),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.mint),
                const SizedBox(width: 6),
                Text(
                  '$taskCount open',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFC9CBE0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.checklist_rounded, 'Tasks'),
    (Icons.auto_awesome_rounded, 'Insights'),
    (Icons.history_rounded, 'History'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xE817192B),
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .24),
                  blurRadius: 24,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_items.length, (index) {
                final selected = index == selectedIndex;
                final (icon, label) = _items[index];
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: label,
                    child: InkWell(
                      onTap: () => onSelected(index),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [
                                    AppColors.violet.withValues(alpha: .3),
                                    AppColors.lavender.withValues(alpha: .12),
                                  ],
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 19,
                              color: selected ? AppColors.lavender : AppColors.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected ? Colors.white : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    required this.dump,
    required this.isAnalyzing,
    required this.onAnalyze,
    required this.onGoToTasks,
    super.key,
  });

  final ThoughtDump? dump;
  final bool isAnalyzing;
  final ValueChanged<String> onAnalyze;
  final VoidCallback onGoToTasks;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();

  static const _sampleThought =
      'I have to finish the project proposal today. I feel a little overwhelmed by everything on my plate. '
      'What if we created a calmer way for teams to share ideas? Remember to call Maya about the weekend.';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 760;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHero(wide: wide),
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: _inputCard()),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: _promptCard()),
                      ],
                    )
                  else ...[
                    _inputCard(),
                    const SizedBox(height: 14),
                    _promptCard(),
                  ],
                  if (widget.dump != null) ...[
                    const SizedBox(height: 24),
                    _ResultsSection(
                      dump: widget.dump!,
                      onGoToTasks: widget.onGoToTasks,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _inputCard() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppColors.lavender, size: 19),
              ),
              const SizedBox(width: 10),
              const Text('Your brain dump', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${_controller.text.length}/5000',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 8,
            maxLength: 5000,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Let it all out. The tasks, the ideas, the “don’t forgets”…',
              hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: .75), height: 1.5),
              filled: true,
              fillColor: Colors.black.withValues(alpha: .16),
              counterText: '',
              contentPadding: const EdgeInsets.all(15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: .055)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: AppColors.lavender.withValues(alpha: .6)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.isAnalyzing ? null : () => widget.onAnalyze(_controller.text),
              icon: widget.isAnalyzing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(widget.isAnalyzing ? 'Finding your clarity…' : 'Find my clarity'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8872EF),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF6556B5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 9),
          const Center(
            child: Text(
              'Your thoughts stay on this device · Local analysis',
              style: TextStyle(fontSize: 10, color: Color(0xFF858BA5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _promptCard() {
    const prompts = [
      ('What’s taking up the most space in my mind?', Icons.cloud_outlined),
      ('What do I need to remember today?', Icons.today_outlined),
      ('Is there an idea I keep coming back to?', Icons.lightbulb_outline_rounded),
    ];
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Need a starting point?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('A little prompt can open the floodgates.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 14),
          ...prompts.map(
            (prompt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  _controller.text = prompt.$1;
                  _controller.selection = TextSelection.collapsed(
                    offset: _controller.text.length,
                  );
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .035),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withValues(alpha: .055)),
                  ),
                  child: Row(
                    children: [
                      Icon(prompt.$2, size: 16, color: AppColors.lavender),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          prompt.$1,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFD4D5E4)),
                        ),
                      ),
                      const Icon(Icons.add_rounded, size: 16, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          OutlinedButton.icon(
            onPressed: () {
              _controller.text = _sampleThought;
              setState(() {});
            },
            icon: const Icon(Icons.auto_awesome, size: 15),
            label: const Text('Try a sample thought'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.lavender,
              side: BorderSide(color: AppColors.lavender.withValues(alpha: .3)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.violet.withValues(alpha: .18)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.blur_on_rounded, size: 13, color: AppColors.lavender),
                    SizedBox(width: 6),
                    Text(
                      'A LITTLE SPACE TO THINK',
                      style: TextStyle(fontSize: 9, letterSpacing: 1, color: AppColors.lavender),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Let it out.\nFind your clarity.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: wide ? 34 : 29,
                    ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Untangle what’s on your mind, one thought at a time.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const MindOrb(size: 110),
      ],
    );
  }
}

class MindOrb extends StatefulWidget {
  const MindOrb({required this.size, super.key});

  final double size;

  @override
  State<MindOrb> createState() => _MindOrbState();
}

class _MindOrbState extends State<MindOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = .96 + _controller.value * .06;
        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(widget.size),
                  painter: _OrbitPainter(phase: _controller.value),
                ),
                Container(
                  width: widget.size * .67,
                  height: widget.size * .67,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFC3B5FF), Color(0xFF8871EE), Color(0xFF5348AA)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: .38 + _controller.value * .12),
                        blurRadius: 34,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: const Color(0xFF5F85E8).withValues(alpha: .22),
                        blurRadius: 55,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology_alt_rounded,
                    size: widget.size * .34,
                    color: Colors.white.withValues(alpha: .94),
                  ),
                ),
                Positioned(
                  top: widget.size * .18,
                  right: widget.size * .18,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE7DFFF),
                      boxShadow: [BoxShadow(color: AppColors.lavender, blurRadius: 12)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.lavender.withValues(alpha: .28);
    canvas.drawArc(rect.deflate(size.width * .08), phase * math.pi, math.pi * 1.5, false, paint);
    paint
      ..strokeWidth = .7
      ..color = const Color(0xFF6D82E7).withValues(alpha: .26);
    canvas.save();
    canvas.rotate(-.5 + phase * .15);
    canvas.drawOval(rect.deflate(size.width * .015), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => oldDelegate.phase != phase;
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.panelBorder.withValues(alpha: .85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .14),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({required this.dump, required this.onGoToTasks});

  final ThoughtDump dump;
  final VoidCallback onGoToTasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A little more clarity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Here’s what we found in your thoughts.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onGoToTasks,
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('View tasks'),
              style: TextButton.styleFrom(foregroundColor: AppColors.lavender),
            ),
          ],
        ),
        const SizedBox(height: 13),
        GlassCard(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.spa_rounded, color: AppColors.mint, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your tiny next step', style: TextStyle(fontSize: 11, color: AppColors.mint)),
                    const SizedBox(height: 3),
                    Text(dump.tinyStep, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (dump.thoughts.isEmpty)
          const _EmptyState(
            icon: Icons.notes_rounded,
            title: 'Nothing to sort just yet',
            message: 'Add a few sentences to your brain dump and try again.',
          )
        else
          ...dump.thoughts.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _ThoughtCard(thought: entry.value, index: entry.key),
                ),
              ),
      ],
    );
  }
}

class _ThoughtCard extends StatelessWidget {
  const _ThoughtCard({required this.thought, required this.index});

  final ThoughtInsight thought;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(thought.priority);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .94, end: 1),
      duration: Duration(milliseconds: 260 + index * 65),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - value) * 15), child: child),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Tag(label: thought.category, color: AppColors.lavender),
                const SizedBox(width: 7),
                _Tag(label: '${thought.priority} priority', color: color),
                if (thought.emotion != null) ...[
                  const SizedBox(width: 7),
                  _Tag(
                    label: thought.emotion!,
                    color: thought.emotion == 'Under pressure' ? const Color(0xFFFFB77A) : AppColors.mint,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 9),
            Text(thought.text, style: const TextStyle(color: Color(0xFFE5E6F0), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class TasksPage extends StatelessWidget {
  const TasksPage({
    required this.tasks,
    required this.onTasksChanged,
    required this.onEdit,
    required this.onAdd,
    super.key,
  });

  final List<ThoughtTask> tasks;
  final ValueChanged<List<ThoughtTask>> onTasksChanged;
  final ValueChanged<ThoughtTask> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.isComplete).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageHeading(
                eyebrow: 'MAKE ROOM FOR WHAT MATTERS',
                title: 'Your tasks',
                subtitle: 'A clear next step makes everything feel lighter.',
                icon: Icons.checklist_rounded,
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tasks.isEmpty ? 'A fresh start' : '$completed of ${tasks.length} complete',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            tasks.isEmpty ? 'Add one small thing to get moving.' : 'Small steps still move you forward.',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const MindOrb(size: 56),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Your list', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add task'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tasks.isEmpty)
                const _EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No tasks on your list',
                  message: 'Add a task here or find one in a brain dump.',
                )
              else
                ...tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _TaskTile(
                      task: task,
                      onToggle: () => onTasksChanged([
                        for (final item in tasks)
                          if (item.id == task.id)
                            item.copyWith(isComplete: !item.isComplete)
                          else
                            item,
                      ]),
                      onEdit: () => onEdit(task),
                      onDelete: () => onTasksChanged(
                        tasks.where((item) => item.id != task.id).toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ThoughtTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Checkbox(
            value: task.isComplete,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.violet,
            side: BorderSide(color: AppColors.muted.withValues(alpha: .7)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onToggle,
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 12,
                  color: task.isComplete ? AppColors.muted : const Color(0xFFE7E8F2),
                  decoration: task.isComplete ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
          _Tag(label: task.priority, color: priorityColor(task.priority)),
          PopupMenuButton<String>(
            tooltip: 'Task options',
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
            color: const Color(0xFF22253A),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit task')),
              PopupMenuItem(value: 'delete', child: Text('Delete task')),
            ],
          ),
        ],
      ),
    );
  }
}

class TaskEditorDialog extends StatefulWidget {
  const TaskEditorDialog({required this.task, super.key});

  final ThoughtTask? task;

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  late final TextEditingController _controller;
  late String _priority;
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task?.title ?? '');
    _priority = widget.task?.priority ?? 'Medium';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF191C30),
      title: Text(widget.task == null ? 'Add a task' : 'Edit task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 180,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What needs doing?',
              counterText: '',
              errorText: _showValidation && _controller.text.trim().isEmpty
                  ? 'Add a short task description.'
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'High', child: Text('High')),
              DropdownMenuItem(value: 'Medium', child: Text('Medium')),
              DropdownMenuItem(value: 'Low', child: Text('Low')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _priority = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final title = _controller.text.trim();
            if (title.isEmpty) {
              setState(() => _showValidation = true);
              return;
            }
            Navigator.pop(
              context,
              ThoughtTask(
                id: widget.task?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                title: title,
                priority: _priority,
                isComplete: widget.task?.isComplete ?? false,
              ),
            );
          },
          child: Text(widget.task == null ? 'Add task' : 'Save changes'),
        ),
      ],
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    required this.history,
    required this.onDelete,
    required this.onOpen,
    super.key,
  });

  final List<ThoughtDump> history;
  final ValueChanged<ThoughtDump> onDelete;
  final ValueChanged<ThoughtDump> onOpen;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.history
        .where((dump) => dump.text.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageHeading(
                eyebrow: 'YOUR THOUGHTS, KEPT CLOSE',
                title: 'Brain dump history',
                subtitle: 'Revisit a thought whenever you need a little perspective.',
                icon: Icons.history_rounded,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Search your brain dumps',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: AppColors.panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.panelBorder.withValues(alpha: .8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.panelBorder.withValues(alpha: .8)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (results.isEmpty)
                _EmptyState(
                  icon: _query.isEmpty ? Icons.hourglass_empty_rounded : Icons.search_off_rounded,
                  title: _query.isEmpty ? 'Your story starts here' : 'No matching brain dumps',
                  message: _query.isEmpty
                      ? 'Your saved brain dumps will show up here.'
                      : 'Try a different search term.',
                )
              else
                ...results.map(
                  (dump) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryTile(
                      dump: dump,
                      onOpen: () => widget.onOpen(dump),
                      onDelete: () => _confirmDelete(context, dump),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ThoughtDump dump) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF191C30),
        title: const Text('Delete this brain dump?'),
        content: const Text('This removes it from your saved history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete(dump);
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.dump,
    required this.onOpen,
    required this.onDelete,
  });

  final ThoughtDump dump;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.violet.withValues(alpha: .15),
              ),
              child: const Icon(Icons.notes_rounded, color: AppColors.lavender, size: 18),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dump.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFE5E6F0), fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_formatDate(dump.createdAt)} · ${dump.thoughts.length} thoughts organized',
                    style: const TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete brain dump',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class InsightsPage extends StatelessWidget {
  const InsightsPage({required this.tasks, required this.history, super.key});

  final List<ThoughtTask> tasks;
  final List<ThoughtDump> history;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.isComplete).length;
    final thoughtsProcessed = history.fold<int>(
      0,
      (total, dump) => total + dump.thoughts.length,
    );
    final completionRate = tasks.isEmpty ? 0 : (completed / tasks.length * 100).round();
    final highPriority = tasks.where((task) => task.priority == 'High' && !task.isComplete).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageHeading(
                eyebrow: 'A GENTLER KIND OF PROGRESS',
                title: 'Your insights',
                subtitle: 'A small look at how you’re making space for yourself.',
                icon: Icons.auto_awesome_rounded,
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('You’re showing up for yourself.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 7),
                          Text(
                            history.isEmpty
                                ? 'Start with one brain dump. Your progress will take shape here.'
                                : 'You’ve made space for $thoughtsProcessed ${thoughtsProcessed == 1 ? 'thought' : 'thoughts'} across ${history.length} ${history.length == 1 ? 'session' : 'sessions'}.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const MindOrb(size: 76),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 600 ? 3 : 2;
                  const spacing = 10.0;
                  final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                  final stats = [
                    _InsightStat(
                      icon: Icons.notes_rounded,
                      label: 'Thoughts processed',
                      value: '$thoughtsProcessed',
                      color: AppColors.lavender,
                      detail: '${history.length} brain dumps',
                    ),
                    _InsightStat(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Tasks completed',
                      value: '$completed',
                      color: AppColors.mint,
                      detail: '${tasks.length} total tasks',
                    ),
                    _InsightStat(
                      icon: Icons.trending_up_rounded,
                      label: 'Completion rate',
                      value: '$completionRate%',
                      color: const Color(0xFFF4BB77),
                      detail: tasks.isEmpty ? 'No tasks yet' : '$highPriority high priority left',
                    ),
                  ];
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: stats
                        .map((stat) => SizedBox(width: width, child: stat))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 17),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: AppColors.lavender, size: 19),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your mind, your device', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          SizedBox(height: 5),
                          Text(
                            'MindDump uses simple on-device text patterns to organize thoughts. Your data is saved locally and never sent to an AI service.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightStat extends StatelessWidget {
  const _InsightStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -.8)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFD7D8E6))),
          const SizedBox(height: 5),
          Text(detail, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.1,
                  color: AppColors.lavender,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 29)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [AppColors.violet.withValues(alpha: .3), AppColors.lavender.withValues(alpha: .08)],
            ),
            border: Border.all(color: AppColors.lavender.withValues(alpha: .14)),
          ),
          child: Icon(icon, color: AppColors.lavender, size: 21),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.lavender.withValues(alpha: .8)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 5),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.lavender, size: 32),
            const SizedBox(height: 12),
            const Text('Could not load your local data', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Your saved data has not been changed. Try again in a moment.'),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

Color priorityColor(String priority) {
  return switch (priority) {
    'High' => const Color(0xFFFF9C9C),
    'Medium' => const Color(0xFFF4BB77),
    _ => const Color(0xFF9FBDFF),
  };
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = date.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
