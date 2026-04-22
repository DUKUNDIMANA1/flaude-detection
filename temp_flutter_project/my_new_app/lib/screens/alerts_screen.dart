// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../utils/theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getAlerts(isRead: _unreadOnly ? false : null);
      if (res['success'] == true) {
        final list = res['alerts'] as List<dynamic>? ?? [];
        final mapped = list.cast<Map<String, dynamic>>();
        // Cache locally
        for (final a in mapped) await LocalDbService().insertAlert(a);
        setState(() => _alerts = mapped);
      } else {
        final local = await LocalDbService().getAlerts(
            unreadOnly: _unreadOnly);
        setState(() => _alerts = local);
      }
    } catch (_) {
      final local = await LocalDbService().getAlerts(unreadOnly: _unreadOnly);
      setState(() => _alerts = local);
    }
    setState(() => _loading = false);
  }

  Future<void> _markRead(Map<String, dynamic> alert) async {
    final id = alert['id'] as int?;
    if (id != null) {
      await ApiService().markAlertRead(id);
      await LocalDbService().markAlertRead(alert['alert_id'] as String? ?? '');
      _loadAlerts();
    }
  }

  Future<void> _resolve(Map<String, dynamic> alert) async {
    final id = alert['id'] as int?;
    if (id != null) {
      await ApiService().resolveAlert(id);
      _loadAlerts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _unreadOnly = !_unreadOnly;
              _loadAlerts();
            }),
            child: Text(
              _unreadOnly ? 'Show All' : 'Unread Only',
              style: const TextStyle(color: AppTheme.accent, fontSize: 12),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              onRefresh: _loadAlerts,
              color: AppTheme.accent,
              child: _alerts.isEmpty
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.notifications_off_outlined,
                            color: AppTheme.textSecondary, size: 48),
                        SizedBox(height: 12),
                        Text('No alerts', style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14)),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _alerts.length,
                      itemBuilder: (_, i) => _alertCard(_alerts[i]),
                    ),
            ),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'low';
    final isRead = alert['is_read'] is int 
        ? (alert['is_read'] as int) == 1 
        : (alert['is_read'] as bool? ?? false);
    final isResolved = (alert['is_resolved'] as int? ?? 0) == 1
        || alert['is_resolved'] == true;
    final createdAt = alert['created_at'] != null
        ? DateTime.tryParse(alert['created_at'] as String) : null;

    final colors = {
      'critical': AppTheme.danger,
      'high': Colors.orange,
      'medium': AppTheme.warning,
      'low': AppTheme.success,
    };
    final color = colors[severity] ?? AppTheme.textSecondary;
    final icons = {
      'critical': Icons.gpp_bad,
      'high': Icons.warning_amber_rounded,
      'medium': Icons.info_outline,
      'low': Icons.notifications_outlined,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: isRead
            ? null
            : Border.all(color: color.withOpacity(0.4)),
        boxShadow: isRead
            ? null
            : [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icons[severity] ?? Icons.notifications,
              color: color, size: 20),
        ),
        title: Row(children: [
          Expanded(
            child: Text(alert['title'] as String? ?? 'Alert',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.w700,
                    fontSize: 13)),
          ),
          if (!isRead)
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(alert['message'] as String? ?? '',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(severity.toUpperCase(),
                    style: TextStyle(color: color, fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              if (createdAt != null)
                Text(DateFormat('MMM d HH:mm').format(createdAt),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              const Spacer(),
              if (!isResolved) ...[
                if (!isRead)
                  GestureDetector(
                    onTap: () => _markRead(alert),
                    child: const Text('Mark read',
                        style: TextStyle(color: AppTheme.accent, fontSize: 11)),
                  ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _resolve(alert),
                  child: const Text('Resolve',
                      style: TextStyle(color: AppTheme.success, fontSize: 11)),
                ),
              ] else
                const Text('Resolved',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }
}
