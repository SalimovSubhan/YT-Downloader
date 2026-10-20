import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YT Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.red.shade700,
          surface: const Color(0xFF1E1E1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DownloaderPage(),
    );
  }
}

class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});

  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage> {
  final _urlController = TextEditingController();
  String _quality = 'Лучшее качество';
  String _browser = 'safari';
  bool _loading = false;
  String _status = '';
  bool _isError = false;
  double? _progress; // null = скрыт, 0..1 = прогресс
  String _progressLabel = '';

  final _browsers = ['safari', 'chrome', 'firefox', 'brave'];

  final _qualities = [
    'Лучшее качество',
    '1080p',
    '720p',
    '480p',
    '360p',
    'Только аудио (MP3)',
  ];

  static final _progressRe = RegExp(r'\[download\]\s+([\d.]+)%\s+of\s+(\S+)\s+at\s+(\S+)');

  List<String> _buildCmd(String url) {
    const yt = '/opt/homebrew/bin/yt-dlp';
    final out = '${Platform.environment['HOME']}/Downloads/%(title)s.%(ext)s';
    final cookies = ['--cookies-from-browser', _browser];

    if (_quality == 'Только аудио (MP3)') {
      return [yt, ...cookies, '-x', '--audio-format', 'mp3', '-o', out, url];
    }

    const fmts = {
      'Лучшее качество': 'bestvideo+bestaudio/best',
      '1080p': 'bestvideo[height<=1080]+bestaudio/best[height<=1080]',
      '720p': 'bestvideo[height<=720]+bestaudio/best[height<=720]',
      '480p': 'bestvideo[height<=480]+bestaudio/best[height<=480]',
      '360p': 'bestvideo[height<=360]+bestaudio/best[height<=360]',
    };

    return [
      yt, ...cookies, '-f', fmts[_quality]!,
      '--merge-output-format', 'mp4',
      '-o', out, url,
    ];
  }

  Future<void> _download() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _status = 'Вставьте ссылку на видео!';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Загружаю...';
      _isError = false;
      _progress = 0;
      _progressLabel = '';
    });

    try {
      final cmd = _buildCmd(url);
      final process = await Process.start(cmd.first, cmd.sublist(1));

      final stderr = StringBuffer();

      process.stdout.transform(utf8.decoder).listen((chunk) {
        for (final line in chunk.split('\n')) {
          final m = _progressRe.firstMatch(line);
          if (m != null) {
            final pct = double.tryParse(m.group(1)!) ?? 0;
            setState(() {
              _progress = pct / 100;
              _progressLabel = '${m.group(1)}% · ${m.group(2)} · ${m.group(3)}/s';
            });
          }
        }
      });

      process.stderr.transform(utf8.decoder).listen((chunk) {
        stderr.write(chunk);
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        setState(() {
          _progress = 1;
          _progressLabel = '';
          _status = '✅ Готово! Файл сохранён в папку Загрузки';
          _isError = false;
          _loading = false;
        });
        _urlController.clear();
      } else {
        final lines = stderr.toString().trim().split('\n');
        setState(() {
          _status = '❌ ${lines.last}';
          _isError = true;
          _loading = false;
          _progress = null;
          _progressLabel = '';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ $e';
        _isError = true;
        _loading = false;
        _progress = null;
        _progressLabel = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'YT Downloader',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              const Text('Ссылка на видео', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=...',
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              const Text('Качество', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _quality,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    items: _qualities.map((q) => DropdownMenuItem(
                      value: q,
                      child: Text(q, style: const TextStyle(fontSize: 14)),
                    )).toList(),
                    onChanged: _loading ? null : (v) => setState(() => _quality = v!),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Браузер для cookies', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _browser,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    items: _browsers.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b[0].toUpperCase() + b.substring(1), style: const TextStyle(fontSize: 14)),
                    )).toList(),
                    onChanged: _loading ? null : (v) => setState(() => _browser = v!),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _download,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const Text(
                          'Загрузка...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        )
                      : const Text(
                          'Скачать',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              if (_progress != null) ...[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: AlwaysStoppedAnimation(Colors.red.shade700),
                  ),
                ),
                if (_progressLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _progressLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isError ? Colors.red.shade400 : Colors.green.shade400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
