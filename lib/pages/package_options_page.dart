import 'package:flutter/material.dart';
import '../models/package.dart';
import '../database/database_helper.dart';
import 'add_word_page.dart';
import 'add_word_group_page.dart';
import 'update_words_page.dart';
import 'view_list_page.dart';
import 'practice_page.dart';
import 'test_yourself_page.dart';

class PackageOptionsPage extends StatefulWidget {
  final Package package;

  const PackageOptionsPage({super.key, required this.package});

  @override
  State<PackageOptionsPage> createState() => _PackageOptionsPageState();
}

class _PackageOptionsPageState extends State<PackageOptionsPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  Package? _updatedPackage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpdatedPackage();
  }

  Future<void> _loadUpdatedPackage() async {
    try {
      final updatedPackage = await _databaseHelper.getPackage(widget.package.id!);
      setState(() {
        _updatedPackage = updatedPackage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPackage = _updatedPackage ?? widget.package;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Select Option"),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8DC71D),
              Colors.white,
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Package Info Card
              Card(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        const Color(0xFF8DC71D).withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8DC71D), Color(0xFF7AB51A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8DC71D).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            currentPackage.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPackage.name,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentPackage.description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8DC71D).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.text_fields,
                                        size: 14,
                                        color: const Color(0xFF8DC71D),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isLoading 
                                            ? 'Loading...' 
                                            : '${currentPackage.wordCount} words',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF8DC71D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'What would you like to do?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildOptionCard(
                      context,
                      'Add Word',
                      Icons.add_circle,
                      'Add single word',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AddWordPage(package: currentPackage),
                        ),
                      ),
                    ),
                    _buildOptionCard(
                      context,
                      'Update Words',
                      Icons.edit,
                      'Edit existing words',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => UpdateWordsPage(package: currentPackage),
                        ),
                      ),
                    ),
                    _buildOptionCard(
                      context,
                      'Add Word Group',
                      Icons.group_add,
                      'Add multiple words',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AddWordGroupPage(package: currentPackage),
                        ),
                      ),
                    ),
                    _buildOptionCard(
                      context,
                      'View List',
                      Icons.list_alt,
                      'Browse all words',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ViewListPage(package: currentPackage),
                        ),
                      ),
                    ),
                    _buildOptionCard(
                      context,
                      'Practice',
                      Icons.school,
                      'Learn and memorize',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PracticePage(package: currentPackage),
                        ),
                      ),
                    ),
                    _buildOptionCard(
                      context,
                      'Test Yourself',
                      Icons.quiz,
                      'Take a quiz',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TestYourselfPage(package: currentPackage),
                        ),
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

  Widget _buildOptionCard(
    BuildContext context,
    String title,
    IconData icon,
    String description,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFF8DC71D).withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8DC71D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: const Color(0xFF8DC71D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.construction,
              color: const Color(0xFF8DC71D),
            ),
            const SizedBox(width: 8),
            const Text('Coming Soon'),
          ],
        ),
        content: Text('$feature feature will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
} 