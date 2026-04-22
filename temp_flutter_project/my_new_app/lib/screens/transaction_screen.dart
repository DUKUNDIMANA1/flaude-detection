// lib/screens/transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../models/transaction.dart';
import '../utils/theme.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Transaction> _transactions = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _transactions = [];
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService().getTransactions(
        page: _page, perPage: 30, status: _filterStatus);
      if (res['success'] == true) {
        final fetched = (res['transactions'] as List<dynamic>)
            .map((e) => Transaction.fromMap(e as Map<String, dynamic>))
            .toList();
        for (final t in fetched) await LocalDbService().insertTransaction(t);
        setState(() {
          _transactions.addAll(fetched);
          _hasMore = _page < (res['pages'] ?? 1);
          _page++;
        });
      } else {
        // offline fallback
        final local = await LocalDbService()
            .getTransactions(status: _filterStatus);
        setState(() => _transactions = local);
      }
    } catch (_) {
      final local = await LocalDbService().getTransactions(status: _filterStatus);
      setState(() => _transactions = local);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Analyze'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildList(), const AnalyzeTab()],
      ),
    );
  }

  Widget _buildList() {
    return Column(children: [
      _buildFilterBar(),
      Expanded(
        child: _loading && _transactions.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : RefreshIndicator(
                onRefresh: () => _loadTransactions(reset: true),
                color: AppTheme.accent,
                child: _transactions.isEmpty
                    ? const Center(child: Text('No transactions found',
                        style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _transactions.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _transactions.length) {
                            _loadTransactions();
                            return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                      color: AppTheme.accent, strokeWidth: 2),
                                ));
                          }
                          return _txnCard(_transactions[i]);
                        },
                      ),
              ),
      ),
    ]);
  }

  Widget _buildFilterBar() {
    final statuses = [null, 'pending', 'approved', 'blocked', 'review', 'flagged'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = statuses[i];
          final selected = _filterStatus == s;
          return GestureDetector(
            onTap: () {
              setState(() => _filterStatus = s);
              _loadTransactions(reset: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(s ?? 'All',
                  style: TextStyle(
                      color: selected ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }

  Widget _txnCard(Transaction txn) {
    final riskColor = AppTheme.riskColor(txn.fraudScore);
    return GestureDetector(
      onTap: () => _showDetail(txn),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: txn.isFraud
              ? Border.all(color: AppTheme.danger.withOpacity(0.5))
              : null,
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_channelIcon(txn.channel), color: riskColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(txn.merchant ?? 'Unknown', maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(DateFormat('MMM d, HH:mm').format(txn.timestamp),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$${txn.amount.toStringAsFixed(2)}',
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            _statusBadge(txn.status),
          ]),
          const SizedBox(width: 8),
          Column(children: [
            Text('${(txn.fraudScore * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: riskColor, fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text('risk', style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final colors = {
      'approved': AppTheme.success,
      'blocked':  AppTheme.danger,
      'flagged':  AppTheme.warning,
      'review':   Colors.blue,
      'pending':  AppTheme.textSecondary,
    };
    final color = colors[status] ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'online':  return Icons.language;
      case 'pos':     return Icons.point_of_sale;
      case 'atm':     return Icons.atm;
      case 'mobile':  return Icons.smartphone;
      default:        return Icons.payment;
    }
  }

  void _showDetail(Transaction txn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => TransactionDetailSheet(txn: txn),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
}

// ── Detail bottom sheet ────────────────────────────────────────────────────────

class TransactionDetailSheet extends StatelessWidget {
  final Transaction txn;
  const TransactionDetailSheet({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final riskColor = AppTheme.riskColor(txn.fraudScore);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2)),
          )),

          Row(children: [
            Expanded(child: Text(txn.merchant ?? 'Unknown',
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontSize: 20, fontWeight: FontWeight.w700))),
            Text('\$${txn.amount.toStringAsFixed(2)}',
                style: TextStyle(color: riskColor, fontSize: 20,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),

          // Risk meter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: riskColor.withOpacity(0.3)),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(AppTheme.riskLabel(txn.fraudScore),
                    style: TextStyle(color: riskColor,
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${(txn.fraudScore * 100).toStringAsFixed(1)}%',
                    style: TextStyle(color: riskColor,
                        fontWeight: FontWeight.w700, fontSize: 18)),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: txn.fraudScore,
                backgroundColor: AppTheme.surfaceLight,
                valueColor: AlwaysStoppedAnimation(riskColor),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ]),
          ),

          if (txn.fraudReasons.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Risk Factors',
                style: TextStyle(color: AppTheme.textSecondary,
                    fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...txn.fraudReasons.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warning, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(r, style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13))),
              ]),
            )),
          ],

          const SizedBox(height: 16),
          const Divider(color: AppTheme.surfaceLight),
          const SizedBox(height: 8),
          _row('Status',       txn.status),
          _row('Channel',      txn.channel),
          _row('Card',         txn.cardType ?? 'N/A'),
          _row('Card Last 4',  txn.cardLast4 ?? 'N/A'),
          _row('Location',     txn.location ?? 'N/A'),
          _row('Device',       txn.deviceId ?? 'N/A'),
          _row('Timestamp',    DateFormat('MMM d, yyyy HH:mm').format(txn.timestamp)),
          _row('Transaction ID', txn.transactionId, small: true),

          const SizedBox(height: 20),
          if (txn.status == 'review' || txn.isFraud)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark as Reviewed'),
                onPressed: () async {
                  await ApiService().reviewTransaction(txn.id!, 'approved', null);
                  Navigator.pop(context);
                },
              ),
            ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13)),
          Flexible(child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: small ? 11 : 13,
                  fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// ── Analyze tab ────────────────────────────────────────────────────────────────

class AnalyzeTab extends StatefulWidget {
  const AnalyzeTab({super.key});
  @override
  State<AnalyzeTab> createState() => _AnalyzeTabState();
}

class _AnalyzeTabState extends State<AnalyzeTab> {
  final _amountCtrl   = TextEditingController();
  final _merchantCtrl = TextEditingController();
  String _channel     = 'online';
  String _cardType    = 'credit';
  bool _newDevice     = false;
  bool _vpn           = false;
  bool _loading       = false;
  Map<String, dynamic>? _result;

  Future<void> _analyze() async {
    if (_amountCtrl.text.isEmpty) return;
    setState(() { _loading = true; _result = null; });
    final txData = {
      'transaction_id': const Uuid().v4(),
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'merchant': _merchantCtrl.text.isEmpty ? 'Test Merchant' : _merchantCtrl.text,
      'channel': _channel,
      'card_type': _cardType,
      'new_device': _newDevice,
      'vpn_detected': _vpn,
      'transaction_type': 'purchase',
      'frequency_24h': 1,
      'failed_attempts': 0,
      'avg_amount_7d': 200.0,
      'distance_from_home': 0.0,
    };
    final res = await ApiService().analyzeTransaction(txData);
    setState(() { _result = res; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Analyze a Transaction',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Amount (\$)',
            prefixIcon: Icon(Icons.attach_money, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _merchantCtrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Merchant Name',
            prefixIcon: Icon(Icons.store_outlined, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 16),

        _dropdownRow('Channel', _channel, ['online', 'pos', 'atm', 'mobile'],
            (v) => setState(() => _channel = v!)),
        const SizedBox(height: 12),
        _dropdownRow('Card Type', _cardType, ['credit', 'debit', 'prepaid'],
            (v) => setState(() => _cardType = v!)),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(child: _switchTile('New Device', _newDevice,
              (v) => setState(() => _newDevice = v))),
          const SizedBox(width: 12),
          Expanded(child: _switchTile('VPN Detected', _vpn,
              (v) => setState(() => _vpn = v))),
        ]),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.document_scanner_outlined),
            label: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2))
                : const Text('Analyze'),
            onPressed: _loading ? null : _analyze,
          ),
        ),

        if (_result != null) ...[
          const SizedBox(height: 24),
          _buildResult(),
        ],
      ]),
    );
  }

  Widget _dropdownRow(
      String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        DropdownButton<String>(
          value: value,
          dropdownColor: AppTheme.surface,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          underline: const SizedBox(),
          onChanged: onChanged,
          items: items.map((i) =>
              DropdownMenuItem(value: i, child: Text(i))).toList(),
        ),
      ]),
    );
  }

  Widget _switchTile(String label, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  Widget _buildResult() {
    final score     = (_result!['fraud_score'] as num?)?.toDouble() ?? 0;
    final isFraud   = _result!['is_fraud'] as bool? ?? false;
    final action    = _result!['action'] as String? ?? 'approve';
    final reasons   = (_result!['fraud_reasons'] as List?) ?? [];
    final riskColor = AppTheme.riskColor(score);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isFraud ? Icons.gpp_bad : Icons.gpp_good, color: riskColor, size: 22),
          const SizedBox(width: 8),
          Text(AppTheme.riskLabel(score),
              style: TextStyle(color: riskColor,
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${(score * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: riskColor,
                  fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: score,
          backgroundColor: AppTheme.surfaceLight,
          valueColor: AlwaysStoppedAnimation(riskColor),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 12),
        Text('Action: ${action.toUpperCase()}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        if (reasons.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...reasons.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Icon(Icons.arrow_right, color: AppTheme.warning, size: 16),
              Expanded(child: Text(r.toString(),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13))),
            ]),
          )),
        ],
      ]),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    super.dispose();
  }
}
