import 'package:flutter/material.dart';
import '../models/player_progress.dart';
import '../widgets/logo.dart';

class ShopScreen extends StatefulWidget {
  final PlayerProgress progress;
  final VoidCallback onUpdate;
  const ShopScreen({required this.progress, required this.onUpdate});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final Map<String, int> chocolatePrices = {'dark': 0, 'milk': 50, 'white': 100};
  final Map<String, int> hatPrices = {'none': 0, 'tophat': 80, 'cap': 60};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ChocoDino logo
                const Center(
                  child: ChocoDinoLogo(fontSize: 24, showIcon: true),
                ),
                const SizedBox(height: 20),
                // Points row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🛒 SHOP', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(30)),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 20),
                                          const SizedBox(width: 5),
                          Text('${widget.progress.totalPoints}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Chocolate skins
                const Text('🍫 CHOCOLATE SKINS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: chocolatePrices.keys.map((skin) {
                    bool owned = widget.progress.purchasedSkins.contains(skin);
                    bool selected = widget.progress.selectedChocolateSkin == skin;
                    int price = chocolatePrices[skin]!;
                    return _buildShopItem(
                      icon: _chocolateIcon(skin),
                      name: skin,
                      price: price,
                      owned: owned,
                      selected: selected,
                      onTap: () {
                        if (!owned && widget.progress.totalPoints >= price) {
                          setState(() {
                            widget.progress.totalPoints -= price;
                            widget.progress.purchasedSkins.add(skin);
                            widget.progress.selectedChocolateSkin = skin;
                            widget.onUpdate();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchased!'), backgroundColor: Colors.green));
                        } else if (owned) {
                          setState(() {
                            widget.progress.selectedChocolateSkin = skin;
                            widget.onUpdate();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Skin changed to $skin'), backgroundColor: Colors.green));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough points!'), backgroundColor: Colors.red));
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                // Hats
                const Text('🎩 DINOSAUR HATS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: hatPrices.keys.map((hat) {
                    bool owned = widget.progress.purchasedHats.contains(hat);
                    bool selected = widget.progress.selectedHat == hat;
                    int price = hatPrices[hat]!;
                    return _buildShopItem(
                      icon: _hatIcon(hat),
                      name: hat,
                      price: price,
                      owned: owned,
                      selected: selected,
                      onTap: () {
                        if (!owned && widget.progress.totalPoints >= price) {
                          setState(() {
                            widget.progress.totalPoints -= price;
                            widget.progress.purchasedHats.add(hat);
                            widget.progress.selectedHat = hat;
                            widget.onUpdate();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchased!'), backgroundColor: Colors.green));
                        } else if (owned) {
                          setState(() {
                            widget.progress.selectedHat = hat;
                            widget.onUpdate();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hat changed to $hat'), backgroundColor: Colors.green));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough points!'), backgroundColor: Colors.red));
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShopItem({
    required IconData icon,
    required String name,
    required int price,
    required bool owned,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.amber.shade300 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.amber.shade700 : Colors.grey.shade300, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: selected ? Colors.black87 : Colors.brown.shade700),
            const SizedBox(height: 8),
            Text(name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: selected ? Colors.black87 : Colors.brown.shade800)),
            const SizedBox(height: 4),
            Text('$price pts', style: TextStyle(fontSize: 12, color: owned ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold)),
            if (!owned) const Icon(Icons.lock, size: 16, color: Colors.grey),
            if (selected) const Icon(Icons.check_circle, size: 20, color: Colors.green),
          ],
        ),
      ),
    );
  }

  IconData _chocolateIcon(String skin) {
    switch (skin) {
      case 'dark': return Icons.circle;
      case 'milk': return Icons.circle_outlined;
      case 'white': return Icons.lens;
      default: return Icons.circle;
    }
  }

  IconData _hatIcon(String hat) {
    switch (hat) {
      case 'tophat': return Icons.workspace_premium;
      case 'cap': return Icons.sports_baseball;
      default: return Icons.face;
    }
  }
}