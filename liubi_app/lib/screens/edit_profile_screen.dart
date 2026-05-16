import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/helpers.dart';
import '../widgets/app_toast.dart';
import '../widgets/region_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  int _gender = 0;
  String _selectedRegion = '';
  String _birthday = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).userInfo;
    if (user != null) {
      _nicknameCtrl.text = user.nickname;
      _bioCtrl.text = user.bio;
      _selectedRegion = user.location ?? '';
      _gender = user.gender;
      _birthday = _parseDate(user.birthday);
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  void _showBirthdayPicker() {
    DateTime initial;
    if (_birthday.isNotEmpty) {
      try {
        initial = DateTime.parse(_birthday);
      } catch (_) {
        initial = DateTime(2000, 1, 1);
      }
    } else {
      initial = DateTime(2000, 1, 1);
    }
    if (initial.isAfter(DateTime.now())) initial = DateTime(2000, 1, 1);
    if (initial.isBefore(DateTime(1900))) initial = DateTime(1900, 1, 1);

    int selectedYear = initial.year;
    int selectedMonth = initial.month;
    int selectedDay = initial.day;

    final years = List.generate(200, (i) => 1900 + i);
    final months = List.generate(12, (i) => i + 1);
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        int maxDay;
        try {
          maxDay = DateTime(selectedYear, selectedMonth + 1, 0).day;
        } catch (_) {
          maxDay = 28;
        }
        final days = List.generate(maxDay, (i) => i + 1);
        if (selectedDay > maxDay) selectedDay = maxDay;

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.5,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Text('取消', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                    ),
                    const Text('选择生日', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _birthday = '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-${selectedDay.toString().padLeft(2, '0')}';
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('确定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFF2442))),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF8F8F8),
                        child: ListView.builder(
                          itemCount: years.length,
                          itemBuilder: (_, i) {
                            final year = years[i];
                            final isSelected = selectedYear == year;
                            return GestureDetector(
                              onTap: () => setState(() => selectedYear = year),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  border: Border(left: BorderSide(color: isSelected ? const Color(0xFFFF2442) : Colors.transparent, width: 3)),
                                ),
                                child: Text('$year年', style: TextStyle(fontSize: 14, color: isSelected ? const Color(0xFFFF2442) : const Color(0xFF333333), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: months.length,
                        itemBuilder: (_, i) {
                          final month = months[i];
                          final isSelected = selectedMonth == month;
                          return GestureDetector(
                            onTap: () => setState(() => selectedMonth = month),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5))),
                              child: Row(
                                children: [
                                  Expanded(child: Text('$month月', style: TextStyle(fontSize: 14, color: isSelected ? const Color(0xFFFF2442) : const Color(0xFF333333), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
                                  if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xFFFF2442)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: days.length,
                        itemBuilder: (_, i) {
                          final day = days[i];
                          final isSelected = selectedDay == day;
                          return GestureDetector(
                            onTap: () => setState(() => selectedDay = day),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5))),
                              child: Row(
                                children: [
                                  Expanded(child: Text('$day日', style: TextStyle(fontSize: 14, color: isSelected ? const Color(0xFFFF2442) : const Color(0xFF333333), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
                                  if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xFFFF2442)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _pickAvatar() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.pickAndUploadAvatar();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final res = await userProvider.updateProfile({
      'nickname': _nicknameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
      'location': _selectedRegion,
      'gender': _gender,
      'birthday': _birthday,
    });
    if (mounted) {
      setState(() => _saving = false);
      if (res['code'] == 200) {
        AppToast.success(context, message: '保存成功');
        Navigator.pop(context);
      } else {
        AppToast.error(context, message: res['message'] ?? '保存失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: statusBarH),
            color: Colors.white,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF222222)))),
                  const Expanded(child: Center(child: Text('编辑资料', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF222222))))),
                  GestureDetector(
                    onTap: _save,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _saving
                          ? const CupertinoActivityIndicator(radius: 8, color: Color(0xFFFF2442))
                          : const Text('保存', style: TextStyle(fontSize: 15, color: Color(0xFFFF2442), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Consumer<UserProvider>(
                      builder: (_, up, __) {
                        final avatar = up.userInfo?.avatar ?? '';
                        return Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF0F0F0), border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5)),
                          child: Stack(
                            children: [
                              if (avatar.isNotEmpty)
                                ClipOval(child: Image.network(fullUrl(avatar), width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text((up.userInfo?.nickname ?? '?').isNotEmpty ? (up.userInfo?.nickname ?? '?')[0] : '?', style: const TextStyle(fontSize: 24, color: Colors.white)))))
                              else
                                Center(child: Text((up.userInfo?.nickname ?? '?').isNotEmpty ? (up.userInfo?.nickname ?? '?')[0] : '?', style: const TextStyle(fontSize: 24, color: Color(0xFF999999)))),
                              Positioned(right: 0, bottom: 0, child: Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFFFF2442), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)), child: const Icon(Icons.camera_alt, size: 10, color: Colors.white))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildField('昵称', _nicknameCtrl, '请输入昵称'),
                  const SizedBox(height: 14),
                  _buildGenderSelector(),
                  const SizedBox(height: 14),
                  _buildField('简介', _bioCtrl, '介绍一下自己吧', maxLines: 3),
                  const SizedBox(height: 14),
                  _buildTapField('地区', _selectedRegion.isEmpty ? '请选择所在地区' : _selectedRegion, onTap: () {
                    RegionPicker.show(context, currentValue: _selectedRegion, onChanged: (region) {
                      setState(() => _selectedRegion = region);
                    });
                  }),
                  const SizedBox(height: 14),
                  _buildTapField('生日', _birthday.isEmpty ? '请选择生日' : _birthday, onTap: () {
                    _showBirthdayPicker();
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
        ),
      ],
    );
  }

  Widget _buildTapField(String label, String value, {VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value.isEmpty ? '请选择' : value,
                  style: TextStyle(fontSize: 14, color: value.isEmpty ? const Color(0xFFCCCCCC) : const Color(0xFF333333)),
                ),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCCC)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('性别', style: TextStyle(fontSize: 13, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildGenderOption(0, '保密', const Color(0xFFF5F5F5), const Color(0xFF999999)),
            const SizedBox(width: 10),
            _buildGenderOption(1, '男', const Color(0xFFE6F7FF), const Color(0xFF1890FF)),
            const SizedBox(width: 10),
            _buildGenderOption(2, '女', const Color(0xFFFFF0F6), const Color(0xFFFF2442)),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(int value, String label, Color bg, Color fg) {
    final selected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: selected ? bg : const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8), border: selected ? Border.all(color: fg.withValues(alpha: 0.3)) : null),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 14, color: selected ? fg : const Color(0xFF999999), fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ),
      ),
    );
  }
}
