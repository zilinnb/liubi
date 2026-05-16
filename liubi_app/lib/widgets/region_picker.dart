import 'package:flutter/material.dart';
import '../utils/region_data.dart';

class RegionPicker {
  static void show(BuildContext context, {String? currentValue, required ValueChanged<String> onChanged}) {
    String? selectedProvince;
    String? selectedCity;

    if (currentValue != null && currentValue.contains(' ')) {
      final parts = currentValue.split(' ');
      final prov = regionData.where((r) => r.name == parts[0]).firstOrNull;
      if (prov != null) {
        selectedProvince = prov.name;
        final city = prov.children.where((c) => c.name == parts[1]).firstOrNull;
        if (city != null) selectedCity = city.name;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setState) {
        final provinceList = regionData;
        final cityList = selectedProvince != null
            ? regionData.where((r) => r.name == selectedProvince).first.children
            : <Region>[];

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Text('取消', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                    ),
                    const Text('选择地区', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                    GestureDetector(
                      onTap: () {
                        if (selectedProvince != null && selectedCity != null) {
                          onChanged('$selectedProvince $selectedCity');
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text('确定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: selectedProvince != null && selectedCity != null
                            ? const Color(0xFFFF2442)
                            : const Color(0xFFCCCCCC),
                      )),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: const Color(0xFFF8F8F8),
                        child: ListView.builder(
                          itemCount: provinceList.length,
                          itemBuilder: (_, i) {
                            final prov = provinceList[i];
                            final isSelected = selectedProvince == prov.name;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedProvince = prov.name;
                                  selectedCity = prov.children.isNotEmpty ? prov.children.first.name : null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  border: Border(
                                    left: BorderSide(
                                      color: isSelected ? const Color(0xFFFF2442) : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  prov.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected ? const Color(0xFFFF2442) : const Color(0xFF333333),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: cityList.isEmpty
                          ? const Center(child: Text('请选择省份', style: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))))
                          : ListView.builder(
                              itemCount: cityList.length,
                              itemBuilder: (_, i) {
                                final city = cityList[i];
                                final isSelected = selectedCity == city.name;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => selectedCity = city.name);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            city.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isSelected ? const Color(0xFFFF2442) : const Color(0xFF333333),
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check, size: 16, color: Color(0xFFFF2442)),
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
}
