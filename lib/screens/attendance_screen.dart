import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _attendance = [];
  bool _isLoading = true;
  String? _error;
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final studentData = auth.userData;
    final studentSessionId = studentData?['student_session_id']?.toString();

    try {
      final response = await _apiClient.post('/get-student-attendance', {
        'student_session_id': studentSessionId ?? '',
      });

      setState(() {
        _attendance = response['data'] ?? [];
        _presentCount = 0;
        _absentCount = 0;
        _lateCount = 0;
        for (var record in _attendance) {
          final type = record['type']?.toString().toLowerCase() ?? '';
          final typeId = record['attendence_type_id']?.toString() ?? '';
          if (type == 'present' || typeId == '1') {
            _presentCount++;
          } else if (type == 'absent' || typeId == '2') {
            _absentCount++;
          } else if (type == 'late' || typeId == '3') {
            _lateCount++;
          }
        }
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load attendance';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: _isLoading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer.fromColors(
              baseColor: AppTheme.cardBg,
              highlightColor: AppTheme.surfaceLight,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
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
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadAttendance();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final total = _presentCount + _absentCount + _lateCount;
    final percentage = total > 0 ? (_presentCount / total * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7A5AF8), Color(0xFFA78BFA)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Attendance Rate',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem('Present', _presentCount, AppTheme.success),
                    _StatItem('Absent', _absentCount, AppTheme.error),
                    _StatItem('Late', _lateCount, AppTheme.warning),
                    _StatItem('Total', total, Colors.white),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Records
          Text(
            'Attendance Records',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),

          if (_attendance.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('No attendance records',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            ...List.generate(_attendance.length, (index) {
              final record = _attendance[index];
              final date = record['date'] ?? '';
              final type = record['type'] ??
                  (record['attendence_type_id']?.toString() == '1'
                      ? 'Present'
                      : record['attendence_type_id']?.toString() == '2'
                          ? 'Absent'
                          : 'Late');
              final isPresent = type.toString().toLowerCase() == 'present' ||
                  record['attendence_type_id']?.toString() == '1';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPresent ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        date,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPresent
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.toString(),
                        style: TextStyle(
                          color: isPresent ? AppTheme.success : AppTheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatItem(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
