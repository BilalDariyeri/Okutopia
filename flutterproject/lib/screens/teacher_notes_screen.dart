import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/teacher_note_service.dart';
import 'package:intl/intl.dart';

class TeacherNotesScreen extends StatefulWidget {
  const TeacherNotesScreen({super.key});

  @override
  State<TeacherNotesScreen> createState() => _TeacherNotesScreenState();
}

class _TeacherNotesScreenState extends State<TeacherNotesScreen> {
  final TeacherNoteService _teacherNoteService = TeacherNoteService();
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  
  List<Map<String, dynamic>> _notes = [];
  Map<String, dynamic>? _lastSessionStats;
  String? _studentName;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedStudent = authProvider.selectedStudent;
    
    if (selectedStudent == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lütfen önce bir öğrenci seçin.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _studentName = '${selectedStudent.firstName} ${selectedStudent.lastName}';
    });

    try {
      // Son oturum istatistiklerini getir
      final statsResponse = await _teacherNoteService.getStudentLastSessionStats(selectedStudent.id);
      
      // Notları getir
      final notesResponse = await _teacherNoteService.getStudentNotes(selectedStudent.id);
      
      if (!mounted) return;

      setState(() {
        // API response yapısını kontrol et ve normalize et
        if (statsResponse['success'] == true) {
          // Backend'den gelen response zaten normalize edilmiş olmalı
          final lastSessionData = statsResponse['lastSessionStats'];
          if (lastSessionData != null && lastSessionData is Map<String, dynamic>) {
            _lastSessionStats = lastSessionData;
          } else {
            _lastSessionStats = null;
          }
        } else {
          _lastSessionStats = null;
        }
        
        // Notları güvenli şekilde al
        if (notesResponse['success'] == true && notesResponse['notes'] != null) {
          _notes = List<Map<String, dynamic>>.from(notesResponse['notes']);
        } else {
          _notes = [];
        }
        
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _lastSessionStats = null;
        _notes = [];
      });
    }
  }

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir not yazın.')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedStudent = authProvider.selectedStudent;
    
    if (selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir öğrenci seçin.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Mevcut "Son Çalışma Yorumu" notunu kontrol et
      Map<String, dynamic>? existingNote;
      try {
        existingNote = _notes.firstWhere(
          (note) => note['title'] == 'Son Çalışma Yorumu',
        );
      } catch (e) {
        existingNote = null;
      }

      if (existingNote != null && existingNote['id'] != null) {
        // Mevcut notu güncelle
        await _teacherNoteService.updateNote(
          noteId: existingNote['id'],
          title: 'Son Çalışma Yorumu',
          content: _noteController.text.trim(),
          category: 'Oturum Yorumu',
        );
      } else {
        // Yeni not oluştur
        await _teacherNoteService.createNote(
          studentId: selectedStudent.id,
          title: 'Son Çalışma Yorumu',
          content: _noteController.text.trim(),
          priority: 'Normal',
          category: 'Oturum Yorumu',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not kaydedildi!'),
          backgroundColor: Colors.green,
        ),
      );

      _noteController.clear();
      _loadNotes(); // Notları yeniden yükle
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '$hours s $minutes dk';
    } else if (minutes > 0) {
      return '$minutes dk $secs sn';
    } else {
      return '$secs sn';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Öğretmen Notları'),
        backgroundColor: const Color(0xFF4834D4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotes,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotes,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Öğrenci Bilgisi
                      if (_studentName != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF4834D4),
                                child: Text(
                                  _studentName![0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _studentName!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Son Çalışma Özeti
                      if (_lastSessionStats != null && _lastSessionStats!['lastUpdated'] != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4CAF50),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.timer,
                                    color: Color(0xFF2E7D32),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Son Çalışma Özeti',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Toplam Süre: ${_formatTime((_lastSessionStats!['totalDurationSeconds'] as num?)?.toInt() ?? 0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              if (_lastSessionStats!['activities'] != null &&
                                  (_lastSessionStats!['activities'] as List).isNotEmpty)
                                ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Son Aktivite: ${(_lastSessionStats!['activities'] as List).last['activityTitle'] ?? 'Bilinmeyen'} (${_formatTime(((_lastSessionStats!['activities'] as List).last['durationSeconds'] as num?)?.toInt() ?? 0)})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              const SizedBox(height: 8),
                              if (_lastSessionStats!['lastUpdated'] != null)
                                Text(
                                  'Güncelleme: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(_lastSessionStats!['lastUpdated']))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Not Ekleme Alanı
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Öğretmen Yorumu / Notu',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _noteController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Öğrencinin son çalışması hakkında yorumunuzu buraya yazın...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveNote,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4834D4),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Notu Kaydet',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Geçmiş Notlar
                      const Text(
                        'Geçmiş Notlar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_notes.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.note_outlined, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz not eklenmemiş',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._notes.map((note) {
                          Color priorityColor;
                          switch (note['priority']) {
                            case 'Acil':
                              priorityColor = Colors.red;
                              break;
                            case 'Önemli':
                              priorityColor = Colors.orange;
                              break;
                            default:
                              priorityColor = Colors.blue;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  width: 4,
                                  color: priorityColor,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        note['title'] ?? 'Başlıksız',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: priorityColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        note['priority'] ?? 'Normal',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: priorityColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (note['category'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    note['category'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  note['content'] ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                if (note['createdAt'] != null)
                                  Text(
                                    DateFormat('dd.MM.yyyy HH:mm').format(
                                      DateTime.parse(note['createdAt']),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

