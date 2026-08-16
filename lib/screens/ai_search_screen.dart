import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/smart_search_service.dart';
import '../theme/firstvue_theme.dart';
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
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: const Text('ASK FIRSTVUE'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Describe exactly what you need',
            style: TextStyle(
              color: fv.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'FirstVue searches its own approved business data first.',
            style: TextStyle(color: fv.secondaryText),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            onSubmitted: (_) => _run(),
            maxLines: 3,
            style: TextStyle(color: fv.primaryText),
            decoration: InputDecoration(
              hintText:
                  'Barber good with fades, available today, under \$50, rated 4.5+',
              hintStyle: TextStyle(color: fv.tertiaryText),
              filled: true,
              fillColor: fv.inputFill,
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
                        return Center(
                          child: Text(
                            'No strong matches yet. Try a broader request.',
                            style: TextStyle(color: fv.secondaryText),
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
                              FirstVuePageRoute(
                                builder: (_) => FirstVueBusinessProfileScreen(
                                  businessId: item.id,
                                ),
                              ),
                            ),
                            tileColor: fv.elevatedSurface,
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
                              style: TextStyle(
                                color: fv.primaryText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${item.rating == 0 ? 'New' : '★ ${item.rating}'} • ${item.availableToday ? 'Available today' : 'Check availability'}$price\n${item.services.take(3).join(' • ')}',
                              style: TextStyle(color: fv.secondaryText),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: fv.tertiaryText,
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
}

class _Suggestions extends StatelessWidget {
  const _Suggestions();
  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return ListView(
    children: [
      const Text(
        'TRY ASKING',
        style: TextStyle(color: Color(0xFFD8B56A), fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      Text(
        '“Good date-night restaurant within 15 minutes, outdoor seating, under \$100 for two.”\n\n“Find a barber good with fades, available today, under \$50, rated 4.5 or better.”',
        style: TextStyle(color: fv.secondaryText, height: 1.5),
      ),
    ],
  );
  }
}
