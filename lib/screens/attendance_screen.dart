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
  List<_AttendanceRecord> _records = [];
  bool _isLoading = true;
  String? _error;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Summary counts
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;
  int _halfDayCount = 0;
  int _holidayCount = 0;
  int _totalCount = 0;

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final studentId = auth.userData?['id']?.toString() ?? auth.userId;
    final sessionId = auth.userData?['session_id']?.toString();

    if (studentId == null || sessionId == null) {
      setState(() {
        _error = 'Student data not found';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _apiClient.post('/get-student-attendance', {
        'student_id': studentId,
        'session_id': sessionId,
        'month': _selectedMonth,
        'year': _selectedYear,
      });

      final data = response['data'] as List<dynamic>? ?? [];
      final List<_AttendanceRecord> records = [];

      int present = 0, absent = 0, late = 0, halfDay = 0, holiday = 0;

      for (var item in data) {
        final date = item['date']?.toString() ?? '';
        final remark = item['remark']?.toString() ?? '';
        final attendanceType = item['attendance_type'] as Map<String, dynamic>?;
        final type = attendanceType?['type']?.toString() ?? 'Unknown';

        // Filter by selected month/year
        if (date.isNotEmpty) {
          try {
            final parsedDate = DateTime.parse(date);
            if (parsedDate.month != _selectedMonth || parsedDate.year != _selectedYear) {
              continue; // Skip records not in selected month
            }
          } catch (_) {}
        }

        switch (type) {
          case 'Present':
            present++;
            break;
          case 'Absent':
            absent++;
            break;
          case 'Late':
          case 'Late With Excuse':
            late++;
            break;
          case 'Half Day':
            halfDay++;
            break;
          case 'Holiday':
            holiday++;
            break;
        }

        records.add(_AttendanceRecord(
          date: date,
          type: type,
          remark: remark,
        ));
      }

      // Sort by date descending
      records.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _records = records;
        _presentCount = present;
        _absentCount = absent;
        _lateCount = late;
        _halfDayCount = halfDay;
        _holidayCount = holiday;
        _totalCount = records.length;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load attendance data';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String type) {
    switch (type) {
      case 'Present':
        return const Color(0xFF28A745);
      case 'Absent':
        return const Color(0xFFDC3545);
      case 'Late':
      case 'Late With Excuse':
        return const Color(0xFF007BFF);
      case 'Half Day':
        return const Color(0xFFFD7E14);
      case 'Holiday':
        return const Color(0xFF17A2B8);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String type) {
    switch (type) {
      case 'Present':
        return Icons.check_circle_rounded;
      case 'Absent':
        return Icons.cancel_rounded;
      case 'Late':
      case 'Late With Excuse':
        return Icons.access_time_rounded;
      case 'Half Day':
        return Icons.timelapse_rounded;
      case 'Holiday':
        return Icons.beach_access_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getShortLabel(String type) {
    switch (type) {
      case 'Present':
        return 'P';
      case 'Absent':
        return 'A';
      case 'Late':
        return 'L';
      case 'Late With Excuse':
        return 'E';
      case 'Half Day':
        return 'H';
      case 'Holiday':
        return 'HD';
      default:
        return '?';
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
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: AppTheme.cardBg,
          highlightColor: AppTheme.surfaceLight,
          child: Container(
            height: 70,
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
              onPressed: _loadAttendance,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Month/Year selector
          _buildMonthSelector(),
          const SizedBox(height: 16),

          // Summary card
          _buildSummaryCard(),
          const SizedBox(height: 16),

          // Attendance percentage bar
          if (_totalCount > 0) _buildPercentageBar(),
          if (_totalCount > 0) const SizedBox(height: 16),

          // Legend
          _buildLegend(),
          const SizedBox(height: 16),

          // Calendar grid
          if (_records.isNotEmpty) _buildCalendarGrid(),

          // Records list
          if (_records.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.event_busy_rounded,
                        color: AppTheme.textMuted, size: 48),
                    SizedBox(height: 16),
                    Text('No attendance records for this month',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
              });
              _loadAttendance();
            },
            icon: const Icon(Icons.chevron_left_rounded,
                color: AppTheme.textPrimary),
          ),
          Text(
            '${_monthNames[_selectedMonth - 1]} $_selectedYear',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
              });
              _loadAttendance();
            },
            icon: const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textPrimary),
          ),
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
            'Attendance Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryBadge(
                  label: 'Present',
                  count: _presentCount,
                  color: const Color(0xFF28A745)),
              const SizedBox(width: 8),
              _SummaryBadge(
                  label: 'Absent',
                  count: _absentCount,
                  color: const Color(0xFFDC3545)),
              const SizedBox(width: 8),
              _SummaryBadge(
                  label: 'Late',
                  count: _lateCount,
                  color: const Color(0xFF007BFF)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SummaryBadge(
                  label: 'Half Day',
                  count: _halfDayCount,
                  color: const Color(0xFFFD7E14)),
              const SizedBox(width: 8),
              _SummaryBadge(
                  label: 'Holiday',
                  count: _holidayCount,
                  color: const Color(0xFF17A2B8)),
              const SizedBox(width: 8),
              _SummaryBadge(
                  label: 'Total',
                  count: _totalCount,
                  color: Colors.white54),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageBar() {
    final attendedDays = _presentCount + _lateCount + _halfDayCount;
    final workingDays = _totalCount - _holidayCount;
    final percentage =
        workingDays > 0 ? (attendedDays / workingDays * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Attendance Rate',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: percentage >= 75
                      ? const Color(0xFF28A745)
                      : const Color(0xFFDC3545),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage >= 75
                    ? const Color(0xFF28A745)
                    : const Color(0xFFDC3545),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final items = [
      ('Present', const Color(0xFF28A745)),
      ('Absent', const Color(0xFFDC3545)),
      ('Late', const Color(0xFF007BFF)),
      ('Half Day', const Color(0xFFFD7E14)),
      ('Holiday', const Color(0xFF17A2B8)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item.$2,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              item.$1,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    // Build a map of date -> record
    final Map<int, _AttendanceRecord> dayMap = {};
    for (var record in _records) {
      try {
        final d = DateTime.parse(record.date);
        if (d.month == _selectedMonth && d.year == _selectedYear) {
          dayMap[d.day] = record;
        }
      } catch (_) {}
    }

    final daysInMonth =
        DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final firstWeekday =
        DateTime(_selectedYear, _selectedMonth, 1).weekday; // 1=Mon...7=Sun

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          // Day headers
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar days
          ...List.generate(
            ((daysInMonth + firstWeekday - 1) / 7).ceil(),
            (weekIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: List.generate(7, (dayOfWeek) {
                    final dayNum =
                        weekIndex * 7 + dayOfWeek + 1 - (firstWeekday - 1);

                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 36));
                    }

                    final record = dayMap[dayNum];
                    final hasRecord = record != null;
                    final color = hasRecord
                        ? _getStatusColor(record.type)
                        : Colors.transparent;

                    return Expanded(
                      child: Tooltip(
                        message: hasRecord
                            ? '${record.type}${record.remark.isNotEmpty ? '\n${record.remark}' : ''}'
                            : 'Day $dayNum',
                        child: Container(
                          height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: hasRecord
                                ? color.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: hasRecord
                                ? Border.all(
                                    color: color.withValues(alpha: 0.5),
                                    width: 1)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              hasRecord
                                  ? _getShortLabel(record.type)
                                  : dayNum.toString(),
                              style: TextStyle(
                                color: hasRecord ? color : AppTheme.textMuted,
                                fontSize: hasRecord ? 12 : 11,
                                fontWeight: hasRecord
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AttendanceRecord {
  final String date;
  final String type;
  final String remark;

  _AttendanceRecord({
    required this.date,
    required this.type,
    required this.remark,
  });
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                color: color == Colors.white54 ? Colors.white : color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
