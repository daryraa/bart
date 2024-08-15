import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ArticleScreen(),
    );
  }
}

class ArticleScreen extends StatefulWidget {
  @override
  _ArticleScreenState createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  TextEditingController _keywordsController = TextEditingController();
  int _pages = 1;
  List<dynamic> _articles = [];
  bool _isLoading = false;
  String _loadingTime = '';
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> _scrapeArticles(String keywords, int pages) async {
    setState(() {
      _isLoading = true;
      _loadingTime = '';
    });

    final startTime = DateTime.now();
    // Ganti URL lokal dengan URL publik dari server FastAPI
    final url = Uri.parse('https://060ac42b-6389-43fc-ae7f-6025d12fd4df-00-2je6z7bqb117k.sisko.replit.dev/articles?keywords=$keywords&pages=$pages');
    final response = await http.get(url);

    final endTime = DateTime.now();
    final timeTaken = endTime.difference(startTime);
    final formattedTime = DateFormat('mm:ss.SSS').format(DateTime.fromMillisecondsSinceEpoch(timeTaken.inMilliseconds));

    if (response.statusCode == 200) {
      setState(() {
        _articles = json.decode(response.body);
        _isLoading = false;
        _loadingTime = 'Time taken: $formattedTime';
      });
      await _speak("Berikut hasil pencarian anda.");
    } else {
      setState(() {
        _isLoading = false;
        _loadingTime = 'Failed to scrape articles';
      });
      throw Exception('Failed to scrape articles');
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("id-ID");
    await _flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Peringkasan Teks')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _keywordsController,
              decoration: InputDecoration(labelText: 'Enter keywords to scrape'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Pages'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _pages = int.tryParse(value) ?? 1;
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _scrapeArticles(_keywordsController.text, _pages);
                  },
                  child: Text('Scrape'),
                ),
              ],
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : Text(_loadingTime),
            Expanded(
              child: ListView.builder(
                itemCount: _articles.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(_articles[index]['title'])),
                        IconButton(
                          icon: Icon(Icons.volume_up),
                          onPressed: () => _speak(_articles[index]['title']),
                        ),
                      ],
                    ),
                    subtitle: Text(_articles[index]['published_time']),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SummarizationScreen(
                            article: _articles[index],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Copyright © 2024 by Dary R.A',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SummarizationScreen extends StatefulWidget {
  final Map<String, dynamic> article;

  SummarizationScreen({required this.article});

  @override
  _SummarizationScreenState createState() => _SummarizationScreenState();
}

class _SummarizationScreenState extends State<SummarizationScreen> {
  String _summary = '';
  bool _isLoading = false;
  String _summarizationTime = '';
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _summarize();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("id-ID");
  }

  Future<void> _summarize() async {
    setState(() {
      _isLoading = true;
    });

    final startTime = DateTime.now();
    // Ganti URL lokal dengan URL publik dari server FastAPI
    final url = Uri.parse('https://060ac42b-6389-43fc-ae7f-6025d12fd4df-00-2je6z7bqb117k.sisko.replit.dev/test');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'text_data': {'text': widget.article['text']},
        'params': {'max_length': 150, 'min_length': 50}
      }),
    );

    final endTime = DateTime.now();
    final timeTaken = endTime.difference(startTime);
    final formattedTime = DateFormat('mm:ss.SSS').format(DateTime.fromMillisecondsSinceEpoch(timeTaken.inMilliseconds));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _summary = data['summary_text'];
        _isLoading = false;
        _summarizationTime = 'Time taken: $formattedTime';
      });
      await _speak(widget.article['title']);
      await _speak(_summary);
    } else {
      setState(() {
        _isLoading = false;
      });
      throw Exception('Failed to summarize text');
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.article['title'])),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Published Time: ${widget.article['published_time']}'),
            SizedBox(height: 10),
            Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _isLoading
                ? CircularProgressIndicator()
                : Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.article['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        SizedBox(height: 10),
                        Text(_summary),
                        SizedBox(height: 10),
                        Text(_summarizationTime, style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _speak(_summary),
                  child: Text('Bacakan Ringkasan'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Copyright © 2024 by Dary R.A',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
