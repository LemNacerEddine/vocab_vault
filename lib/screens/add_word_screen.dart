import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import '../services/dictionary_service.dart';
import '../services/unsplash_service.dart';

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
  bool _isSearching = false;
  DictionaryResult? _dictionaryResult;
  List<UnsplashImage> _images = [];
  UnsplashImage? _selectedImage;
  String? _searchError;

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  // البحث عن الكلمة في القاموس + جلب الصور
  Future<void> _searchWord() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      setState(() => _searchError = 'الرجاء إدخال الكلمة أولاً');
      return;
    }

    // التحقق من وجود الكلمة مسبقاً
    final exists = await DatabaseHelper.instance.wordExists(word);
    if (exists) {
      setState(() => _searchError = 'هذه الكلمة موجودة مسبقاً في قائمتك!');
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _dictionaryResult = null;
      _images = [];
      _selectedImage = null;
    });

    // جلب البيانات من القاموس والصور بالتوازي
    final results = await Future.wait([
      DictionaryService.lookupWord(word),
      UnsplashService.searchImages(word),
    ]);

    final dictResult = results[0] as DictionaryResult?;
    final imageResults = results[1] as List<UnsplashImage>;

    setState(() {
      _isSearching = false;
      _dictionaryResult = dictResult;
      _images = imageResults;

      // اختيار أول صورة تلقائياً
      if (imageResults.isNotEmpty) {
        _selectedImage = imageResults[0];
      }

      if (dictResult == null && imageResults.isEmpty) {
        _searchError =
            'لم يتم العثور على الكلمة. تأكد من الإملاء أو اتصال الإنترنت.\nيمكنك حفظ الكلمة يدوياً بإدخال الترجمة والضغط على حفظ.';
      }
    });
  }

  // حفظ الكلمة في قاعدة البيانات
  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final word = Word(
      word: _wordController.text.trim(),
      translation: _translationController.text.trim(),
      definition: _dictionaryResult?.definition,
      example: _dictionaryResult?.example,
      phonetic: _dictionaryResult?.phonetic,
      audioUrl: _dictionaryResult?.audioUrl,
      partOfSpeech: _dictionaryResult?.partOfSpeech,
      imageUrl: _selectedImage?.regularUrl,
      imageDescription: _selectedImage?.description,
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
      Navigator.pop(context, true);
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
      body: SingleChildScrollView(
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

              // حقل الكلمة بالإنجليزية مع زر البحث
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
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
                      onFieldSubmitted: (_) => _searchWord(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // زر البحث
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _searchWord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // رسالة الخطأ
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _searchError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),

              // نتيجة البحث من القاموس
              if (_dictionaryResult != null) _buildDictionaryResultCard(),

              // عرض الصور من Unsplash
              if (_images.isNotEmpty) _buildImageSelector(),

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

  // بطاقة عرض نتيجة البحث من القاموس
  Widget _buildDictionaryResultCard() {
    final result = _dictionaryResult!;
    return Card(
      elevation: 3,
      color: Colors.deepPurple.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان ونوع الكلمة
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'تم العثور على الكلمة!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                if (result.partOfSpeech != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.partOfSpeech!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(),

            // النطق الصوتي
            if (result.phonetic != null) ...[
              Row(
                children: [
                  const Icon(Icons.volume_up,
                      size: 18, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text(
                    result.phonetic!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // التعريف
            if (result.definition != null) ...[
              const Text(
                'Definition:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result.definition!,
                style: const TextStyle(fontSize: 14),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 8),
            ],

            // المثال
            if (result.example != null) ...[
              const Text(
                'Example:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Text(
                  '"${result.example!}"',
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // عرض الصور من Unsplash مع إمكانية الاختيار
  Widget _buildImageSelector() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: Colors.deepPurple.shade300),
                const SizedBox(width: 8),
                const Text(
                  'اختر صورة توضيحية',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final image = _images[index];
                  final isSelected = _selectedImage?.id == image.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImage = isSelected ? null : image;
                      });
                    },
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              isSelected ? Colors.deepPurple : Colors.grey[300]!,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: image.smallUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image),
                            ),
                            if (isSelected)
                              Container(
                                color: Colors.deepPurple.withOpacity(0.3),
                                child: const Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_selectedImage != null && _selectedImage!.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _selectedImage!.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
