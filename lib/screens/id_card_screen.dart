import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class IdCardScreen extends StatelessWidget {
  const IdCardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final data = auth.userData ?? {};

    final firstName = data['firstname'] ?? auth.userName ?? 'Student';
    final lastName = data['lastname'] ?? auth.userSurname ?? '';
    final fullName = '$firstName $lastName'.trim();

    final admissionNo = data['admission_no']?.toString() ?? 'N/A';
    final className = data['class_name']?.toString() ?? 'N/A';
    final sectionName = data['section_name']?.toString() ?? 'N/A';
    final bloodGroup = data['blood_group']?.toString() ?? 'N/A';
    final mobileNo = data['mobileno']?.toString() ?? 'N/A';
    final schoolName = 'Acadicron Public School'; // Can be fetched from settings if available

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital ID Card'),
        backgroundColor: const Color(0xFF242B31),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The ID Card Container
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 5,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF242B31),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            schoolName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Text(
                            'STUDENT ID CARD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Profile Photo
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                            style: const TextStyle(fontSize: 40, color: Colors.white),
                          ),
                        ),
                      ),
                    ),

                    // Student Details
                    Transform.translate(
                      offset: const Offset(0, -15),
                      child: Column(
                        children: [
                          Text(
                            fullName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF242B31),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow('ADMISSION NO', admissionNo),
                          _buildDetailRow('CLASS', '$className - $sectionName'),
                          _buildDetailRow('BLOOD GROUP', bloodGroup),
                          _buildDetailRow('EMERGENCY NO', mobileNo),
                        ],
                      ),
                    ),

                    // QR Code
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'SCAN TO VERIFY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    QrImageView(
                      data: 'ADM-$admissionNo',
                      version: QrVersions.auto,
                      size: 100.0,
                    ),
                    const SizedBox(height: 20),
                    
                    // Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: const Text(
                        'This card is the property of the school.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF242B31),
            ),
          ),
        ],
      ),
    );
  }
}
