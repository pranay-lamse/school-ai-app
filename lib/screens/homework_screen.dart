import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
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
  List<dynamic> _homework = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final studentData = auth.userData;
    final classId = studentData?['class_id']?.toString();
    final sectionId = studentData?['section_id']?.toString();
    final studentSessionId = studentData?['student_session_id']?.toString();

    try {
      final queryParams = <String, String>{};
      if (classId != null) queryParams['class_id'] = classId;
      if (sectionId != null) queryParams['section_id'] = sectionId;
      if (studentSessionId != null) {
        queryParams['student_session_id'] = studentSessionId;
      }

      final response = await _apiClient.get(
        '/homework-student',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      setState(() {
        _homework = response['data'] ?? [];
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
                  : _buildList(),
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
            height: 90,
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
                _loadHomework();
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
          Icon(Icons.menu_book_rounded, color: AppTheme.textMuted, size: 48),
          SizedBox(height: 16),
          Text('No homework assigned',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadHomework();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _homework.length,
        itemBuilder: (context, index) {
          final hw = _homework[index];
          final title = hw['description'] ?? 'Homework';
          final subject = hw['subject_name'] ?? hw['name'] ?? '';
          final date = hw['homework_date'] ?? '';
          final submitDate = hw['submit_date'] ?? '';
          final className = hw['class'] ?? '';
          final sectionName = hw['section'] ?? '';

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
                          if (subject.isNotEmpty)
                            Text(
                              subject,
                              style: const TextStyle(
                                color: AppTheme.primaryPurple,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (date.isNotEmpty) ...[
                      const Icon(Icons.calendar_today,
                          color: AppTheme.textMuted, size: 13),
                      const SizedBox(width: 4),
                      Text(date,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12)),
                    ],
                    if (submitDate.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.schedule,
                          color: AppTheme.warning, size: 13),
                      const SizedBox(width: 4),
                      Text('Due: $submitDate',
                          style: const TextStyle(
                              color: AppTheme.warning, fontSize: 12)),
                    ],
                  ],
                ),
                if (className.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Class $className - Section $sectionName',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
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
