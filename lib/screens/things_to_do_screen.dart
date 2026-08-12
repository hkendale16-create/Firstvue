import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/things_to_do_service.dart';
import '../theme/firstvue_theme.dart';
import 'auth_screen.dart';

class ThingsToDoScreen extends StatefulWidget {
  const ThingsToDoScreen({super.key});

  @override
  State<ThingsToDoScreen> createState() => _ThingsToDoScreenState();
}

class _ThingsToDoScreenState extends State<ThingsToDoScreen> {
  late Future<List<CommunityEvent>> _eventsFuture;
  late Future<bool> _canPostFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _eventsFuture = ThingsToDoService.fetchApprovedEvents();
      _canPostFuture = ThingsToDoService.canPostEvents();
    });
    await Future.wait([_eventsFuture, _canPostFuture]);
  }

  Future<void> _postEvent() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (!mounted) return;
    }

    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();

    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FirstVueColors.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'POST AN EVENT',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: title,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Event title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: location,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (title.text.trim().isEmpty) return;
                    await ThingsToDoService.postEvent(
                      title: title.text,
                      description: description.text,
                      locationLabel: location.text,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('PUBLISH'),
                ),
              ),
            ],
          ),
        );
      },
    );

    title.dispose();
    description.dispose();
    location.dispose();

    if (posted == true && mounted) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event posted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FirstVueColors.background,
      appBar: AppBar(
        backgroundColor: FirstVueColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'THINGS TO DO',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 21,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          FutureBuilder<bool>(
            future: _canPostFuture,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Post event',
                onPressed: _postEvent,
                icon: const Icon(Icons.add_circle_outline),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: FirstVueColors.gold,
        onRefresh: _refresh,
        child: FutureBuilder<List<CommunityEvent>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Events are unavailable right now.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: FirstVueColors.teal),
              );
            }
            final events = snapshot.data!;
            if (events.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Local events and experiences will appear here.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final event = events[index];
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: FirstVueColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: FirstVueColors.coral.withValues(alpha: .35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (event.businessName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.businessName!,
                          style: const TextStyle(
                            color: FirstVueColors.gold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (event.locationLabel != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.locationLabel!,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                      if (event.description != null &&
                          event.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          event.description!,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
