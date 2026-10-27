import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../core/di/injection.dart';
import '../core/services/email_service.dart';
import '../core/services/gemini_service.dart';
import '../core/services/task_provider.dart';
import '../core/services/voice_service.dart';
import '../core/theme/apple_theme.dart';
import '../models/task_model.dart';
import '../widgets/glass_container.dart';
import '../widgets/pip_companion.dart';
import '../widgets/supreme_intelligence_avatar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _briefingText;
  bool _isLoadingBriefing = false;

  void _triggerBriefing() async {
    final gemini = getIt<GeminiAssistantService>();
    final taskProv = getIt<TaskProvider>();
    final email = getIt<EmailService>();
    final voice = getIt<VoiceService>();

    setState(() => _isLoadingBriefing = true);
    final emailHeaders = await email.fetchUnreadSummaries();
    final result = await gemini.generateDailyBriefing(
      tasks: taskProv.allTasks.where((t) => !t.isCompleted).toList(),
      recentEmails: emailHeaders,
    );
    if (mounted) {
      setState(() {
        _briefingText = result;
        _isLoadingBriefing = false;
      });
      // Speak the briefing out loud!
      voice.speak(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProv = getIt<TaskProvider>();
    final gemini = getIt<GeminiAssistantService>();

    return ListenableBuilder(
      listenable: Listenable.merge([taskProv, gemini]),
      builder: (context, _) {
        final pendingTasks = taskProv.allTasks.where((t) => !t.isCompleted).length;
        final completedToday = taskProv.allTasks.where((t) => t.isCompleted).length;

        return Scaffold(
      body: Stack(
        children: [
          // Ambient Apple subtle backdrop glows
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppleTheme.accentBlue.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppleTheme.accentPurple.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Header with Pip Desk Companion / Avatar
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: Builder(
                      builder: (ctx) {
                        final voice = getIt<VoiceService>();
                        final isPip = gemini.currentPersona.id == 'pip';

                        final pipMood = voice.isSpeaking
                            ? PipMood.talking
                            : voice.isListening
                                ? PipMood.listening
                                : _isLoadingBriefing
                                    ? PipMood.thinking
                                    : PipMood.idle;

                        final avatarState = voice.isSpeaking
                            ? AvatarState.speaking
                            : _isLoadingBriefing
                                ? AvatarState.thinking
                                : AvatarState.idle;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Center(
                              child: isPip
                                  ? PipDeskCompanion(
                                      width: 290,
                                      height: 200,
                                      mood: pipMood,
                                      onTap: () {
                                        if (voice.isSpeaking) {
                                          voice.stopSpeaking();
                                        } else {
                                          _triggerBriefing();
                                        }
                                      },
                                    )
                                  : SupremeIntelligenceCore(
                                      size: 190,
                                      state: avatarState,
                                      onTap: () {
                                        if (voice.isSpeaking) {
                                          voice.stopSpeaking();
                                        } else {
                                          _triggerBriefing();
                                        }
                                      },
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              voice.isSpeaking
                                  ? (isPip ? "PIP IS SPEAKING..." : "COMMUNICATING...")
                                  : gemini.currentPersona.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                color: AppleTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gemini.currentPersona.role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: isPip ? const Color(0xFFE2A826) : AppleTheme.accentTeal.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // AI Executive Briefing Card
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(20),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppleTheme.accentBlue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(CupertinoIcons.sparkles, color: AppleTheme.accentBlue, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Daily AI Briefing',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: AppleTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: _isLoadingBriefing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppleTheme.accentBlue),
                                      )
                                    : const Icon(CupertinoIcons.arrow_clockwise, size: 18, color: AppleTheme.textSecondary),
                                onPressed: _isLoadingBriefing ? null : _triggerBriefing,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _briefingText ??
                                (gemini.isConfigured
                                    ? "Tap refresh to let ${gemini.currentPersona.name} digest your inbox and organize today's schedule."
                                    : "Enter your Gemini API key in Settings to unlock automated daily morning briefings."),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppleTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                  ),
                ),

                // Metrics Bento Grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.clock, color: AppleTheme.accentOrange, size: 24),
                                const SizedBox(height: 12),
                                Text(
                                  '$pendingTasks',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppleTheme.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                const Text('Pending Tasks', style: TextStyle(fontSize: 13, color: AppleTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.checkmark_seal_fill, color: AppleTheme.accentGreen, size: 24),
                                const SizedBox(height: 12),
                                Text(
                                  '$completedToday',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppleTheme.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                const Text('Completed Today', style: TextStyle(fontSize: 13, color: AppleTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 150.ms),
                  ),
                ),

                // Project Selector Filter
                SliverPadding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                  sliver: SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: taskProv.projects.map((proj) {
                          final isSelected = taskProv.selectedProject == proj;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(proj),
                              selected: isSelected,
                              onSelected: (_) => taskProv.selectProject(proj),
                              selectedColor: AppleTheme.accentBlue,
                              backgroundColor: Colors.white.withOpacity(0.06),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppleTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide.none,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // Project Tasks List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: taskProv.tasks.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text('All tasks completed! ✨', style: TextStyle(color: AppleTheme.textSecondary)),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final task = taskProv.tasks[index];
                              return _buildTaskCard(context, task, taskProv);
                            },
                            childCount: taskProv.tasks.length,
                          ),
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppleTheme.accentBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(CupertinoIcons.add, color: Colors.white),
        label: const Text('New Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () => _showAddTaskSheet(context),
      ),
    );
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskItem task, TaskProvider provider) {
    Color priorityColor = AppleTheme.accentTeal;
    if (task.priority == TaskPriority.high) priorityColor = AppleTheme.accentOrange;
    if (task.priority == TaskPriority.urgent) priorityColor = AppleTheme.accentRed;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppleTheme.accentRed.withOpacity(0.3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      onDismissed: (_) => provider.deleteTask(task.id),
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 18,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => provider.toggleTask(task.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted ? AppleTheme.accentGreen : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted ? AppleTheme.accentGreen : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: task.isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: task.isCompleted ? AppleTheme.textTertiary : AppleTheme.textPrimary,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.project,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: priorityColor),
                        ),
                      ),
                      if (task.dueDate != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, h:mm a').format(task.dueDate!),
                          style: const TextStyle(fontSize: 11, color: AppleTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    final titleController = TextEditingController();
    String selectedProj = 'Work';
    TaskPriority selectedPriority = TaskPriority.medium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: GlassContainer(
            borderRadius: 28,
            padding: const EdgeInsets.all(24),
            backgroundColor: const Color(0xFF1E212D).withOpacity(0.96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Task',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppleTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: const TextStyle(color: AppleTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Schedule meeting with design team',
                    hintStyle: const TextStyle(color: AppleTheme.textTertiary),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: selectedProj,
                      dropdownColor: AppleTheme.surfaceDark,
                      underline: const SizedBox(),
                      items: ['Work', 'Personal', 'Fitness', 'Learning']
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedProj = val!),
                    ),
                    DropdownButton<TaskPriority>(
                      value: selectedPriority,
                      dropdownColor: AppleTheme.surfaceDark,
                      underline: const SizedBox(),
                      items: TaskPriority.values
                          .map((pr) => DropdownMenuItem(value: pr, child: Text(pr.name.toUpperCase())))
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedPriority = val!),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppleTheme.accentBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (titleController.text.trim().isNotEmpty) {
                        getIt<TaskProvider>().addTask(
                              title: titleController.text.trim(),
                              project: selectedProj,
                              priority: selectedPriority,
                            );
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Create Task', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
