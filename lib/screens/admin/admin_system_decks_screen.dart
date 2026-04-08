import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import '../../models/app_models.dart';

class AdminSystemDecksScreen extends StatefulWidget {
  const AdminSystemDecksScreen({super.key});

  @override
  State<AdminSystemDecksScreen> createState() => _AdminSystemDecksScreenState();
}

class _AdminSystemDecksScreenState extends State<AdminSystemDecksScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  static const String systemOwnerId = 'system';

  void _showCreateDeckDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo bộ thẻ hệ thống'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Tên bộ thẻ', border: OutlineInputBorder()),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Mô tả (tùy chọn)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B8C88), foregroundColor: Colors.white),
            onPressed: () async {
              String name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _createSystemDeck(name, descCtrl.text.trim());
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSystemDeck(String name, String desc) async {
    try {
      DatabaseReference ref = _dbRef.child('decks').push();
      String deckId = ref.key!;
      await ref.set({
        'id': deckId,
        'ownerId': systemOwnerId,
        'name': name,
        'description': desc,
        'cardCount': 0,
        'isPublic': false,
        'isSystem': true,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo bộ thẻ hệ thống'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }

  void _showAddCardDialog(String deckId) {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    final exampleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm thẻ'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: frontCtrl, decoration: const InputDecoration(labelText: 'Mặt trước (từ/câu)', border: OutlineInputBorder()), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: backCtrl, decoration: const InputDecoration(labelText: 'Mặt sau (nghĩa)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: exampleCtrl, decoration: const InputDecoration(labelText: 'Ví dụ (tùy chọn)', border: OutlineInputBorder()), maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B8C88), foregroundColor: Colors.white),
            onPressed: () async {
              String front = frontCtrl.text.trim();
              String back = backCtrl.text.trim();
              if (front.isEmpty || back.isEmpty) return;
              Navigator.pop(ctx);
              await _addCardToSystemDeck(deckId, front, back, exampleCtrl.text.trim());
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCardToSystemDeck(String deckId, String front, String back, String example) async {
    try {
      int now = DateTime.now().millisecondsSinceEpoch;
      await _dbRef.child('cards').push().set({
        'ownerId': systemOwnerId,
        'deckId': deckId,
        'front': front,
        'back': back,
        'example': example,
        'dueDate': now,
        'interval': 0,
        'easeFactor': 2.5,
        'status': 'new',
      });

      // Update cardCount
      DataSnapshot snap = await _dbRef.child('decks/$deckId/cardCount').get();
      int count = snap.exists ? (snap.value as num).toInt() : 0;
      await _dbRef.child('decks/$deckId/cardCount').set(count + 1);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm thẻ'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteSystemDeck(String deckId, String deckName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bộ thẻ hệ thống', style: TextStyle(color: Colors.red)),
        content: Text('Xóa "$deckName" và toàn bộ thẻ bên trong?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _dbRef.child('decks/$deckId').remove();
      final cardsSnap = await _dbRef.child('cards').orderByChild('deckId').equalTo(deckId).get();
      if (cardsSnap.exists) {
        Map data = cardsSnap.value as Map;
        for (String cardId in data.keys) {
          await _dbRef.child('cards/$cardId').remove();
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bộ thẻ'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('Bộ thẻ hệ thống', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF3B8C88), size: 28),
            onPressed: _showCreateDeckDialog,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _dbRef.child('decks').orderByChild('ownerId').equalTo(systemOwnerId).onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.snapshot.value == null) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('Chưa có bộ thẻ hệ thống nào', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateDeckDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo bộ thẻ đầu tiên'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B8C88), foregroundColor: Colors.white),
                ),
              ]),
            );
          }

          Map data = snapshot.data!.snapshot.value as Map;
          List<Deck> decks = [];
          data.forEach((key, value) => decks.add(Deck.fromMap(key, value)));
          decks.sort((a, b) => a.name.compareTo(b.name));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              return _buildDeckTile(deck);
            },
          );
        },
      ),
    );
  }

  Widget _buildDeckTile(Deck deck) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.verified, color: Colors.blue, size: 24),
        ),
        title: Text(deck.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${deck.cardCount} thẻ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.blue),
            onPressed: () => _importExcelToSystemDeck(deck.id),
            tooltip: 'Import Excel',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF3B8C88)),
            onPressed: () => _showAddCardDialog(deck.id),
            tooltip: 'Thêm thẻ',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteSystemDeck(deck.id, deck.name),
            tooltip: 'Xóa bộ thẻ',
          ),
        ]),
        children: [
          _buildCardList(deck.id),
        ],
      ),
    );
  }

  Widget _buildCardList(String deckId) {
    return StreamBuilder(
      stream: _dbRef.child('cards').orderByChild('deckId').equalTo(deckId).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chưa có thẻ nào. Nhấn + để thêm.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }

        Map data = snapshot.data!.snapshot.value as Map;
        List<MapEntry> cards = data.entries.toList();

        return Column(
          children: cards.map((entry) {
            Map card = entry.value as Map;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.style, size: 18, color: Colors.grey),
              title: Text(card['front'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Text(card['back'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                onPressed: () => _deleteCard(entry.key, deckId),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _importExcelToSystemDeck(String deckId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) return;

      List<int> bytes;
      if (result.files.first.bytes != null) {
        bytes = result.files.first.bytes!;
      } else if (result.files.first.path != null) {
        bytes = File(result.files.first.path!).readAsBytesSync();
      } else {
        throw Exception('Không thể đọc file');
      }

      var excelFile = excel_pkg.Excel.decodeBytes(bytes);
      if (excelFile.tables.isEmpty) throw Exception('File không có sheet nào');

      int now = DateTime.now().millisecondsSinceEpoch;
      int importedCount = 0;
      int skippedCount = 0;

      for (var table in excelFile.tables.keys) {
        var sheet = excelFile.tables[table];
        if (sheet == null) continue;
        for (var i = 1; i < sheet.maxRows; i++) {
          var row = sheet.row(i);
          if (row.length < 2) { skippedCount++; continue; }
          String front = row[0]?.value?.toString().trim() ?? '';
          String back = row[1]?.value?.toString().trim() ?? '';
          String example = row.length > 2 ? (row[2]?.value?.toString().trim() ?? '') : '';
          if (front.isEmpty || back.isEmpty) { skippedCount++; continue; }

          await _dbRef.child('cards').push().set({
            'ownerId': systemOwnerId,
            'deckId': deckId,
            'front': front,
            'back': back,
            'example': example,
            'dueDate': now,
            'interval': 0,
            'easeFactor': 2.5,
            'status': 'new',
          });
          importedCount++;
        }
      }

      if (importedCount == 0) throw Exception('Không có thẻ nào hợp lệ trong file');

      // Update cardCount
      DataSnapshot snap = await _dbRef.child('decks/$deckId/cardCount').get();
      int count = snap.exists ? (snap.value as num).toInt() : 0;
      await _dbRef.child('decks/$deckId/cardCount').set(count + importedCount);

      if (mounted) {
        String msg = 'Đã import $importedCount thẻ!';
        if (skippedCount > 0) msg += ' ($skippedCount dòng bỏ qua)';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi import: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteCard(String cardId, String deckId) async {
    try {
      await _dbRef.child('cards/$cardId').remove();
      DataSnapshot snap = await _dbRef.child('decks/$deckId/cardCount').get();
      int count = snap.exists ? (snap.value as num).toInt() : 1;
      await _dbRef.child('decks/$deckId/cardCount').set((count - 1).clamp(0, 9999));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }
}
