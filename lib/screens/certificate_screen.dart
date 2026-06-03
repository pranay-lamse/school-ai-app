import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _certificates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.get('/certificate');
      setState(() {
        _certificates = response['data'] ?? [];
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load certificates';
        _isLoading = false;
      });
    }
  }

  void _generateCertificate(dynamic certificate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CertificateViewScreen(
          certificateId: certificate['id'].toString(),
          certificateName: certificate['certificate_name']?.toString() ?? 'Certificate',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Certificates')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.error, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style:
                              const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCertificates,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _certificates.isEmpty
                  ? const Center(
                      child: Text('No certificates available',
                          style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _certificates.length,
                      itemBuilder: (context, index) {
                        final cert = _certificates[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.workspace_premium,
                                  color: AppTheme.primaryPurple),
                            ),
                            title: Text(
                              cert['certificate_name'] ?? 'Unknown Certificate',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => _generateCertificate(cert),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Generate'),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class CertificateViewScreen extends StatefulWidget {
  final String certificateId;
  final String certificateName;

  const CertificateViewScreen({
    super.key,
    required this.certificateId,
    required this.certificateName,
  });

  @override
  State<CertificateViewScreen> createState() => _CertificateViewScreenState();
}

class _CertificateViewScreenState extends State<CertificateViewScreen> {
  final ApiClient _apiClient = ApiClient();
  String? _htmlContent;
  bool _isLoading = true;
  String? _error;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _fetchCertificateHtml();
  }

  Future<void> _fetchCertificateHtml() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final studentData = auth.userData;
    final studentId = studentData?['id']?.toString();
    final classId = studentData?['class_id']?.toString();

    if (studentId == null || classId == null) {
      setState(() {
        _error = 'Student details not found';
        _isLoading = false;
      });
      return;
    }

    try {
      final payload = [
        {'student_id': studentId}
      ];

      final body = {
        'data': jsonEncode(payload),
        'class_id': classId,
        'certificate_id': widget.certificateId,
      };

      final response = await _apiClient.post(
        '/certificate-view-generate/${widget.certificateId}',
        body,
      );

      setState(() {
        _htmlContent = response['data'] ?? '';
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to generate certificate';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    if (_htmlContent == null || _isDownloading) return;
    
    setState(() => _isDownloading = true);
    
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return await Printing.convertHtml(
            format: format,
            html: _htmlContent!,
          );
        },
        name: '${widget.certificateName}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate PDF')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.certificateName),
        actions: [
          if (_htmlContent != null)
            IconButton(
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _downloadPdf,
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.error, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style:
                              const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _fetchCertificateHtml();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.white,
                      ),
                      child: Html(
                        data: _htmlContent,
                        style: {
                          "body": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                          ),
                        },
                      ),
                    ),
                  ),
                ),
    );
  }
}
