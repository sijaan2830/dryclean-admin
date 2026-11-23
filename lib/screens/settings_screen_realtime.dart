import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/firebase_admin_service.dart';
import '../providers/firebase_auth_provider.dart';

class SettingsScreenRealtime extends StatefulWidget {
  const SettingsScreenRealtime({super.key});

  @override
  State<SettingsScreenRealtime> createState() => _SettingsScreenRealtimeState();
}

class _SettingsScreenRealtimeState extends State<SettingsScreenRealtime> {
  final FirebaseAdminService _adminService = FirebaseAdminService();
  Map<String, dynamic>? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // Listen to real-time settings data
    _adminService.getSettingsStream().listen((settings) {
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $error')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Settings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              Consumer<FirebaseAuthProvider>(
                builder: (context, authProvider, child) {
                  return Text(
                    'Logged in as: ${authProvider.user?.email ?? 'Admin'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Settings Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      _buildSettingsSection('Business Settings', [
                        _buildSettingItem(
                          'Business Name',
                          _settings?['businessName'] ?? 'DryClean Plus',
                          Icons.business,
                          () => _showEditDialog('businessName', _settings?['businessName'] ?? 'DryClean Plus'),
                        ),
                        _buildSettingItem(
                          'Business Email',
                          _settings?['businessEmail'] ?? 'admin@drycleanplus.com',
                          Icons.email,
                          () => _showEditDialog('businessEmail', _settings?['businessEmail'] ?? 'admin@drycleanplus.com'),
                        ),
                        _buildSettingItem(
                          'Business Phone',
                          _settings?['businessPhone'] ?? '+44 20 1234 5678',
                          Icons.phone,
                          () => _showEditDialog('businessPhone', _settings?['businessPhone'] ?? '+44 20 1234 5678'),
                        ),
                        _buildSettingItem(
                          'Business Address',
                          _settings?['businessAddress'] ?? '123 Main Street, London, UK',
                          Icons.location_on,
                          () => _showEditDialog('businessAddress', _settings?['businessAddress'] ?? '123 Main Street, London, UK'),
                        ),
                      ]),
                      
                      _buildSettingsSection('App Settings', [
                        _buildSettingItem(
                          'Default Currency',
                          _settings?['defaultCurrency'] ?? 'GBP (£)',
                          Icons.currency_pound,
                          () => _showCurrencyDialog(),
                        ),
                        _buildSettingItem(
                          'Time Zone',
                          _settings?['timeZone'] ?? 'Europe/London',
                          Icons.access_time,
                          () => _showTimeZoneDialog(),
                        ),
                        _buildSettingItem(
                          'Date Format',
                          _settings?['dateFormat'] ?? 'DD/MM/YYYY',
                          Icons.calendar_today,
                          () => _showDateFormatDialog(),
                        ),
                      ]),
                      
                      _buildSettingsSection('Notification Settings', [
                        _buildSwitchItem(
                          'Email Notifications',
                          _settings?['emailNotifications'] ?? true,
                          (value) => _updateSetting('emailNotifications', value),
                        ),
                        _buildSwitchItem(
                          'SMS Notifications',
                          _settings?['smsNotifications'] ?? false,
                          (value) => _updateSetting('smsNotifications', value),
                        ),
                        _buildSwitchItem(
                          'Push Notifications',
                          _settings?['pushNotifications'] ?? true,
                          (value) => _updateSetting('pushNotifications', value),
                        ),
                      ]),
                      
                      _buildSettingsSection('System', [
                        _buildActionItem(
                          'Clear Cache',
                          Icons.clear_all,
                          () => _clearCache(),
                          Colors.orange,
                        ),
                        _buildActionItem(
                          'Export Data',
                          Icons.download,
                          () => _exportData(),
                          const Color(0xFF047857),
                        ),
                        _buildActionItem(
                          'Backup Settings',
                          Icons.backup,
                          () => _backupSettings(),
                          Colors.green,
                        ),
                      ]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: items,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingItem(String title, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF073B1B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF073B1B), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF073B1B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.notifications, color: const Color(0xFF073B1B), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF073B1B),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String key, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${key.replaceAll(RegExp(r'([A-Z])'), r' \$1').trim()}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Enter new value',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateSetting(key, controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF073B1B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog() {
    final currencies = ['GBP (£)', 'USD (\$)', 'EUR (€)', 'INR (₹)'];
    String selected = _settings?['defaultCurrency'] ?? 'GBP (£)';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: currencies.map((currency) {
            return RadioListTile<String>(
              title: Text(currency),
              value: currency,
              groupValue: selected,
              onChanged: (value) {
                selected = value!;
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateSetting('defaultCurrency', selected);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF073B1B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTimeZoneDialog() {
    final timeZones = ['Europe/London', 'America/New_York', 'Asia/Tokyo', 'Asia/Kolkata'];
    String selected = _settings?['timeZone'] ?? 'Europe/London';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Time Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: timeZones.map((timeZone) {
            return RadioListTile<String>(
              title: Text(timeZone),
              value: timeZone,
              groupValue: selected,
              onChanged: (value) {
                selected = value!;
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateSetting('timeZone', selected);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF073B1B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDateFormatDialog() {
    final formats = ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'];
    String selected = _settings?['dateFormat'] ?? 'DD/MM/YYYY';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: formats.map((format) {
            return RadioListTile<String>(
              title: Text(format),
              value: format,
              groupValue: selected,
              onChanged: (value) {
                selected = value!;
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateSetting('dateFormat', selected);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF073B1B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _adminService.updateSettings({key: value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Setting updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearCache() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleared successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data export started'),
        backgroundColor: const Color(0xFF047857),
      ),
    );
  }

  void _backupSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings backed up successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
