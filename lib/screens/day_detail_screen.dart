import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/practice_controller.dart';
import '../utils/app_date_utils.dart';

class DayDetailScreen extends StatefulWidget {
  const DayDetailScreen({super.key, required this.date});

  final DateTime date;

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  final _minutesController = TextEditingController();
  final _noteController = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_loaded) return;

    final log = context.read<PracticeController>().logForDate(widget.date);
    final minutes = ((log?.durationSeconds ?? 0) / 60).round();

    _minutesController.text = minutes.toString();
    _noteController.text = log?.note ?? '';
    _loaded = true;
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minutes = int.tryParse(_minutesController.text.trim());

    if (minutes == null || minutes < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的练习分钟数')));
      return;
    }

    setState(() => _saving = true);

    try {
      await context.read<PracticeController>().saveLogForDate(
        date: widget.date,
        durationSeconds: minutes * 60,
        note: _noteController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后再试')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = AppDateUtils.readableDate(widget.date);

    return Scaffold(
      appBar: AppBar(title: const Text('练习记录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(dateText, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '练习时长',
              suffixText: '分钟',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '今日练习心得',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
              hintText: '例如：长音气息更稳了，但高音区还需要慢练。',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
    );
  }
}
