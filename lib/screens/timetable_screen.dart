import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient();
  Map<String, List<dynamic>> _timetableByDay = {};
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    // Set to current day
    final today = DateTime.now().weekday; // 1=Monday
    if (today >= 1 && today <= 6) {
      _tabController.index = today - 1;
    }
    _loadTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTimetable() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final studentData = auth.userData;
    final classId = studentData?['class_id']?.toString() ?? '';
    final sectionId = studentData?['section_id']?.toString() ?? '';

    try {
      final response = await _apiClient.get('/timetable-by/$classId/$sectionId');
      final data = response['data'] ?? [];

      // Group by day
      final Map<String, List<dynamic>> grouped = {};
      for (var entry in data) {
        final day = entry['day'] ?? '';
        grouped.putIfAbsent(day, () => []);
        grouped[day]!.add(entry);
      }

      setState(() {
        _timetableByDay = grouped;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load timetable';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.primaryPurple,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: AppTheme.textMuted,
          tabAlignment: TabAlignment.start,
          tabs: _days
              .map((day) => Tab(text: day.substring(0, 3).toUpperCase()))
              .toList(),
        ),
      ),
      body: _isLoading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: _days.map((day) {
                    final entries = _timetableByDay[day] ?? [];
                    return _buildDayView(day, entries);
                  }).toList(),
                ),
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
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadTimetable();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayView(String day, List<dynamic> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded,
                color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'No classes on $day',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    // Sort by time
    entries.sort((a, b) {
      final timeA = a['time_from']?.toString() ?? '';
      final timeB = b['time_from']?.toString() ?? '';
      return timeA.compareTo(timeB);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final subject = entry['subject_name'] ?? entry['subject'] ?? 'Subject';
        final timeFrom = entry['time_from'] ?? '';
        final timeTo = entry['time_to'] ?? '';
        final roomNo = entry['room_no'] ?? '';
        final teacher = entry['staff_name'] ?? '';

        final colors = [
          AppTheme.primaryPurple,
          AppTheme.info,
          AppTheme.success,
          AppTheme.warning,
          AppTheme.accentPink,
          const Color(0xFFA78BFA),
        ];
        final color = colors[index % colors.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time column
              SizedBox(
                width: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeFrom,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      timeTo,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Color bar
              Container(
                width: 3,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (roomNo.isNotEmpty) ...[
                            const Icon(Icons.room_outlined,
                                color: AppTheme.textMuted, size: 13),
                            const SizedBox(width: 4),
                            Text('Room $roomNo',
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12)),
                            const SizedBox(width: 12),
                          ],
                          if (teacher.isNotEmpty) ...[
                            const Icon(Icons.person_outline,
                                color: AppTheme.textMuted, size: 13),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(teacher,
                                  style: const TextStyle(
                                      color: AppTheme.textMuted, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
