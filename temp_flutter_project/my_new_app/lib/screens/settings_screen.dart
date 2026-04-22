// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _rules = [];
  bool _loadingRules = true;
  int _localTxns = 0;

  @override
  void initState() {
    super.initState();
    _loadRules();
    _loadLocalStats();
  }

  Future<void> _loadRules() async {
    final rules = await ApiService().getRules();
    setState(() { _rules = rules; _loadingRules = false; });
  }

  Future<void> _loadLocalStats() async {
    final count = await LocalDbService().getTransactionCount();
    setState(() => _localTxns = count);
  }

  Future<void> _logout() async {
    await ApiService().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Connection', [
            _infoTile('Backend URL', AppConstants.baseUrl, Icons.cloud_outlined),
            _infoTile('WebSocket URL', AppConstants.wsUrl, Icons.sync_outlined),
          ]),
          const SizedBox(height: 20),
          _section('Local Data', [
            _infoTile('Cached Transactions', '$_localTxns', Icons.storage_outlined),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
              title: const Text('Clear Local Cache',
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text('Remove locally stored transactions',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              onTap: _confirmClearCache,
              tileColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ]),
          const SizedBox(height: 20),
          _section(
            'Detection Rules (${_rules.length})',
            _loadingRules
                ? [const Center(child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2))]
                : _rules.map((rule) => _ruleTile(rule)).toList(),
          ),
          const SizedBox(height: 20),
          _section('Account', [
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: const Text('Sign Out',
                  style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
              onTap: _logout,
              tileColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ]),
          const SizedBox(height: 30),
          const Center(
            child: Text('FraudGuard v1.0.0',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textSecondary, size: 20),
      title: Text(label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      subtitle: Text(value,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
    );
  }

  Widget _ruleTile(Map<String, dynamic> rule) {
    final isActive = rule['is_active'] as bool? ?? true;
    final severity = rule['severity'] as String? ?? 'low';
    final severityColors = {
      'low': AppTheme.success,
      'medium': AppTheme.warning,
      'high': AppTheme.danger,
      'critical': Colors.red,
    };
    return ListTile(
      leading: Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: severityColors[severity] ?? AppTheme.textSecondary,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(rule['name'] as String? ?? '',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
      subtitle: Text(rule['description'] as String? ?? '',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Switch(
        value: isActive,
        onChanged: (val) async {
          await ApiService().toggleRule(rule['id'] as int, val);
          _loadRules();
        },
        activeColor: AppTheme.accent,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _confirmClearCache() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Clear Cache',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('This will remove all locally cached transactions.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Clear old cache
              await LocalDbService().clearOldCache();
              _loadLocalStats();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}
