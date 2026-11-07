import 'package:flutter/material.dart';

class PreflightChecklistCard extends StatelessWidget {
  final bool serverConnected;
  final bool batterySufficient;

  const PreflightChecklistCard({
    super.key,
    required this.serverConnected,
    required this.batterySufficient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChecklistRow(
            icon: Icons.wifi,
            title: 'Kết nối máy chủ thi',
            subtitle: serverConnected ? 'Đã kết nối ổn định (Ping OK)' : 'Chưa kết nối được máy chủ',
            isOk: serverConnected,
          ),
          const Divider(height: 20),
          _buildChecklistRow(
            icon: Icons.battery_charging_full,
            title: 'Pin & Thiết bị an toàn',
            subtitle: 'Mức pin đảm bảo (> 20%), không phát hiện Root/Jailbreak',
            isOk: batterySufficient,
          ),
          const Divider(height: 20),
          _buildChecklistRow(
            icon: Icons.shield_outlined,
            title: 'Bảo vệ màn hình an toàn',
            subtitle: 'Kích hoạt cờ chống chụp màn hình (FLAG_SECURE)',
            isOk: true,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isOk,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isOk ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isOk ? Colors.green : Colors.red, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isOk ? const Color(0xFF64748B) : Colors.red)),
            ],
          ),
        ),
        Icon(isOk ? Icons.check_circle : Icons.error, color: isOk ? Colors.green : Colors.red, size: 20),
      ],
    );
  }
}
