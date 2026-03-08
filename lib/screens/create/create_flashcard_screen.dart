import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';

class CreateFlashcardScreen extends StatefulWidget {
  final String? selectedDeckId;

  const CreateFlashcardScreen({super.key, this.selectedDeckId});

  @override
  State<CreateFlashcardScreen> createState() => _CreateFlashcardScreenState();
}

class _CreateFlashcardScreenState extends State<CreateFlashcardScreen> {
  // Controllers
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  final _exampleController = TextEditingController();
  final _newDeckNameController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _isFetchingDecks = true;
  bool _isCreatingNewDeck = false;
  bool _isImporting = false;
  
  String? _selectedDeckId;
  List<Map<String, dynamic>> _myDecks = []; // Danh sách deck tải từ Firebase

  // Firebase
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Colors
  final Color primaryColor = const Color(0xFF3B8C88);
  final Color textDark = const Color(0xFF2D3142);
  final Color inputBg = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _fetchDecks();
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _exampleController.dispose();
    _newDeckNameController.dispose();
    super.dispose();
  }

  // 1. Tải danh sách Deck từ Firebase về
  Future<void> _fetchDecks() async {
    if (user == null) return;
    try {
      final snapshot = await _dbRef.child("decks").orderByChild("ownerId").equalTo(user!.uid).get();
      
      List<Map<String, dynamic>> loadedDecks = [];
      if (snapshot.exists && snapshot.value != null) {
        Map data = snapshot.value as Map;
        data.forEach((key, value) {
          loadedDecks.add({
            "id": key,
            "name": value["name"] ?? "Untitled",
            "cardCount": value["cardCount"] ?? 0
          });
        });
        // Sắp xếp theo tên A-Z
        loadedDecks.sort((a, b) => a["name"].toString().compareTo(b["name"].toString()));
      }

      if (mounted) {
        setState(() {
          _myDecks = loadedDecks;
          _isFetchingDecks = false;

          // Logic chọn mặc định:
          // Nếu có ID truyền vào (từ trang Home) -> Chọn nó
          if (widget.selectedDeckId != null && _myDecks.any((d) => d['id'] == widget.selectedDeckId)) {
            _selectedDeckId = widget.selectedDeckId;
            _isCreatingNewDeck = false;
          } 
          // Nếu không, chọn cái đầu tiên trong danh sách
          else if (_myDecks.isNotEmpty) {
            _selectedDeckId = _myDecks.first["id"];
            _isCreatingNewDeck = false;
          } 
          // Nếu chưa có deck nào -> Bắt buộc tạo mới
          else {
            _selectedDeckId = null;
            _isCreatingNewDeck = true;
          }
        });
      }
    } catch (e) {
      print("Lỗi tải decks: $e");
      if (mounted) setState(() => _isFetchingDecks = false);
    }
  }

  // 2. Xử lý Lưu
  void _handleSave() async {
    // Validate
    if (_frontController.text.trim().isEmpty || _backController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thiếu mặt trước hoặc mặt sau!"), backgroundColor: Colors.orange));
      return;
    }

    if (_isCreatingNewDeck && _newDeckNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên bộ thẻ mới!"), backgroundColor: Colors.orange));
      return;
    }

    if (!_isCreatingNewDeck && _selectedDeckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn một bộ thẻ!"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String uid = user!.uid;
      int now = DateTime.now().millisecondsSinceEpoch;
      String finalDeckId = "";

      // Xử lý Deck
      if (_isCreatingNewDeck) {
        // Tạo Deck mới
        String deckNameInput = _newDeckNameController.text.trim();
        DatabaseReference newDeckRef = _dbRef.child("decks").push();
        finalDeckId = newDeckRef.key!;
        
        await newDeckRef.set({
          "id": finalDeckId,
          "ownerId": uid,
          "name": deckNameInput,
          "cardCount": 1, 
          "createdAt": now,
        });
      } else {
        // Dùng Deck cũ
        finalDeckId = _selectedDeckId!;
        
        // Cộng thêm 1 vào cardCount
        final deckRef = _dbRef.child("decks/$finalDeckId/cardCount");
        await deckRef.runTransaction((mutableData) {
          if (mutableData == null) return Transaction.success(1);
          return Transaction.success((mutableData as int) + 1);
        });
      }

      // Lưu Card
      await _dbRef.child("cards").push().set({
        "deckId": finalDeckId,
        "ownerId": uid,
        "front": _frontController.text.trim(),
        "back": _backController.text.trim(),
        "example": _exampleController.text.trim(),
        "dueDate": now,
        "interval": 0,
        "easeFactor": 2.5,
        "status": "new"
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tạo thẻ thành công!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }

    } catch (e) {
      print("Lỗi lưu: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromExcel() async {
    if (_isCreatingNewDeck && _newDeckNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên bộ thẻ trước!"), backgroundColor: Colors.orange));
      return;
    }

    if (!_isCreatingNewDeck && _selectedDeckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn một bộ thẻ!"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isImporting = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      List<int> bytes;
      if (result.files.first.bytes != null) {
        bytes = result.files.first.bytes!;
      } else if (result.files.first.path != null) {
        bytes = File(result.files.first.path!).readAsBytesSync();
      } else {
        throw Exception("Không thể đọc file");
      }

      var excel = excel_pkg.Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        throw Exception("File Excel không có sheet nào");
      }

      String uid = user!.uid;
      int now = DateTime.now().millisecondsSinceEpoch;
      String finalDeckId = "";

      if (_isCreatingNewDeck) {
        String deckNameInput = _newDeckNameController.text.trim();
        DatabaseReference newDeckRef = _dbRef.child("decks").push();
        finalDeckId = newDeckRef.key!;
        
        await newDeckRef.set({
          "id": finalDeckId,
          "ownerId": uid,
          "name": deckNameInput,
          "cardCount": 0,
          "createdAt": now,
        });
      } else {
        finalDeckId = _selectedDeckId!;
      }

      int importedCount = 0;
      int skippedCount = 0;
      
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        for (var i = 1; i < sheet.maxRows; i++) {
          var row = sheet.row(i);
          if (row.isEmpty || row.length < 2) {
            skippedCount++;
            continue;
          }

          String front = row[0]?.value?.toString().trim() ?? "";
          String back = row[1]?.value?.toString().trim() ?? "";
          String example = row.length > 2 ? (row[2]?.value?.toString().trim() ?? "") : "";

          if (front.isEmpty || back.isEmpty) {
            skippedCount++;
            continue;
          }

          await _dbRef.child("cards").push().set({
            "deckId": finalDeckId,
            "ownerId": uid,
            "front": front,
            "back": back,
            "example": example,
            "dueDate": now,
            "interval": 0,
            "easeFactor": 2.5,
            "status": "new"
          });

          importedCount++;
        }
      }

      if (importedCount == 0) {
        throw Exception("Không có thẻ nào được import. Kiểm tra lại định dạng file.");
      }

      final deckRef = _dbRef.child("decks/$finalDeckId/cardCount");
      await deckRef.runTransaction((mutableData) {
        int currentCount = (mutableData ?? 0) as int;
        return Transaction.success(currentCount + importedCount);
      });

      if (mounted) {
        String message = "Đã import $importedCount thẻ thành công!";
        if (skippedCount > 0) {
          message += " ($skippedCount dòng bị bỏ qua)";
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
        Navigator.pop(context);
      }

    } catch (e) {
      print("Lỗi import Excel: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi import: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Tạo Thẻ Mới", style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isLoading 
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : TextButton(
                  onPressed: _handleSave,
                  child: Text("Lưu", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: Colors.grey[100], height: 1)),
      ),
      body: _isFetchingDecks 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // --- DECK SELECTOR (Dropdown) ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder_rounded, color: primaryColor),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _isCreatingNewDeck
                              // TRƯỜNG HỢP 1: Nhập tên mới
                              ? TextField(
                                  controller: _newDeckNameController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Nhập tên bộ thẻ mới...",
                                    labelText: "TẠO BỘ MỚI",
                                    labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)
                                  ),
                                )
                              // TRƯỜNG HỢP 2: Dropdown chọn có sẵn
                              : DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedDeckId,
                                    isExpanded: true,
                                    hint: const Text("Chọn bộ thẻ"),
                                    icon: const Icon(Icons.keyboard_arrow_down),
                                    items: [
                                      // List các bộ thẻ đã có
                                      ..._myDecks.map((deck) {
                                        return DropdownMenuItem<String>(
                                          value: deck["id"],
                                          child: Text(
                                            deck["name"], 
                                            style: TextStyle(color: textDark, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      
                                      // Item đặc biệt: Tạo bộ mới
                                      DropdownMenuItem<String>(
                                        value: "CREATE_NEW",
                                        child: Row(
                                          children: [
                                            Icon(Icons.add_circle_outline, color: primaryColor, size: 20),
                                            const SizedBox(width: 8),
                                            Text("Tạo bộ thẻ mới...", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      )
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == "CREATE_NEW") {
                                          _isCreatingNewDeck = true;
                                          _selectedDeckId = null;
                                        } else {
                                          _selectedDeckId = value;
                                        }
                                      });
                                    },
                                  ),
                                ),
                        ),
                        // Nút hủy tạo mới để quay về list
                        if (_isCreatingNewDeck && _myDecks.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _isCreatingNewDeck = false;
                                _selectedDeckId = _myDecks.first["id"];
                              });
                            },
                          )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Inputs
                  _buildInputSection("MẶT TRƯỚC (CÂU HỎI)", "VD: Ephemeral", 3, _frontController),
                  const SizedBox(height: 24),
                  _buildInputSection("MẶT SAU (ĐÁP ÁN)", "VD: Phù du, sớm nở tối tàn...", 4, _backController),
                  const SizedBox(height: 24),
                  _buildInputSection("VÍ DỤ (TÙY CHỌN)", "VD: Fashions are ephemeral.", 2, _exampleController),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text("Lưu Thẻ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isImporting ? null : _importFromExcel,
                      icon: _isImporting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file),
                      label: Text(_isImporting ? "Đang import..." : "Import từ Excel"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text("Định dạng file Excel:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("• Cột A: Mặt trước (bắt buộc)", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        Text("• Cột B: Mặt sau (bắt buộc)", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        Text("• Cột C: Ví dụ (tùy chọn)", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        Text("• Dòng đầu tiên sẽ bị bỏ qua (header)", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInputSection(String label, String hint, int lines, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: lines,
          minLines: 1,
          style: TextStyle(fontSize: 16, color: textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputBg,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}