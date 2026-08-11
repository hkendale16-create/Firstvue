import 'package:flutter/material.dart';

import '../services/saved_businesses_store.dart';

class BusinessProfileScreen extends StatefulWidget {
  final String businessName;
  final double rating;
  final int reviews;
  final bool verified;
  final String distance;
  final String specialty;
  final IconData profileIcon;
  final String profileLabel;
  final String aboutText;

  const BusinessProfileScreen({
    super.key,
    required this.businessName,
    required this.rating,
    required this.reviews,
    required this.verified,
    required this.distance,
    required this.specialty,
    this.profileIcon = Icons.content_cut,
    this.profileLabel = 'Independent professional',
    this.aboutText =
        'This fictional prototype profile demonstrates the FIRSTVUE discovery experience.',
  });

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  bool saved = false;

  @override
  void initState() {
    super.initState();
    saved = SavedBusinessesStore.isSaved(widget.businessName);
  }

  void _toggleSaved() {
    setState(() {
      saved = !saved;
      if (saved) {
        SavedBusinessesStore.save(
          SavedBusiness(
            businessName: widget.businessName,
            rating: widget.rating,
            reviews: widget.reviews,
            verified: widget.verified,
            distance: widget.distance,
            specialty: widget.specialty,
          ),
        );
      } else {
        SavedBusinessesStore.remove(widget.businessName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),

      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF080B0F),

            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),

            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .55),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    saved ? Icons.favorite : Icons.favorite_border,
                    color: saved ? const Color(0xFFD68E98) : Colors.white,
                  ),
                  onPressed: _toggleSaved,
                ),
              ),
            ],

            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF282118),
                      Color(0xFF0E1319),
                      Color(0xFF080B0F),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.profileIcon,
                    size: 80,
                    color: const Color(0xFFD8B56A).withValues(alpha: .35),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.businessName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      if (widget.verified)
                        const Icon(
                          Icons.verified,
                          color: Color(0xFFD8B56A),
                          size: 25,
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    widget.profileLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFD8B56A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFE5C16F),
                        size: 21,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.rating}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.reviews} reviews',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFD8B56A),
                        size: 17,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${widget.distance} away',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  _SectionTitle(title: 'ROUTE PREVIEW'),

                  const SizedBox(height: 12),

                  _PrototypeRoutePreview(distance: widget.distance),

                  const SizedBox(height: 25),

                  _SectionTitle(title: 'SPECIALTY'),

                  const SizedBox(height: 10),

                  Text(
                    widget.specialty,
                    style: const TextStyle(
                      color: Color(0xFFD8B56A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 25),

                  _SectionTitle(title: 'PORTFOLIO'),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 105,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 105,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF25201A), Color(0xFF0E1319)],
                            ),
                          ),
                          child: const Icon(
                            Icons.image_outlined,
                            color: Colors.white24,
                            size: 32,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  _SectionTitle(title: 'SERVICES'),

                  const SizedBox(height: 12),

                  ...widget.specialty
                      .split('•')
                      .map(
                        (service) => ServiceRow(
                          service: service.trim(),
                          price: 'Contact for pricing',
                        ),
                      ),

                  const SizedBox(height: 30),

                  _SectionTitle(title: 'ABOUT'),

                  const SizedBox(height: 12),

                  Text(
                    widget.aboutText,
                    style: const TextStyle(
                      color: Colors.white60,
                      height: 1.6,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 30),

                  _SectionTitle(title: 'REVIEWS'),

                  const SizedBox(height: 15),

                  const ReviewCard(
                    name: 'Marcus',
                    rating: 5,
                    review:
                        'Great cut and attention to detail. Definitely coming back.',
                  ),

                  const ReviewCard(
                    name: 'Jordan',
                    rating: 5,
                    review: 'Best fade I have had in a long time.',
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.calendar_month),
                      label: const Text(
                        'BOOK APPOINTMENT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD8B56A),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrototypeRoutePreview extends StatelessWidget {
  final String distance;

  const _PrototypeRoutePreview({required this.distance});

  @override
  Widget build(BuildContext context) {
    final miles = double.tryParse(distance.split(' ').first) ?? 0;
    final sampleMinutes = (miles * 5 + 4).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: Container(
        height: 186,
        decoration: BoxDecoration(
          color: const Color(0xFF10151B),
          border: Border.all(
            color: const Color(0xFFD8B56A).withValues(alpha: .2),
          ),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _RouteMapPainter())),
            Positioned(
              top: 12,
              left: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF080B0F).withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xFFD8B56A).withValues(alpha: .24),
                  ),
                ),
                child: const Text(
                  'PROTOTYPE ROUTE',
                  style: TextStyle(
                    color: Color(0xFFD8B56A),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 13,
              right: 13,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF080B0F).withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_car,
                      color: Color(0xFFD8B56A),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sample ETA: ~$sampleMinutes min  •  $distance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white38,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFD8B56A).withValues(alpha: .07)
      ..strokeWidth = 1;
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: .09)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var x = 14.0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 14.0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final roadOne = Path()
      ..moveTo(0, size.height * .72)
      ..quadraticBezierTo(
        size.width * .32,
        size.height * .45,
        size.width,
        size.height * .53,
      );
    final roadTwo = Path()
      ..moveTo(size.width * .25, 0)
      ..quadraticBezierTo(
        size.width * .58,
        size.height * .46,
        size.width * .67,
        size.height,
      );
    canvas.drawPath(roadOne, roadPaint);
    canvas.drawPath(roadTwo, roadPaint);

    final route = Path()
      ..moveTo(size.width * .18, size.height * .72)
      ..cubicTo(
        size.width * .31,
        size.height * .58,
        size.width * .42,
        size.height * .71,
        size.width * .56,
        size.height * .47,
      )
      ..quadraticBezierTo(
        size.width * .68,
        size.height * .28,
        size.width * .8,
        size.height * .29,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFFD8B56A)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(
      Offset(size.width * .18, size.height * .72),
      8,
      Paint()..color = const Color(0xFFD8B56A),
    );
    canvas.drawCircle(
      Offset(size.width * .8, size.height * .29),
      9,
      Paint()..color = const Color(0xFFD68E98),
    );
    canvas.drawCircle(
      Offset(size.width * .8, size.height * .29),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) => false;
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}

class ServiceRow extends StatelessWidget {
  final String service;
  final String price;

  const ServiceRow({super.key, required this.service, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF10151B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(service, style: const TextStyle(color: Colors.white70)),
          Text(
            price,
            style: const TextStyle(
              color: Color(0xFFD8B56A),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  final String name;
  final int rating;
  final String review;

  const ReviewCard({
    super.key,
    required this.name,
    required this.rating,
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10151B),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              ...List.generate(
                rating,
                (_) =>
                    const Icon(Icons.star, size: 14, color: Color(0xFFE5C16F)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review,
            style: const TextStyle(color: Colors.white54, height: 1.4),
          ),
        ],
      ),
    );
  }
}
