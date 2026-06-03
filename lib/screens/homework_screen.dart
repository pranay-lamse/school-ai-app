import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  final ApiClient _apiClient = ApiClient();
  List<_HomeworkItem> _homework = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final studentData = auth.userData;
    final classId = studentData?['class_id']?.toString();
    final sectionId = studentData?['section_id']?.toString();
    final studentSessionId = studentData?['student_session_id']?.toString();
    final sessionId = studentData?['session_id']?.toString();

    if (classId == null || sectionId == null) {
      setState(() {
        _error = 'Student class/section data not found';
        _isLoading = false;
      });
      return;
    }

    try {
      final queryParams = <String, String>{
        'selectedClass': classId,
        'selectedSection': sectionId,
        'page': '1',
        'perPage': '50',
      };
      if (studentSessionId != null) {
        queryParams['student_session_id'] = studentSessionId;
      }
      if (sessionId != null) {
        queryParams['current_session_id'] = sessionId;
      }

      final response = await _apiClient.get(
        '/homework-student',
        queryParams: queryParams,
      );

      final data = response['data'] as List<dynamic>? ?? [];
      final List<_HomeworkItem> items = [];

      for (var hw in data) {
        items.add(_HomeworkItem(
          id: hw['id']?.toString() ?? '',
          subjectName: hw['subject_name']?.toString() ?? '',
          subjectGroupName: hw['subject_group_name']?.toString() ?? '',
          className: hw['class']?.toString() ?? '',
          sectionName: hw['section']?.toString() ?? '',
          description: hw['description']?.toString() ?? '',
          homeworkDate: hw['homework_date']?.toString() ?? '',
          submitDate: hw['submit_date']?.toString() ?? '',
          evaluationDate: hw['evaluation_date']?.toString() ?? '',
          staffName:
              '${hw['staff_name'] ?? ''} ${hw['staff_surname'] ?? ''}'.trim(),
          document: hw['document']?.toString(),
          isCompleted: (hw['homework_evaluation_id'] ?? 0) != 0,
        ));
      }

      setState(() {
        _homework = items;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load homework';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty || dateStr == '0000-00-00') return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  bool _isOverdue(String submitDateStr) {
    if (submitDateStr.isEmpty || submitDateStr == '0000-00-00') return false;
    try {
      final submitDate = DateTime.parse(submitDateStr);
      return DateTime.now().isAfter(submitDate);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Homework')),
      body: _isLoading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : _homework.isEmpty
                  ? _buildEmpty()
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
              onPressed: _loadHomework,
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
          Icon(Icons.menu_book_rounded, color: AppTheme.textMuted, size: 48),
          SizedBox(height: 16),
          Text('No homework assigned',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Count summaries
    final completed = _homework.where((h) => h.isCompleted).length;
    final incomplete = _homework.where((h) => !h.isCompleted).length;

    return RefreshIndicator(
      onRefresh: _loadHomework,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary row
          _buildSummaryRow(completed, incomplete),
          const SizedBox(height: 16),
          // Homework cards
          ..._homework.map((hw) => _buildHomeworkCard(hw)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(int completed, int incomplete) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF28A745), Color(0xFF34D058)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(completed.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Completed',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8A317), Color(0xFFF0C040)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(incomplete.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Incomplete',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7A5AF8), Color(0xFF9F7AEA)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(_homework.length.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Total',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeworkCard(_HomeworkItem hw) {
    final overdue = !hw.isCompleted && _isOverdue(hw.submitDate);

    Color statusColor;
    String statusText;
    Color statusBg;
    IconData statusIcon;

    if (hw.isCompleted) {
      statusText = 'Completed';
      statusColor = const Color(0xFF15803D);
      statusBg = const Color(0xFFDCFCE7);
      statusIcon = Icons.check_circle_rounded;
    } else if (overdue) {
      statusText = 'Overdue';
      statusColor = const Color(0xFF991B1B);
      statusBg = const Color(0xFFFEE2E2);
      statusIcon = Icons.warning_rounded;
    } else {
      statusText = 'Incomplete';
      statusColor = const Color(0xFF854D0E);
      statusBg = const Color(0xFFFEF9C3);
      statusIcon = Icons.pending_rounded;
    }

    return GestureDetector(
      onTap: () => _showHomeworkDetail(hw),
      child: Container(
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
            // Header: subject + status
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: AppTheme.info, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hw.subjectName.isNotEmpty)
                        Text(
                          hw.subjectName,
                          style: const TextStyle(
                            color: AppTheme.primaryPurple,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        'Class ${hw.className} - ${hw.sectionName}',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Description preview
            if (hw.description.isNotEmpty)
              Text(
                _stripHtml(hw.description),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),

            // Dates row
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DateChip(
                      icon: Icons.calendar_today,
                      label: 'Assigned',
                      date: _formatDate(hw.homeworkDate),
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateChip(
                      icon: Icons.event,
                      label: 'Due',
                      date: _formatDate(hw.submitDate),
                      color: overdue ? AppTheme.error : AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),

            // Created by
            if (hw.staffName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      color: AppTheme.textMuted, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    hw.staffName,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  void _showHomeworkDetail(_HomeworkItem hw) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Homework Details',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subject
                  _DetailItem(
                      label: 'Subject', value: hw.subjectName),
                  _DetailItem(
                      label: 'Class',
                      value: '${hw.className} - ${hw.sectionName}'),
                  _DetailItem(
                      label: 'Homework Date',
                      value: _formatDate(hw.homeworkDate)),
                  _DetailItem(
                      label: 'Submission Date',
                      value: _formatDate(hw.submitDate)),
                  _DetailItem(
                      label: 'Evaluation Date',
                      value: _formatDate(hw.evaluationDate)),
                  _DetailItem(label: 'Created By', value: hw.staffName),
                  _DetailItem(
                      label: 'Status',
                      value: hw.isCompleted ? 'Completed' : 'Incomplete'),

                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.cardBorder),
                  const SizedBox(height: 12),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hw.description.isNotEmpty
                          ? _stripHtml(hw.description)
                          : 'No description provided.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeworkItem {
  final String id;
  final String subjectName;
  final String subjectGroupName;
  final String className;
  final String sectionName;
  final String description;
  final String homeworkDate;
  final String submitDate;
  final String evaluationDate;
  final String staffName;
  final String? document;
  final bool isCompleted;

  _HomeworkItem({
    required this.id,
    required this.subjectName,
    required this.subjectGroupName,
    required this.className,
    required this.sectionName,
    required this.description,
    required this.homeworkDate,
    required this.submitDate,
    required this.evaluationDate,
    required this.staffName,
    this.document,
    required this.isCompleted,
  });
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  final Color color;

  const _DateChip({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500)),
              Text(date,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'N/A',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
