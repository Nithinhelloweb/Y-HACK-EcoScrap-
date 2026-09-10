import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../i18n/translations.dart';

class PassportScreen extends StatefulWidget {
  final ApiService apiService;
  final String currentLang;

  const PassportScreen({
    super.key,
    required this.apiService,
    required this.currentLang,
  });

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  final _searchController = TextEditingController(text: 'EW-TN-2026-000184');
  Map<String, dynamic>? _passportData;
  bool _isLoading = false;

  String t(String key) => AppTranslations.get(key, widget.currentLang);

  @override
  void initState() {
    super.initState();
    _fetchPassport();
  }

  Future<void> _fetchPassport() async {
    final code = _searchController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await widget.apiService.fetchPassport(code);
      if (!mounted) return;
      setState(() => _passportData = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load passport: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _passportData;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('passport_tab')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Enter E-Waste Lot Code',
                    hintText: 'e.g. EW-TN-2026-000184',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  backgroundColor: Colors.teal,
                ),
                onPressed: _fetchPassport,
                child: const Text('Trace'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(30.0), child: CircularProgressIndicator()))
          else if (data != null) ...[
            // Main Passport Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'E-WASTE PASSPORT',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2, color: Colors.tealAccent.shade400),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade900,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('CPCB Traceable', style: TextStyle(color: Colors.lightGreenAccent, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['lot_code'] ?? '',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text('Material: ${data['category']} • ${data['subcategory']}'),
                    Text('Collector: ${data['collector_code']} • Assigned Recycler: ${data['verified_recycler_name']}'),
                    const SizedBox(height: 8),
                    Text(
                      'Weight: ${data['verified_weight_kg'] ?? data['estimated_weight_kg']} kg (${data['verified_weight_kg'] != null ? "Scale Verified" : "Collector Declared"})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent),
                    ),
                    const Divider(height: 20),

                    // Ledger Hash Integrity Status
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (data['ledger_integrity_valid'] == true) ? const Color(0xFF042F2E) : const Color(0xFF450A0A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (data['ledger_integrity_valid'] == true) ? Colors.tealAccent : Colors.redAccent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (data['ledger_integrity_valid'] == true) ? Icons.verified_user : Icons.gpp_bad,
                            color: (data['ledger_integrity_valid'] == true) ? Colors.tealAccent : Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              (data['ledger_integrity_valid'] == true)
                                  ? t('chain_valid')
                                  : '🚨 WARNING: Tampered Hash Detected!',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Circular Material Recovery Breakdown
            _buildCircularityCard(data),
            const SizedBox(height: 16),

            // Environmental Impact Metrics
            _buildImpactCard(data),
            const SizedBox(height: 16),

            // Tamper-Evident SHA-256 Ledger Timeline
            const Text('🔗 Tamper-Evident Cryptographic Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...((data['events_timeline'] as List? ?? []).map((ev) => _buildLedgerBlock(ev))),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularityCard(Map<String, dynamic> data) {
    final fractions = data['recovered_fractions_estimate'] as Map<String, dynamic>? ?? {};

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.recycling, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text('Material Recovery Potential', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            ...fractions.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('• ${e.key.replaceAll('_', ' ').toUpperCase()}'),
                      Text('${e.value} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightGreenAccent)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactCard(Map<String, dynamic> data) {
    final env = data['environmental_savings'] as Map<String, dynamic>? ?? {};

    return Card(
      color: const Color(0xFF042F2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.teal.shade700)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.eco, color: Colors.lightGreenAccent),
                SizedBox(width: 8),
                Text('Environmental Impact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol('CO2e Avoided', '${env['co2e_avoided_kg'] ?? 0} kg', Icons.cloud),
                _buildMetricCol('Toxics Contained', '${env['toxic_heavy_metals_contained_g'] ?? 0} g', Icons.security),
                _buildMetricCol('Trees Offset', '${env['trees_offset_equivalent'] ?? 0}', Icons.forest),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.lightGreenAccent, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLedgerBlock(dynamic ev) {
    final prev = (ev['previous_hash'] as String? ?? '').substring(0, 16);
    final curr = (ev['current_hash'] as String? ?? '').substring(0, 16);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Block: ${ev['event_type']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                const Icon(Icons.link, size: 16, color: Colors.lightGreenAccent),
              ],
            ),
            const SizedBox(height: 4),
            Text('Prev Hash: $prev...', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey)),
            Text('Block Hash: $curr...', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.lightGreenAccent)),
          ],
        ),
      ),
    );
  }
}
