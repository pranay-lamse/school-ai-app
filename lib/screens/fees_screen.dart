import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  final ApiClient _apiClient = ApiClient();
  List<_FeeRow> _fees = [];
  double _totalAmount = 0;
  double _totalPaid = 0;
  double _totalDiscount = 0;
  double _totalFine = 0;
  double _totalBalance = 0;
  String _currencySymbol = '₹';
  bool _isLoading = true;
  String? _error;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _loadFees();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Successful! Payment ID: ${response.paymentId}'),
        backgroundColor: AppTheme.success,
      ),
    );
    // In a real app, call your backend to verify and update the fee status
    _loadFees();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message ?? "Unknown error"}'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet Selected: ${response.walletName}')),
    );
  }

  void _openCheckout(_FeeRow fee) {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Razorpay Flutter does not support Web directly in this demo. Please use the mobile app (APK).'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    var options = {
      'key': 'rzp_test_YOUR_FAKE_DEMO_KEY', // Replace with real key later
      'amount': (fee.balance * 100).toInt(), // amount in the smallest currency sub-unit
      'name': 'AcadiCron',
      'description': '${fee.groupName} - ${fee.feeName}',
      'prefill': {
        'contact': '9876543210',
        'email': 'student@example.com'
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: e');
    }
  }

  Future<void> _loadFees() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    // The API expects student_session_id, not student id
    final studentSessionId =
        auth.userData?['student_session_id']?.toString() ?? auth.userId;

    if (studentSessionId == null) {
      setState(() {
        _error = 'Student session ID not found';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _apiClient.get('/studentfees/$studentSessionId');

      final dueFeesGroups =
          response['student_due_fees'] as List<dynamic>? ?? [];
      final currencySymbol =
          response['currency_symbol']?.toString() ?? '₹';

      final List<_FeeRow> allFees = [];
      double totalAmt = 0, totalPd = 0, totalDisc = 0, totalFn = 0, totalBal = 0;

      for (var group in dueFeesGroups) {
        final groupName = group['name']?.toString() ?? 'Fee Group';
        final fees = group['fees'] as List<dynamic>? ?? [];

        for (var fee in fees) {
          final amount = _parseDouble(fee['amount']);
          final fineAmount = _parseDouble(fee['fine_amount']);
          final code = fee['code']?.toString() ?? '';
          final dueDate = fee['due_date']?.toString();
          final feeName = fee['name']?.toString() ?? fee['type']?.toString() ?? 'Fee';

          // Parse amount_detail (JSON string of deposit records)
          double paid = 0, discount = 0, fine = 0;
          final amountDetail = fee['amount_detail'];
          if (amountDetail != null &&
              amountDetail != 0 &&
              amountDetail != '0' &&
              amountDetail is String &&
              amountDetail.isNotEmpty) {
            try {
              final parsed = jsonDecode(amountDetail);
              if (parsed is Map) {
                for (var entry in parsed.values) {
                  if (entry is Map) {
                    paid += _parseDouble(entry['amount']);
                    discount += _parseDouble(entry['amount_discount']);
                    fine += _parseDouble(entry['amount_fine']);
                  }
                }
              }
            } catch (_) {}
          }

          final balance = amount - (paid + discount);

          totalAmt += amount;
          totalPd += paid;
          totalDisc += discount;
          totalFn += fine;
          totalBal += balance;

          allFees.add(_FeeRow(
            groupName: groupName,
            feeName: feeName,
            code: code,
            dueDate: dueDate,
            amount: amount,
            fineAmount: fineAmount,
            paid: paid,
            discount: discount,
            fine: fine,
            balance: balance,
          ));
        }
      }

      setState(() {
        _fees = allFees;
        _totalAmount = totalAmt;
        _totalPaid = totalPd;
        _totalDiscount = totalDisc;
        _totalFine = totalFn;
        _totalBalance = totalBal;
        _currencySymbol = currencySymbol;
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

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
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
                  : _buildFeesContent(),
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
            Text(_error!,
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
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

  Widget _buildFeesContent() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadFees();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          _buildSummaryCard(),
          const SizedBox(height: 20),
          // Fee items
          ..._fees.map((fee) => _buildFeeCard(fee)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A5AF8), Color(0xFF9F7AEA)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fee Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                    label: 'Total',
                    value: '$_currencySymbol${_totalAmount.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _SummaryItem(
                    label: 'Paid',
                    value: '$_currencySymbol${_totalPaid.toStringAsFixed(2)}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                    label: 'Discount',
                    value:
                        '$_currencySymbol${_totalDiscount.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _SummaryItem(
                    label: 'Balance',
                    value:
                        '$_currencySymbol${_totalBalance.toStringAsFixed(2)}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeeCard(_FeeRow fee) {
    Color statusColor;
    String statusText;
    Color statusBg;

    if (fee.balance <= 0) {
      statusText = 'Paid';
      statusColor = const Color(0xFF15803D);
      statusBg = const Color(0xFFDCFCE7);
    } else if (fee.paid > 0) {
      statusText = 'Partial';
      statusColor = const Color(0xFF854D0E);
      statusBg = const Color(0xFFFEF9C3);
    } else {
      statusText = 'Unpaid';
      statusColor = const Color(0xFF991B1B);
      statusBg = const Color(0xFFFEE2E2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: group name + status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  fee.groupName,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fee type + code
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_rounded,
                    color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fee.code.isNotEmpty ? fee.code : fee.feeName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (fee.dueDate != null)
                      Text(
                        'Due: ${fee.dueDate}',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _DetailRow(
                    label: 'Amount',
                    value:
                        '$_currencySymbol${fee.amount.toStringAsFixed(2)}'),
                if (fee.fineAmount > 0)
                  _DetailRow(
                      label: 'Fine',
                      value:
                          '+ $_currencySymbol${fee.fineAmount.toStringAsFixed(2)}',
                      valueColor: AppTheme.error),
                if (fee.discount > 0)
                  _DetailRow(
                      label: 'Discount',
                      value:
                          '- $_currencySymbol${fee.discount.toStringAsFixed(2)}',
                      valueColor: AppTheme.success),
                if (fee.paid > 0)
                  _DetailRow(
                      label: 'Paid',
                      value:
                          '$_currencySymbol${fee.paid.toStringAsFixed(2)}',
                      valueColor: AppTheme.success),
                const Divider(color: AppTheme.cardBorder, height: 16),
                _DetailRow(
                  label: 'Balance',
                  value:
                      '$_currencySymbol${fee.balance.toStringAsFixed(2)}',
                  isBold: true,
                  valueColor:
                      fee.balance <= 0 ? AppTheme.success : AppTheme.error,
                ),
                if (fee.balance > 0) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _openCheckout(fee),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Pay Now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeRow {
  final String groupName;
  final String feeName;
  final String code;
  final String? dueDate;
  final double amount;
  final double fineAmount;
  final double paid;
  final double discount;
  final double fine;
  final double balance;

  _FeeRow({
    required this.groupName,
    required this.feeName,
    required this.code,
    this.dueDate,
    required this.amount,
    required this.fineAmount,
    required this.paid,
    required this.discount,
    required this.fine,
    required this.balance,
  });
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
