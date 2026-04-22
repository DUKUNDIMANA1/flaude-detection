// lib/screens/dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../services/websocket_service.dart';
import '../utils/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  int _unreadAlerts = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    WebSocketService().onAlert((alert) {
      setState(() => _unreadAlerts++);
      _showAlertSnackbar(alert);
    });
    WebSocketService().connect();
  }

  void _showAlertSnackbar(Map<String, dynamic> alert) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppTheme.danger,
      content: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(alert['title'] ?? 'Fraud Alert',
            style: const TextStyle(color: Colors.white))),
      ]),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService().getDashboardStats();
      if (result['success'] == true) {
        final local = LocalDbService();
        await local.cacheStats('dashboard', jsonEncode(result));
        setState(() {
          _stats = result;
          _unreadAlerts = result['unread_alerts'] ?? 0;
        });
      } else {
        // Fallback to local cache
        final cached = await LocalDbService().getCachedStats('dashboard');
        if (cached != null) {
          setState(() => _stats = jsonDecode(cached));
        } else {
          await _loadLocalStats();
        }
      }
    } catch (_) {
      await _loadLocalStats();
    }
    setState(() => _loading = false);
  }

  Future<void> _loadLocalStats() async {
    final local = LocalDbService();
    final total  = await local.getTransactionCount();
    final fraud  = await local.getFraudCount();
    final avgScore = await local.getAvgFraudScore();
    final unread = await local.getUnreadAlertCount();
    setState(() {
      _stats = {
        'total_transactions': total,
        'total_fraud': fraud,
        'fraud_rate': total > 0 ? (fraud / total * 100).toStringAsFixed(2) : '0.00',
        'avg_fraud_score': avgScore,
        'unread_alerts': unread,
        'pending_review': 0,
        'fraud_trend': [],
      };
      _unreadAlerts = unread;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pushNamed(context, '/alerts'),
            ),
            if (_unreadAlerts > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: AppTheme.danger, shape: BoxShape.circle),
                  child: Text('$_unreadAlerts',
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
          ]),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: AppTheme.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildStatGrid(),
                    const SizedBox(height: 20),
                    _buildFraudTrend(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.shield_outlined, color: AppTheme.accent, size: 24),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('FraudGuard',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w700)),
        Text('Last updated: ${DateFormat('HH:mm').format(DateTime.now())}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ]),
    ]);
  }

  Widget _buildStatGrid() {
    final fraudRate = _stats['fraud_rate']?.toString() ?? '0';
    final avgScore  = ((_stats['avg_fraud_score'] ?? 0.0) as num).toDouble();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _statCard('Total Transactions',
            '${_stats['total_transactions'] ?? 0}',
            Icons.receipt_long_outlined, AppTheme.accent),
        _statCard('Fraud Detected',
            '${_stats['total_fraud'] ?? 0}',
            Icons.gpp_bad_outlined, AppTheme.danger),
        _statCard('Fraud Rate',
            '$fraudRate%',
            Icons.percent, AppTheme.warning),
        _statCard('Avg Risk Score',
            '${(avgScore * 100).toStringAsFixed(1)}%',
            Icons.analytics_outlined,
            AppTheme.riskColor(avgScore)),
        _statCard('Pending Review',
            '${_stats['pending_review'] ?? 0}',
            Icons.hourglass_empty, AppTheme.warning),
        _statCard('Unread Alerts',
            '$_unreadAlerts',
            Icons.notifications_active_outlined,
            _unreadAlerts > 0 ? AppTheme.danger : AppTheme.success),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ],
      ),
    );
  }

  Widget _buildFraudTrend() {
    final trend = (_stats['fraud_trend'] as List?) ?? [];
    if (trend.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No trend data available',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final maxVal = trend.map((t) => (t['fraud_count'] as int)).fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('7-Day Fraud Trend',
              style: TextStyle(color: AppTheme.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trend.map((day) {
                final count = (day['fraud_count'] as int);
                final date  = day['date'] as String;
                final frac  = maxVal > 0 ? count / maxVal : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$count',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 9)),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: 4 + 60 * frac,
                          decoration: BoxDecoration(
                            color: count > 0
                                ? AppTheme.danger.withOpacity(0.7 + frac * 0.3)
                                : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(date.substring(5),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 9)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _actionBtn('Analyze Transaction',
              Icons.document_scanner_outlined, AppTheme.accent, '/analyze')),
          const SizedBox(width: 12),
          Expanded(child: _actionBtn('View Alerts',
              Icons.notifications_outlined, AppTheme.warning, '/alerts')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _actionBtn('Transactions',
              Icons.list_alt_outlined, AppTheme.accentDim, '/transactions')),
          const SizedBox(width: 12),
          Expanded(child: _actionBtn('Settings',
              Icons.settings_outlined, AppTheme.textSecondary, '/settings')),
        ]),
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}
