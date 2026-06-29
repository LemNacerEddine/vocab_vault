import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/word.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  // حفظ الكلمة في قاعدة البيانات
  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final word = Word(
      word: _wordController.text.trim(),
      translation: _translationController.text.trim(),
    );

    await DatabaseHelper.instance.insertWord(word);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ كلمة "${word.word}" بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // العودة مع إشارة النجاح
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة كلمة جديدة'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // أيقونة توضيحية
              const Icon(
                Icons.translate,
                size: 60,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 24),

              // حقل الكلمة بالإنجليزية
              TextFormField(
                controller: _wordController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الكلمة بالإنجليزية',
                  hintText: 'مثال: Resilient',
                  prefixIcon: Icon(Icons.abc),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال الكلمة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // حقل الترجمة بالعربية
              TextFormField(
                controller: _translationController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'الترجمة بالعربية',
                  hintText: 'مثال: قادر على التكيف',
                  prefixIcon: Icon(Icons.language),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال الترجمة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // زر الحفظ
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveWord,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'جاري الحفظ...' : 'حفظ الكلمة',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
