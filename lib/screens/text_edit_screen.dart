import 'package:flutter/material.dart';

class TextEditScreen extends StatefulWidget {
  const TextEditScreen({
    super.key,
    required this.title,
    required this.initialText,
    required this.hintText,
    this.saveLabel = '保存',
    this.minLines = 10,
    this.maxLines,
    this.textInputAction = TextInputAction.newline,
  });

  final String title;
  final String initialText;
  final String hintText;
  final String saveLabel;
  final int minLines;
  final int? maxLines;
  final TextInputAction textInputAction;

  @override
  State<TextEditScreen> createState() => _TextEditScreenState();
}

class _TextEditScreenState extends State<TextEditScreen> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final text = _textController.text;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(onPressed: _submit, child: Text(widget.saveLabel)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _textController,
            autofocus: true,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.textInputAction == TextInputAction.done
                ? (_) => _submit()
                : null,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: widget.hintText,
              alignLabelWithHint: true,
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.save_outlined),
            label: Text(widget.saveLabel),
          ),
        ),
      ),
    );
  }
}
