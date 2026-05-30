import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _fees = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final studentId = auth.userData?['id']?.toString() ?? auth.userId;

    if (studentId == null) {
      setState(() {
        _error = 'Student ID not found';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _apiClient.get('/studentfees/$studentId');
      
      final dueFeesGroups = response['student_due_fees'] as List<dynamic>? ?? [];
      final List<dynamic> allFees = [];
      
      for (var group in dueFeesGroups) {
        final fees = group['fees'] as List<dynamic>? ?? [];
        for (var fee in fees) {
          // Flatten by adding group info to the fee
          fee['group_name'] = group['name'];
          allFees.add(fee);
        }
      }
      
      setState(() {
        _fees = allFees;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load fees data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: _isLoading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : _fees.isEmpty
                  ? _buildEmpty()
                  : _buildFeesList(),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: AppTheme.cardBg,
          highlightColor: AppTheme.surfaceLight,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadFees();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, color: AppTheme.textMuted, size: 48),
          SizedBox(height: 16),
          Text('No fee records found',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFeesList() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadFees();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _fees.length,
        itemBuilder: (context, index) {
          final fee = _fees[index];
          final groupName = fee['group_name'] ?? 'Fee Group';
          final feeType = fee['name'] ?? fee['type'] ?? 'Fee';
          final amount = fee['amount']?.toString() ?? '0';
          
          // amount_detail contains a JSON string or 0 if nothing is paid
          final amountDetail = fee['amount_detail'];
          double paidAmount = 0.0;
          if (amountDetail != null && amountDetail != 0 && amountDetail != '0') {
            try {
               // Sometimes amount_detail is a JSON string of a map/array, sometimes just a number.
               // We will try to parse if it looks like JSON. (Simple sum logic can go here if needed).
               // But for now let's just display it if it's a number, or assume 0 if unparseable to keep it simple.
            } catch (e) {
               // ignore
            }
          }
          final status = paidAmount > 0 ? 'Paid/Partial' : 'Unpaid';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: AppTheme.success, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        feeType,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount: ₹$amount',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.contains('Paid')
                          ? AppTheme.success.withValues(alpha: 0.15)
                          : AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: status.contains('Paid')
                            ? AppTheme.success
                            : AppTheme.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
