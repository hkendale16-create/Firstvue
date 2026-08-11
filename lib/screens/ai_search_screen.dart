import 'package:flutter/material.dart';
import '../services/smart_search_service.dart';
import 'firstvue_business_profile_screen.dart';

class AiSearchScreen extends StatefulWidget {
  final String initialPrompt;
  const AiSearchScreen({super.key, this.initialPrompt = ''});
  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  late final _controller = TextEditingController(text: widget.initialPrompt);
  Future<List<SmartBusinessResult>>? _results;
  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt.isNotEmpty) _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      setState(() => _results = SmartSearchService.search(query));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080B0F),
    appBar: AppBar(
      title: const Text('ASK FIRSTVUE'),
      backgroundColor: const Color(0xFF080B0F),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Describe exactly what you need',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'FirstVue searches its own approved business data first.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            onSubmitted: (_) => _run(),
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'Barber good with fades, available today, under \$50, rated 4.5+',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF151B22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('FIND MY BEST MATCHES'),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _results == null
                ? const _Suggestions()
                : FutureBuilder<List<SmartBusinessResult>>(
                    future: _results,
                    builder: (_, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFD8B56A),
                          ),
                        );
                      }
                      if (snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            'No strong matches yet. Try a broader request.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: snapshot.data!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final item = snapshot.data![index];
                          final price = item.minimumPriceCents == null
                              ? ''
                              : ' • from \$${(item.minimumPriceCents! / 100).round()}';
                          return ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FirstVueBusinessProfileScreen(
                                  businessId: item.id,
                                ),
                              ),
                            ),
                            tileColor: const Color(0xFF10151B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0x2228B56A),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFFD8B56A),
                                ),
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${item.rating == 0 ? 'New' : '★ ${item.rating}'} • ${item.availableToday ? 'Available today' : 'Check availability'}$price\n${item.services.take(3).join(' • ')}',
                              style: const TextStyle(color: Colors.white60),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _Suggestions extends StatelessWidget {
  const _Suggestions();
  @override
  Widget build(BuildContext context) => ListView(
    children: const [
      Text(
        'TRY ASKING',
        style: TextStyle(color: Color(0xFFD8B56A), fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 12),
      Text(
        '“Good date-night restaurant within 15 minutes, outdoor seating, under \$100 for two.”\n\n“Find a barber good with fades, available today, under \$50, rated 4.5 or better.”',
        style: TextStyle(color: Colors.white60, height: 1.5),
      ),
    ],
  );
}
