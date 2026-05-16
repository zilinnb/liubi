import 'package:flutter/material.dart';

class CustomTabbar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  final int unreadCount;

  const CustomTabbar({
    super.key,
    required this.current,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: SizedBox(
        height: 50 + bottom,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Row(
            children: [
              _buildItem(0, '首页'),
              _buildItem(1, '发现'),
              _buildCenter(),
              _buildMsgItem(2, '消息'),
              _buildItem(3, '我'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, String label) {
    final isOn = current == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: SizedBox(
          height: 50,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isOn ? 14 : 13,
                color: isOn ? const Color(0xFF222222) : const Color(0xFF999999),
                fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMsgItem(int index, String label) {
    final isOn = current == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(label, style: TextStyle(fontSize: isOn ? 14 : 13, color: isOn ? const Color(0xFF222222) : const Color(0xFF999999), fontWeight: isOn ? FontWeight.w600 : FontWeight.w400)),
                  if (unreadCount > 0)
                    Positioned(
                      top: -8, right: -16,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        padding: EdgeInsets.symmetric(horizontal: unreadCount > 9 ? 5 : (unreadCount > 1 ? 4 : 0)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF23030),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500, height: 1.2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenter() {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(-1),
        child: SizedBox(
          height: 50,
          child: Center(
            child: Container(
              width: 40,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF2442), Color(0xFFFF5A6E)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2442).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
