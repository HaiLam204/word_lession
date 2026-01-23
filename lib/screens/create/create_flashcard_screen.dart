import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class CreateFlashcardScreen extends StatefulWidget {
  final String? selectedDeckId;
  final String? selectedDeckName;

  const CreateFlashcardScreen({
    super.key,
    this.selectedDeckId,
    this.selectedDeckName,
  });

  @override
  State<CreateFlashcardScreen> createState() => _CreateFlashcardScreenState();
}

class _CreateFlashcardScreenState extends State<CreateFlashcardScreen> {
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  final _exampleController = TextEditingController();
  final _deckNameController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  bool _isLoading = false;
  late String _selectedDeckId;
  late String _selectedDeckName;
  bool _isNewDeck = true;

  @override
  void initState() {
    super.initState();
    _selectedDeckId = widget.selectedDeckId ?? '';
    _selectedDeckName = widget.selectedDeckName ?? '';
    _isNewDeck = widget.selectedDeckId == null;
    
    if (!_isNewDeck) {
      _deckNameController.text = _selectedDeckName;
    }
  }

  void _createCard() async {
    if (_frontController.text.isEmpty || _backController.text.isEmpty) {
      _showSnackBar("Vui lòng điền tất cả thông tin bắt buộc", Colors.red);
      return;
    }

    if (_isNewDeck && _deckNameController.text.isEmpty) {
      _showSnackBar("Vui lòng nhập tên bộ thẻ", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String deckId = _selectedDeckId;
      
      if (_isNewDeck) {
        deckId = _deckNameController.text.toLowerCase().replaceAll(' ', '_');
        final deckSnapshot = await _dbRef.child("decks/$deckId").get();
        
        if (!deckSnapshot.exists) {
          int now = DateTime.now().millisecondsSinceEpoch;
          await _dbRef.child("decks/$deckId").set({
            'id': deckId,
            'name': _deckNameController.text,
            'ownerId': user!.uid,
            'createdAt': now,
            'cardCount': 0,
            'description': '',
            'isPublic': false,
          });
        }
      }
      int now = DateTime.now().millisecondsSinceEpoch;
      String cardId = _dbRef.child("cards").push().key ?? '';
      
      await _dbRef.child("cards/$cardId").set({
        'id': cardId,
        'front': _frontController.text.trim(),
        'back': _backController.text.trim(),
        'example': _exampleController.text.trim(),
        'deckId': deckId,
        'ownerId': user!.uid,
        'createdAt': now,
        'dueDate': now,
        'interval': 0,
        'easeFactor': 2.5,
        'repetitions': 0,
        'status': 'new',
      });
      final decksSnapshot = await _dbRef.child("decks/$deckId/cardCount").get();
      int currentCount = decksSnapshot.exists ? (decksSnapshot.value as int) : 0;
      await _dbRef.child("decks/$deckId/cardCount").set(currentCount + 1);

      if (mounted) {
        _showSnackBar("Tạo flashcard thành công!", Colors.green);
        _clearFields();
      }
    } catch (e) {
      _showSnackBar("Lỗi: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearFields() {
    _frontController.clear();
    _backController.clear();
    _exampleController.clear();
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Tạo Flashcard", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isNewDeck) ...[
              const Text("Tên bộ thẻ", 
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF121716))),
              const SizedBox(height: 8),
              _buildTextField(_deckNameController, "Ví dụ: Tiếng Anh cơ bản"),
              const SizedBox(height: 24),
            ] else
              _buildDeckInfo(),

            const Text("Mặt trước (Từ vựng)", 
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF121716))),
            const SizedBox(height: 8),
            _buildTextField(_frontController, "Nhập từ vựng hoặc câu hỏi", maxLines: 3),
            const SizedBox(height: 24),

            const Text("Mặt sau (Định nghĩa)", 
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF121716))),
            const SizedBox(height: 8),
            _buildTextField(_backController, "Nhập định nghĩa hoặc câu trả lời", maxLines: 3),
            const SizedBox(height: 24),

            const Text("Ví dụ (Tùy chọn)", 
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF121716))),
            const SizedBox(height: 8),
            _buildTextField(_exampleController, "Nhập ví dụ sử dụng từ này", maxLines: 2),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B8C88),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                  shadowColor: const Color(0xFF3B8C88).withOpacity(0.4),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Tạo Flashcard", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA0AFAC)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE5E3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE5E3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B8C88), width: 2),
        ),
      ),
    );
  }

  Widget _buildDeckInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF3B8C88).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B8C88).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder, color: Color(0xFF3B8C88), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Bộ thẻ hiện tại",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(_selectedDeckName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3B8C88))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _exampleController.dispose();
    _deckNameController.dispose();
    super.dispose();
  }
}