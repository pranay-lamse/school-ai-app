import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  final AuthService auth;
  const ProfileScreen({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    final data = auth.userData ?? {};
    final name = '${data['firstname'] ?? auth.userName ?? ''} ${data['lastname'] ?? auth.userSurname ?? ''}'.trim();
    final role = auth.role ?? 'student';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassCard,
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name.isNotEmpty ? name : 'Student',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Personal Information
            _SectionCard(
              title: 'Personal Information',
              icon: Icons.person_outline,
              items: [
                _InfoRow('Admission No', data['admission_no']),
                _InfoRow('Roll No', data['roll_no']),
                _InfoRow('Date of Birth', data['dob']),
                _InfoRow('Gender', data['gender']),
                _InfoRow('Blood Group', data['blood_group']),
                _InfoRow('Religion', data['religion']),
                _InfoRow('Mobile', data['mobileno']),
                _InfoRow('Email', data['email']),
                _InfoRow('Address', data['current_address']),
              ],
            ),
            const SizedBox(height: 16),

            // Academic Information
            _SectionCard(
              title: 'Academic Information',
              icon: Icons.school_outlined,
              items: [
                _InfoRow('Class', data['class_name']),
                _InfoRow('Section', data['section_name']),
                _InfoRow('Admission Date', data['admission_date']),
              ],
            ),
            const SizedBox(height: 16),

            // Guardian Information
            _SectionCard(
              title: 'Guardian Information',
              icon: Icons.family_restroom_outlined,
              items: [
                _InfoRow('Father Name', data['father_name']),
                _InfoRow('Father Phone', data['father_phone']),
                _InfoRow('Mother Name', data['mother_name']),
                _InfoRow('Mother Phone', data['mother_phone']),
                _InfoRow('Guardian Name', data['guardian_name']),
                _InfoRow('Guardian Phone', data['guardian_phone']),
                _InfoRow('Guardian Email', data['guardian_email']),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final dynamic value;
  _InfoRow(this.label, this.value);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoRow> items;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out null/empty values
    final filteredItems = items
        .where((item) =>
            item.value != null &&
            item.value.toString().isNotEmpty &&
            item.value.toString() != 'null')
        .toList();

    if (filteredItems.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              Icon(icon, color: AppTheme.primaryPurple, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...filteredItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value.toString(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
