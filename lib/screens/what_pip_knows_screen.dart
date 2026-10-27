import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/di/injection.dart';
import '../../core/domain/memory_models.dart';
import '../../core/domain/memory_repository.dart';
import '../../core/services/nightly_reflection_service.dart';
import '../../core/services/sync/pip_cloud_sync_coordinator.dart';
import '../../core/theme/apple_theme.dart';
import '../../widgets/glass_container.dart';

/// "What Pip Knows About Me" Transparency Screen (Section 8.5)
/// Lets the user inspect, edit, and delete learned profile facts, episodic memories,
/// and behavioral rules, plus nuclear "Forget Everything" and immediate "Sync Now".
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
          "This will write tombstones for all learned facts, rules, and episodic memories across all synced devices. This cannot be undone.",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Erase All"),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.memoryRepository.forgetEverything();
              HapticFeedback.heavyImpact();
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
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
                _buildSyncStatusBar(),
                const SizedBox(height: 12),
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

  Widget _buildSyncStatusBar() {
    final sync = getIt<PipCloudSyncCoordinator>();
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final last = sync.lastSyncTime;
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
              const Icon(CupertinoIcons.cloud_upload, color: AppleTheme.accentTeal, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Cloud Sync: Last synced $timeStr", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppleTheme.textPrimary)),
                    if (sync.lastError != null)
                      Text("Error: ${sync.lastError}", style: const TextStyle(fontSize: 10, color: AppleTheme.accentRed)),
                  ],
                ),
              ),
              TextButton(
                onPressed: sync.isSyncing
                    ? null
                    : () async {
                        final success = await sync.syncNow(force: true);
                        if (success) _loadData();
                      },
                child: sync.isSyncing
                    ? const CupertinoActivityIndicator(radius: 8)
                    : const Text("Sync Now", style: TextStyle(fontSize: 12, color: AppleTheme.accentTeal, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
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
              const Icon(CupertinoIcons.sparkles, color: AppleTheme.accentOrange, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Nightly Reflection: Last synthesized $timeStr",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppleTheme.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppleTheme.textPrimary)),
        Text("$count items", style: const TextStyle(fontSize: 12, color: AppleTheme.textTertiary)),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message, style: const TextStyle(color: AppleTheme.textTertiary, fontStyle: FontStyle.italic, fontSize: 13)),
    );
  }

  Widget _buildFactTile(ProfileFact fact) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 12,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fact.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppleTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(fact.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppleTheme.textPrimary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.xmark_circle, color: AppleTheme.textTertiary, size: 18),
            onPressed: () async {
              await widget.memoryRepository.deleteFact(fact.key);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryTile(MemoryItem memory) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 12,
      child: Row(
        children: [
          Expanded(
            child: Text(memory.text, style: const TextStyle(fontSize: 13, color: AppleTheme.textPrimary)),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.xmark_circle, color: AppleTheme.textTertiary, size: 18),
            onPressed: () async {
              await widget.memoryRepository.deleteMemory(memory.id);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRuleTile(PipRule rule) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 12,
      child: Row(
        children: [
          Expanded(
            child: Text(rule.instruction, style: const TextStyle(fontSize: 13, color: AppleTheme.textPrimary)),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.xmark_circle, color: AppleTheme.textTertiary, size: 18),
            onPressed: () async {
              await widget.memoryRepository.deleteRule(rule.id);
              _loadData();
            },
          ),
        ],
      ),
    );
  }
}
