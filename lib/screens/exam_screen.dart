import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _exams = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
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
      final response = await _apiClient.get('/student-exam/$studentId');
      setState(() {
        _exams = response['data'] ?? [];
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load exam results';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Results')),
      body: _isLoading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : _exams.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
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
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadExams();
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
          Icon(Icons.assignment_rounded, color: AppTheme.textMuted, size: 48),
          SizedBox(height: 16),
          Text('No exam results found',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadExams();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _exams.length,
        itemBuilder: (context, index) {
          final exam = _exams[index];
          final examName = exam['exam'] ?? exam['name'] ?? 'Exam';
          final subject = exam['subject_name'] ?? '';
          final marks = exam['get_marks']?.toString() ?? '-';
          final maxMarks = exam['max_marks']?.toString() ?? '-';
          final passingMarks = exam['passing_marks']?.toString() ?? '';
          final examResults = exam['exam_result'];

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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_rounded,
                          color: AppTheme.warning, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            examName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subject.isNotEmpty)
                            Text(
                              subject,
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // If exam has results, show them
                if (examResults != null && examResults is List) ...[
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  const SizedBox(height: 12),
                  ...examResults.map<Widget>((result) {
                    final subName =
                        result['subject_name'] ?? result['subject'] ?? '';
                    final obtained = result['get_marks']?.toString() ?? '-';
                    final max = result['max_marks']?.toString() ?? '-';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(subName,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ),
                          Text(
                            '$obtained / $max',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Marks: $marks / $maxMarks',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      if (passingMarks.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Pass: $passingMarks',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
