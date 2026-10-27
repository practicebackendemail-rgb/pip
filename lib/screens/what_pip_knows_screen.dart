import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/di/injection.dart';
import '../../core/domain/memory_models.dart';
import '../../core/domain/memory_repository.dart';
import '../../core/services/nightly_reflection_service.dart';
import '../../core/theme/apple_theme.dart';
import '../../widgets/glass_container.dart';

/// "What Pip Knows About Me" Transparency Screen (Section 8.5)
/// Lets the user inspect, edit, and delete learned profile facts, episodic memories,
/// and behavioral rules, plus a nuclear "Forget Everything" button for total trust.
class WhatPipKnowsScreen extends StatefulWidget {
  final MemoryRepository memoryRepository;

  const WhatPipKnowsScreen({super.key, required this.memoryRepository});

  static void show(BuildContext context, MemoryRepository repo) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WhatPipKnowsScreen(memoryRepository: repo)),
    );
  }

  @override
  State<WhatPipKnowsScreen> createState() => _WhatPipKnowsScreenState();
}

class _WhatPipKnowsScreenState extends State<WhatPipKnowsScreen> {
  List<ProfileFact> _facts = [];
  List<MemoryItem> _memories = [];
  List<PipRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final facts = await widget.memoryRepository.getProfile();
    final memories = await widget.memoryRepository.searchMemories(const [], limit: 50);
    final rules = await widget.memoryRepository.getActiveRules();
    if (mounted) {
      setState(() {
        _facts = facts;
        _memories = memories;
        _rules = rules;
        _isLoading = false;
      });
    }
  }

  void _confirmForgetEverything() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Forget Everything?"),
        content: const Text(
          "This will permanently erase all learned memories, profile facts, and behavioral habits Pip has acquired about you. This action is irreversible.",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.memoryRepository.forgetEverything();
              HapticFeedback.heavyImpact();
              await _loadData();
            },
            child: const Text("Forget All"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("What Pip Knows", style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.trash, color: AppleTheme.accentRed),
            tooltip: "Forget Everything",
            onPressed: _confirmForgetEverything,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                _buildReflectionStatusBar(),
                const SizedBox(height: 12),
                _buildSectionHeader("Learned Profile Facts", _facts.length),
                if (_facts.isEmpty) _buildEmptyState("No learned facts yet. Chat with Pip to build understanding."),
                ..._facts.map((f) => _buildFactTile(f)),
                const SizedBox(height: 24),
                _buildSectionHeader("Episodic Memories", _memories.length),
                if (_memories.isEmpty) _buildEmptyState("No episodic memories stored."),
                ..._memories.map((m) => _buildMemoryTile(m)),
                const SizedBox(height: 24),
                _buildSectionHeader("Behavioral Rules", _rules.length),
                if (_rules.isEmpty) _buildEmptyState("No active rules configured."),
                ..._rules.map((r) => _buildRuleTile(r)),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildReflectionStatusBar() {
    final reflectionService = getIt<NightlyReflectionService>();
    return ListenableBuilder(
      listenable: reflectionService,
      builder: (context, _) {
        final last = reflectionService.lastReflectionAt;
        final timeStr = last != null
            ? '${last.month}/${last.day} at ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}'
            : 'Never';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Icon(
                reflectionService.isReflecting
                    ? CupertinoIcons.arrow_2_circlepath
                    : CupertinoIcons.sparkles,
                size: 16,
                color: AppleTheme.accentTeal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reflectionService.isReflecting
                      ? 'Reflecting and learning from interactions...'
                      : 'Last reflection: $timeStr',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(fontSize: 12, color: AppleTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(msg, style: const TextStyle(fontSize: 13, color: AppleTheme.textTertiary, fontStyle: FontStyle.italic)),
    );
  }

  Widget _buildFactTile(ProfileFact f) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassContainer(
        borderRadius: 14,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppleTheme.textPrimary)),
                  const SizedBox(height: 3),
                  Text(f.value, style: const TextStyle(fontSize: 12.5, color: AppleTheme.textSecondary)),
                ],
              ),
            ),
            Text("${(f.confidence * 100).toInt()}% conf", style: const TextStyle(fontSize: 11, color: Color(0xFF6FBF73))),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryTile(MemoryItem m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassContainer(
        borderRadius: 14,
        padding: const EdgeInsets.all(12),
        child: Text(m.text, style: const TextStyle(fontSize: 12.5, color: AppleTheme.textSecondary)),
      ),
    );
  }

  Widget _buildRuleTile(PipRule r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassContainer(
        borderRadius: 14,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text(r.instruction, style: const TextStyle(fontSize: 12.5, color: AppleTheme.textPrimary))),
            Text(r.scope, style: const TextStyle(fontSize: 11, color: AppleTheme.accentBlue)),
          ],
        ),
      ),
    );
  }
}
