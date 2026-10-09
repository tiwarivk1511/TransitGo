import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../components/train/TrainNumberAutocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/fare.dart';
import '../../../data/models/station.dart';
import '../../../services/fare_service.dart';

class FareScreen extends StatefulWidget {
  final String? initialTrainNumber;
  final String? initialFromCode;
  final String? initialToCode;
  final String? initialClassCode;
  final String? initialQuotaCode;

  const FareScreen({
    super.key,
    this.initialTrainNumber,
    this.initialFromCode,
    this.initialToCode,
    this.initialClassCode,
    this.initialQuotaCode,
  });

  @override
  State<FareScreen> createState() => _FareScreenState();
}

class _FareScreenState extends State<FareScreen> {
  final _trainCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  Station? _from;
  Station? _to;

  DateTime _selectedDate = DateTime.now();
  String _class = '3A';
  String _quota = 'GN';
  bool _loading = false;
  String? _error;
  TrainFareData? _data;

  static const _classes = [
    {'code': 'SL', 'name': 'Sleeper'},
    {'code': '3A', 'name': '3 AC'},
    {'code': '2A', 'name': '2 AC'},
    {'code': '1A', 'name': '1st AC'},
    {'code': '3E', 'name': '3 Economy'},
    {'code': 'CC', 'name': 'AC Chair'},
    {'code': 'EC', 'name': 'Exec Chair'},
    {'code': '2S', 'name': '2nd Seating'},
  ];

  static const _quotas = [
    {'code': 'GN', 'name': 'General'},
    {'code': 'TQ', 'name': 'Tatkal'},
    {'code': 'PT', 'name': 'Premium Tatkal'},
    {'code': 'LD', 'name': 'Ladies'},
    {'code': 'SS', 'name': 'Senior Citizen'},
  ];

  @override
  void initState() {
    super.initState();
    final train = widget.initialTrainNumber?.trim();
    final from = widget.initialFromCode?.trim();
    final to = widget.initialToCode?.trim();
    if (train != null) _trainCtrl.text = train;
    if (from != null) _fromCtrl.text = from;
    if (to != null) _toCtrl.text = to;

    final initialClass = widget.initialClassCode?.trim().toUpperCase();
    if (initialClass != null &&
        _classes.any((c) => c['code'] == initialClass)) {
      _class = initialClass;
    }

    final initialQuota = widget.initialQuotaCode?.trim().toUpperCase();
    if (initialQuota != null &&
        _quotas.any((q) => q['code'] == initialQuota)) {
      _quota = initialQuota;
    }

    if (train?.isNotEmpty == true &&
        from?.isNotEmpty == true &&
        to?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

  @override
  void dispose() {
    _trainCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final t = _trainCtrl.text.trim().split(' - ').first;
    final f = _from?.code ?? _fromCtrl.text.trim().toUpperCase();
    final to = _to?.code ?? _toCtrl.text.trim().toUpperCase();

    if (t.isEmpty || f.isEmpty || to.isEmpty) {
      setState(() => _error = 'Please fill train number, source & destination.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final d = await FareService.fetch(
      trainNumber: t,
      from: f,
      to: to,
      date: formattedDate,
      classCode: _class,
      quota: _quota,
    );

    if (!mounted) return;

    if (d != null) {
      await OfflineCache.addHistory(
        'fare',
        '$t $f->$to',
        label: '$t • $f ➔ $to ($_class)',
        data: {
          'trainNumber': t,
          'fromCode': f,
          'toCode': to,
          'classCode': _class,
          'quotaCode': _quota,
          'journeyDate': formattedDate,
        },
      );
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = d;
      if (d == null) _error = 'Fare data unavailable for $t ($f ➔ $to).';
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 120)),
      builder: (context, child) {
        final isDark = ThemeController.instance.isDarkMode;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF0A84FF),
                    onPrimary: Colors.white,
                    surface: Color(0xFF16161C),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF0A84FF),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1C1C1E),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _data = null;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF636366);
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E5EA);
    final inputBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Fare Calculator & Breakdown',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark
                  ? CupertinoIcons.sun_max_fill
                  : CupertinoIcons.moon_stars_fill,
              color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF0A84FF),
              size: 18,
            ),
            onPressed: () async {
              await ThemeController.instance.toggleTheme();
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          physics: const BouncingScrollPhysics(),
          children: [
            _introCard(cardBg, textPrimary, textSecondary, borderCol),
            const SizedBox(height: 16),

            // Main Fare Inputs Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderCol),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRAIN & ROUTE SELECTION',
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TrainNumberAutocomplete(
                    controller: _trainCtrl,
                    hint: 'Train number or name (e.g. 12417, Prayagraj)',
                    icon: CupertinoIcons.tram_fill,
                  ),
                  const SizedBox(height: 12),

                  StationAutocomplete(
                    controller: _fromCtrl,
                    label: 'From Station',
                    hint: 'e.g. PRYJ or Prayagraj',
                    icon: CupertinoIcons.location_north_fill,
                    onStationSelected: (s) => setState(() {
                      _from = s;
                      _fromCtrl.text = '${s.name} (${s.code})';
                      _data = null;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 12),

                  StationAutocomplete(
                    controller: _toCtrl,
                    label: 'To Station',
                    hint: 'e.g. NDLS or New Delhi',
                    icon: CupertinoIcons.location_fill,
                    onStationSelected: (s) => setState(() {
                      _to = s;
                      _toCtrl.text = '${s.name} (${s.code})';
                      _data = null;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Journey Date Selector Row
                  Text(
                    'JOURNEY DATE',
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderCol),
                            ),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.calendar,
                                    size: 16, color: Color(0xFF0A84FF)),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('EEE, dd MMM yyyy')
                                      .format(_selectedDate),
                                  style: GoogleFonts.inter(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const Spacer(),
                                Icon(CupertinoIcons.chevron_down,
                                    size: 14, color: textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedDate = DateTime.now();
                          _data = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 11),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderCol),
                          ),
                          child: Text(
                            'Today',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0A84FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedDate = DateTime.now().add(const Duration(days: 1));
                          _data = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 11),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderCol),
                          ),
                          child: Text(
                            'Tomorrow',
                            style: GoogleFonts.inter(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Travel Class Selector Chips
                  Text(
                    'TRAVEL CLASS',
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _classes.map((c) {
                      final isSelected = _class == c['code'];
                      return ChoiceChip(
                        label: Text('${c['code']} (${c['name']})'),
                        selected: isSelected,
                        onSelected: (_) => setState(() {
                          _class = c['code']!;
                          _data = null;
                          _error = null;
                        }),
                        selectedColor: const Color(0xFF0A84FF),
                        backgroundColor: isDark ? cardBg : const Color(0xFFE5E5EA),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF0A84FF)
                              : borderCol,
                        ),
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? Colors.white : textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Quota Selector Chips
                  Text(
                    'QUOTA',
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _quotas.map((q) {
                      final isSelected = _quota == q['code'];
                      return ChoiceChip(
                        label: Text('${q['code']} - ${q['name']}'),
                        selected: isSelected,
                        onSelected: (_) => setState(() {
                          _quota = q['code']!;
                          _data = null;
                          _error = null;
                        }),
                        selectedColor: const Color(0xFF0A84FF),
                        backgroundColor: isDark ? cardBg : const Color(0xFFE5E5EA),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF0A84FF)
                              : borderCol,
                        ),
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? Colors.white : textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Get Fare Breakdown Action Button
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(
                          CupertinoIcons.money_dollar_circle_fill,
                          size: 18),
                      label: Text(
                        'Get Itemized Ticket Fare',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A84FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _loading ? null : _fetch,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const LoadingIndicator(
                color: Color(0xFF0A84FF),
                label: 'Calculating official ticket fare breakdown…',
              )
            else if (_error != null)
              ErrorBox(message: _error!, onRetry: _fetch)
            else if (_data != null)
              _fareReceiptCard(
                  _data!, cardBg, textPrimary, textSecondary, borderCol, inputBg),
          ],
        ),
      ),
    );
  }

  Widget _introCard(
      Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF30D158).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.money_dollar_circle_fill,
              color: Color(0xFF30D158),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transparent Ticket Fare',
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Official PRS ticket fare breakdown by class, distance, superfast charges, GST, catering, and quotas.',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fareReceiptCard(TrainFareData d, Color cardBg, Color textPrimary,
      Color textSecondary, Color borderCol, Color inputBg) {
    final trainName = d.trainName.isNotEmpty
        ? d.trainName
        : 'Train ${d.trainNumber}';
    final distanceText =
        d.distanceKm != null ? '${d.distanceKm} km' : 'Indian Railways Route';

    String? generatedTime;
    if (d.generatedAt != null && d.generatedAt!.isNotEmpty) {
      final dt = DateTime.tryParse(d.generatedAt!)?.toLocal();
      if (dt != null) {
        generatedTime = DateFormat('h:mm a').format(dt);
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.ticket_fill,
                  color: Color(0xFF30D158),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d.trainNumber} • $trainName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.source} ➔ ${d.destination} • $distanceText',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Class & Quota Badge Pills
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'CLASS: ${d.classCode}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0A84FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (d.quota != null && d.quota!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'QUOTA: ${d.quota!.toUpperCase()}',
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                DateFormat('dd MMM yyyy').format(_selectedDate),
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          Divider(color: borderCol, height: 28),

          // Total Fare Header Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF30D158).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF30D158).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL TICKET FARE',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF30D158),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Inclusive of all GST & railway surcharges',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${d.totalFare}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF30D158),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'ITEMIZED CHARGES BREAKDOWN',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),

          // Breakdown Items List
          _breakdownRow('Base Ticket Fare', '₹${d.baseFare}', textPrimary, textSecondary),
          if ((d.reservationCharge ?? 0) >= 0)
            _breakdownRow('Reservation Fee', '₹${d.reservationCharge ?? 0}', textPrimary, textSecondary),
          if ((d.superfastCharge ?? 0) >= 0)
            _breakdownRow('Superfast Surcharge', '₹${d.superfastCharge ?? 0}', textPrimary, textSecondary),
          if (d.serviceTax != null)
            _breakdownRow('Goods & Services Tax (GST)', '₹${d.serviceTax}', textPrimary, textSecondary),
          if (d.tatkalCharge != null)
            _breakdownRow('Tatkal Premium Fee', '₹${d.tatkalCharge}', textPrimary, textSecondary),
          if (d.cateringCharge != null)
            _breakdownRow('Catering Fee', '₹${d.cateringCharge}', textPrimary, textSecondary),
          if (d.dynamicFare != null)
            _breakdownRow('Dynamic Surge Fare', '₹${d.dynamicFare}', textPrimary, textSecondary),
          if (d.otherCharges != null)
            _breakdownRow('Other Charges', '₹${d.otherCharges}', textPrimary, textSecondary),

          Divider(color: borderCol, height: 28),

          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_seal_fill,
                  size: 14, color: Color(0xFF0A84FF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Source: Official PRS Open Web Telemetry${generatedTime != null ? " • $generatedTime" : ""}',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(
      String label, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
