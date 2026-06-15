import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soulsync_dairyapp/models/todo_item.dart';
import 'package:soulsync_dairyapp/services/todo_service.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';
import 'package:soulsync_dairyapp/widgets/theme_background_wrapper.dart';
import 'dart:math';

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  List<TodoItem> _todos = [];
  bool _isLoading = true;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  TodoItem? _editingTodo;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    setState(() {
      _isLoading = true;
    });

    final todos = await TodoService.getTodos();
    // Sort: incomplete first, then by creation date (newest first)
    todos.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    setState(() {
      _todos = todos;
      _isLoading = false;
    });
  }

  Future<void> _addTodo() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final newTodo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString(),
      text: text,
      createdAt: DateTime.now(),
    );

    await TodoService.addTodo(newTodo);
    _textController.clear();
    _loadTodos();
  }

  Future<void> _updateTodo(TodoItem todo, String newText) async {
    if (newText.trim().isEmpty) {
      await TodoService.deleteTodo(todo.id);
    } else {
      final updatedTodo = todo.copyWith(text: newText.trim());
      await TodoService.updateTodo(updatedTodo);
    }
    setState(() {
      _editingTodo = null;
    });
    _loadTodos();
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    await TodoService.deleteTodo(todo.id);
    _loadTodos();
  }

  Future<void> _toggleTodo(TodoItem todo) async {
    final wasCompleted = todo.isCompleted;
    await TodoService.toggleTodo(todo.id);
    _loadTodos();
    
    // Show celebration if task was just completed (not uncompleted)
    if (!wasCompleted) {
      _showCelebration();
    }
  }
  
  void _showCelebration() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      barrierDismissible: true,
      builder: (context) => const _CelebrationDialog(),
    );
  }

  Future<void> _clearCompleted() async {
    await TodoService.clearCompleted();
    _loadTodos();
  }

  void _startEditing(TodoItem todo) {
    setState(() {
      _editingTodo = todo;
      _textController.text = todo.text;
    });
    _focusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingTodo = null;
      _textController.clear();
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ThemeUtils.isDarkTheme(),
      builder: (context, snapshot) {
        final isDarkTheme = snapshot.data ?? false;
        final isLightTheme = !isDarkTheme;

        return ThemeBackgroundWrapper(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'To-Do List',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
              ),
            ),
            body: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B4C93)),
                    ),
                  )
                : Column(
                    children: [
                      // Add todo input
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isLightTheme
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isLightTheme
                                        ? const Color(0xFF6B4C93).withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _focusNode,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    decoration: TextDecoration.none,
                                    color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _editingTodo == null
                                        ? 'Add a new task...'
                                        : 'Edit task...',
                                    hintStyle: GoogleFonts.poppins(
                                      color: isLightTheme
                                          ? const Color(0xFF8B7BA6)
                                          : Colors.white.withValues(alpha: 0.6),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                  ),
                                  onSubmitted: (_) {
                                    if (_editingTodo != null) {
                                      _updateTodo(_editingTodo!, _textController.text);
                                    } else {
                                      _addTodo();
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B4C93),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6B4C93).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _editingTodo == null ? Icons.add : Icons.check,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  if (_editingTodo != null) {
                                    _updateTodo(_editingTodo!, _textController.text);
                                  } else {
                                    _addTodo();
                                  }
                                },
                              ),
                            ),
                            if (_editingTodo != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: _cancelEditing,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Todo list
                      Expanded(
                        child: _todos.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.checklist_rounded,
                                      size: 80,
                                      color: isLightTheme
                                          ? const Color(0xFF8B7BA6).withValues(alpha: 0.5)
                                          : Colors.white.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No tasks yet',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: isLightTheme
                                            ? const Color(0xFF8B7BA6)
                                            : Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add your first task above',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: isLightTheme
                                            ? const Color(0xFF8B7BA6).withValues(alpha: 0.7)
                                            : Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _todos.length,
                                itemBuilder: (context, index) {
                                  final todo = _todos[index];
                                  return _buildTodoItem(todo, isLightTheme, isDarkTheme);
                                },
                              ),
                      ),
                      // Clear completed button
                      if (_todos.any((todo) => todo.isCompleted))
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: TextButton(
                            onPressed: _clearCompleted,
                            child: Text(
                              'Clear Completed',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isLightTheme
                                    ? const Color(0xFF6B4C93)
                                    : Colors.white.withValues(alpha: 0.8),
                              ),
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

  Widget _buildTodoItem(TodoItem todo, bool isLightTheme, bool isDarkTheme) {
    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.red,
          size: 28,
        ),
      ),
      onDismissed: (_) => _deleteTodo(todo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isLightTheme
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLightTheme
                ? Colors.black.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => _toggleTodo(todo),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: todo.isCompleted
                        ? const Color(0xFF6B4C93)
                        : (isLightTheme
                            ? const Color(0xFF8B7BA6)
                            : Colors.white.withValues(alpha: 0.5)),
                    width: 2,
                  ),
                  color: todo.isCompleted ? const Color(0xFF6B4C93) : Colors.transparent,
                ),
                child: todo.isCompleted
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            // Todo text
            Expanded(
              child: GestureDetector(
                onTap: () => _startEditing(todo),
                child: Text(
                  todo.text,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                    decorationThickness: 0,
                    color: todo.isCompleted
                        ? (isLightTheme
                            ? const Color(0xFF8B7BA6)
                            : Colors.white.withValues(alpha: 0.5))
                        : (isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Celebration dialog with confetti animation
class _CelebrationDialog extends StatefulWidget {
  const _CelebrationDialog();

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    
    // Scale animation for dialog
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    
    // Confetti animation
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    // Create confetti particles
    for (int i = 0; i < 30; i++) {
      _particles.add(ConfettiParticle(
        x: _random.nextDouble(),
        y: -0.1 - _random.nextDouble() * 0.2,
        color: _getRandomColor(),
        size: 8 + _random.nextDouble() * 12,
        speed: 0.3 + _random.nextDouble() * 0.4,
        angle: _random.nextDouble() * 2 * pi,
      ));
    }
    
    _scaleController.forward();
    _confettiController.forward();
    
    // Auto-close after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Color _getRandomColor() {
    final colors = [
      const Color(0xFF6B4C93),
      const Color(0xFFE8D5FF),
      const Color(0xFFFF6B9D),
      const Color(0xFF6BC5FF),
      const Color(0xFFFFB84D),
      const Color(0xFF9B7BFF),
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, child) {
        return Stack(
          children: [
            // Confetti particles falling from top
            ..._particles.map((particle) {
              final progress = _confettiController.value;
              final newY = particle.y + (particle.speed * progress);
              final newX = particle.x + (sin(particle.angle) * progress * 0.2);
              final opacity = 1.0 - progress;
              
              if (newY > 1.2 || opacity <= 0) return const SizedBox.shrink();
              
              return Positioned(
                left: MediaQuery.of(context).size.width * newX,
                top: MediaQuery.of(context).size.height * newY,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: progress * 2 * pi,
                    child: Container(
                      width: particle.size,
                      height: particle.size,
                      decoration: BoxDecoration(
                        color: particle.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Dialog content
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isLightTheme
                          ? Colors.white
                          : const Color(0xFF2D1B3D),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Celebration emoji
                        const Text(
                          '🎉',
                          style: TextStyle(
                            fontSize: 56,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Title
                        Text(
                          'Hurray!',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                            decorationColor: Colors.transparent,
                            decorationThickness: 0,
                            color: isLightTheme
                                ? const Color(0xFF6B4C93)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Subtitle
                        Text(
                          'Congratulations!',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                            decorationColor: Colors.transparent,
                            decorationThickness: 0,
                            color: isLightTheme
                                ? const Color(0xFF8B7BA6)
                                : Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Message
                        Text(
                          'Task completed!',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            decoration: TextDecoration.none,
                            decorationColor: Colors.transparent,
                            decorationThickness: 0,
                            color: isLightTheme
                                ? const Color(0xFF8B7BA6).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ConfettiParticle {
  double x;
  double y;
  Color color;
  double size;
  double speed;
  double angle;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speed,
    required this.angle,
  });
}

