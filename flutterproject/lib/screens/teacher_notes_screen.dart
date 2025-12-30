import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/student_selection_provider.dart';
import '../services/teacher_note_service.dart';
import '../models/teacher_note_model.dart';

class TeacherNotesScreen extends StatefulWidget {
  const TeacherNotesScreen({super.key});

  @override
  State<TeacherNotesScreen> createState() => _TeacherNotesScreenState();
}

class _TeacherNotesScreenState extends State<TeacherNotesScreen> {
  final TeacherNoteService _noteService = TeacherNoteService();
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Kategoriler
  static const List<String> _categories = ['Önemli', 'Dikkat Et', 'Diğer'];
  static const List<String> _priorities = ['Normal', 'Önemli', 'Acil'];
  static const Map<String, Color> _categoryColors = {
    'Önemli': Color(0xFFFF6B6B),
    'Dikkat Et': Color(0xFFFFA726),
    'Diğer': Color(0xFF9E9E9E),
  };
  static const Map<String, IconData> _categoryIcons = {
    'Önemli': Icons.priority_high,
    'Dikkat Et': Icons.warning_amber_rounded,
    'Diğer': Icons.note_outlined,
  };

  List<TeacherNote> _notes = [];
  Map<String, dynamic>? _lastEmail;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEmailExpanded = false;
  bool _showNewNoteDialog = false;
  final TextEditingController _titleController = TextEditingController();
  String? _selectedCategory = 'Diğer'; // Varsayılan kategori
  String? _selectedPriority = 'Normal'; // Varsayılan öncelik
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;

    if (selectedStudent == null) {
      setState(() {
        _errorMessage = 'Lütfen önce bir öğrenci seçin.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Son veli maili ve notları paralel olarak yükle
      final results = await Future.wait([
        _noteService.getLastEmailToParent(selectedStudent.id),
        _noteService.getStudentNotes(selectedStudent.id, teacherId: userProfileProvider.user?.id),
      ]);

      final emailResult = results[0];
      final notesResult = results[1];

      if (mounted) {
        setState(() {
          _lastEmail = emailResult['email'] != null ? emailResult : null;
          
          // Notları parse et
          if (notesResult['success'] == true && notesResult['notes'] != null) {
            _notes = (notesResult['notes'] as List)
                .map((note) => TeacherNote.fromJson(note))
                .toList();
            // Tarihe göre sırala (yeniden eskiye)
            _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          } else {
            _notes = [];
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _noteController.text.trim();
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen not başlığı girin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen not içeriği girin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context, listen: false);
    final selectedStudent = studentSelectionProvider.selectedStudent;

    if (selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir öğrenci seçin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await _noteService.createNote(
        studentId: selectedStudent.id,
        title: title,
        content: content,
        category: _selectedCategory,
        priority: _selectedPriority,
        teacherId: Provider.of<UserProfileProvider>(context, listen: false).user?.id,
      );

      if (result['success'] == true) {
        _titleController.clear();
        _noteController.clear();
        setState(() {
          _showNewNoteDialog = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not başarıyla kaydedildi!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Notları yeniden yükle
        await _loadData();
        
        // Scroll'u en üste kaydır
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Not kaydedilemedi.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildLastEmailCard() {
    if (_lastEmail == null || _lastEmail!['email'] == null) {
      return const SizedBox.shrink();
    }

    final email = _lastEmail!['email'];
    final emailContent = email['content']?.toString() ?? email['htmlContent']?.toString() ?? '';
    final sentAt = email['sentAt'] != null
        ? DateTime.tryParse(email['sentAt'].toString())
        : null;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  color: Colors.amber.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Veliye Gönderilen Son Rapor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      if (sentAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Gönderilme: ${sentAt.day}.${sentAt.month}.${sentAt.year} ${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isEmailExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.amber.shade700,
                  ),
                  onPressed: () {
                    setState(() {
                      _isEmailExpanded = !_isEmailExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          if (_isEmailExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  emailContent.length > 500
                      ? '${emailContent.substring(0, 500)}...'
                      : emailContent,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C2C2C),
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    if (_notes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz not eklenmemiş',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Notları kategoriye göre grupla
    final Map<String, List<TeacherNote>> groupedNotes = {};
    for (var note in _notes) {
      final category = note.category ?? 'Diğer';
      if (!groupedNotes.containsKey(category)) {
        groupedNotes[category] = [];
      }
      groupedNotes[category]!.add(note);
    }

    // Kategorileri öncelik sırasına göre sırala
    final sortedCategories = _categories.where((cat) => groupedNotes.containsKey(cat)).toList();
    // Kategoride olmayan notları "Diğer"e ekle
    for (var note in _notes) {
      final category = note.category ?? 'Diğer';
      if (!_categories.contains(category)) {
        if (!groupedNotes.containsKey('Diğer')) {
          groupedNotes['Diğer'] = [];
        }
        if (!groupedNotes['Diğer']!.contains(note)) {
          groupedNotes['Diğer']!.add(note);
        }
      }
    }
    // "Diğer" kategorisi yoksa ekle
    if (!sortedCategories.contains('Diğer') && groupedNotes.containsKey('Diğer')) {
      sortedCategories.add('Diğer');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedCategories.length,
      itemBuilder: (context, categoryIndex) {
        final category = sortedCategories[categoryIndex];
        final categoryNotes = groupedNotes[category] ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kategori başlığı
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _categoryColors[category]?.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _categoryColors[category] ?? Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryIcons[category] ?? Icons.note_outlined,
                          size: 18,
                          color: _categoryColors[category] ?? Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _categoryColors[category] ?? Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _categoryColors[category] ?? Colors.grey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${categoryNotes.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Kategori notları
            ...categoryNotes.map((note) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _categoryColors[category]?.withOpacity(0.3) ?? Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C2C2C),
                            ),
                          ),
                        ),
                        Text(
                          note.formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      note.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2C2C2C),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ],
        );
      },
    );
  }

  Widget _buildNewNoteDialog() {
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context);
    final selectedStudent = studentSelectionProvider.selectedStudent;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve Kapat butonu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Yeni Not',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _showNewNoteDialog = false;
                        _titleController.clear();
                        _noteController.clear();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Öğrenci (Read-only)
              const Text(
                'Öğrenci *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedStudent?.fullName ?? 'Öğrenci seçilmedi',
                        style: TextStyle(
                          fontSize: 15,
                          color: selectedStudent != null ? Colors.black87 : Colors.grey[600],
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Not Başlığı
              const Text(
                'Not Başlığı *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Not başlığını girin...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4834D4), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              
              // Not İçeriği
              const Text(
                'Not İçeriği *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Not içeriğini girin...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4834D4), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              
              // Öncelik ve Kategori yan yana
              Row(
                children: [
                  // Öncelik
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Öncelik',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedPriority,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                            items: _priorities.map((String priority) {
                              return DropdownMenuItem<String>(
                                value: priority,
                                child: Text(
                                  priority,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedPriority = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Kategori
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kategori',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                            items: _categories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(
                                  category,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedCategory = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _showNewNoteDialog = false;
                              _titleController.clear();
                              _noteController.clear();
                            });
                          },
                    child: const Text(
                      'İptal',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Kaydet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentSelectionProvider = Provider.of<StudentSelectionProvider>(context);
    final selectedStudent = studentSelectionProvider.selectedStudent;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text(
              'Öğretmen Notları',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF4834D4),
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4834D4)),
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4834D4),
                            ),
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    )
                  : selectedStudent == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Lütfen önce bir öğrenci seçin.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Son veli maili kartı
                            _buildLastEmailCard(),
                            
                            // Notlar listesi
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_notes.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                        child: Row(
                                          children: [
                                            const Text(
                                              'Geçmiş Notlar',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2C2C2C),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              'Toplam: ${_notes.length}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    _buildNotesList(),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Yeni Not Ekle butonu
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showNewNoteDialog = true;
                                    });
                                  },
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  label: const Text(
                                    'Yeni Not Ekle',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4834D4),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
        // Yeni Not Dialog
        if (_showNewNoteDialog) _buildNewNoteDialog(),
      ],
    );
  }
}
