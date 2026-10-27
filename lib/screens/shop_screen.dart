// lib/screens/shop_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player_progress.dart';
import '../widgets/logo.dart';
import '../theme/design_tokens.dart';

enum ShopCategory { skins, hats }

class ShopScreen extends StatefulWidget {
  final PlayerProgress progress;
  final VoidCallback onUpdate;
  const ShopScreen({required this.progress, required this.onUpdate});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  ShopCategory _currentCategory = ShopCategory.skins;

  final Map<String, int> chocolatePrices = {'dark': 0, 'milk': 50, 'white': 100};
  final Map<String, int> hatPrices = {'none': 0, 'tophat': 80, 'cap': 60};

  final Set<String> _cart = {};
  String? _purchasedItem;
  late AnimationController _bounceController;

  Map<String, int> get _currentItems {
    return _currentCategory == ShopCategory.skins ? chocolatePrices : hatPrices;
  }

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _toggleCartItem(String item) {
    setState(() {
      if (_cart.contains(item)) {
        _cart.remove(item);
      } else {
        _cart.add(item);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
    });
  }

  int get _cartTotal {
    int total = 0;
    for (final item in _cart) {
      total += _currentItems[item]!;
    }
    return total;
  }

  void _checkout() async {
    if (_cart.isEmpty) return;
    if (widget.progress.totalPoints < _cartTotal) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough points!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      widget.progress.totalPoints -= _cartTotal;
    });

    String? lastItem;
    for (final item in _cart) {
      if (_currentCategory == ShopCategory.skins) {
        if (!widget.progress.purchasedSkins.contains(item)) {
          widget.progress.purchasedSkins.add(item);
        }
        widget.progress.selectedChocolateSkin = item;
      } else {
        if (!widget.progress.purchasedHats.contains(item)) {
          widget.progress.purchasedHats.add(item);
        }
        widget.progress.selectedHat = item;
      }
      lastItem = item;
    }

    await widget.progress.save();
    widget.onUpdate();

    setState(() {
      _cart.clear();
      _purchasedItem = lastItem;
      _bounceController.forward(from: 0);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Items purchased! 🎉'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _purchasedItem = null);
    });
  }

  void _selectItem(String item) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_currentCategory == ShopCategory.skins) {
        widget.progress.selectedChocolateSkin = item;
      } else {
        widget.progress.selectedHat = item;
      }
    });
    widget.onUpdate();
    widget.progress.save();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected $item'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  List<String> get _suggestedItems {
    return _currentItems.keys
        .where((item) => !_isOwned(item) && !_cart.contains(item))
        .toList();
  }

  bool _isOwned(String item) {
    if (_currentCategory == ShopCategory.skins) {
      return widget.progress.purchasedSkins.contains(item);
    } else {
      return widget.progress.purchasedHats.contains(item);
    }
  }

  bool _isSelected(String item) {
    if (_currentCategory == ShopCategory.skins) {
      return widget.progress.selectedChocolateSkin == item;
    } else {
      return widget.progress.selectedHat == item;
    }
  }

  // ---- Preview builders ----
  Widget _buildSkinPreview(String skin) {
    Color color;
    switch (skin) {
      case 'dark':
        color = Colors.brown.shade900;
        break;
      case 'milk':
        color = Colors.brown.shade300;
        break;
      case 'white':
        color = Colors.white;
        break;
      default:
        color = Colors.brown;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: const Center(
        child: Text(
          '🍫',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildHatPreview(String hat) {
    String emoji;
    switch (hat) {
      case 'tophat':
        emoji = '🎩';
        break;
      case 'cap':
        emoji = '🧢';
        break;
      default:
        emoji = '🦕';
    }
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 24)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const Center(
                      child: ChocoDinoLogo(fontSize: 24, showIcon: true),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🛒 SHOP',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber.shade400, Colors.amber.shade600],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.5),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.white, size: 20),
                              const SizedBox(width: 5),
                              Text(
                                '${widget.progress.totalPoints}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          _buildCategoryTab(ShopCategory.skins, '🍫 Skins'),
                          _buildCategoryTab(ShopCategory.hats, '🎩 Hats'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentCategory == ShopCategory.skins
                          ? _buildSkinsGrid()
                          : _buildHatsGrid(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            // ---- "ADD MORE TO YOUR CART" UPSELL STRIP ----
            if (_cart.isNotEmpty && _suggestedItems.isNotEmpty) _buildSuggestionsStrip(),
            // ---- FIXED CART BAR ----
            if (_cart.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_cart.length} item${_cart.length > 1 ? 's' : ''} in cart',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Total: $_cartTotal pts',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _clearCart,
                          child: const Text('Clear', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: (_cartTotal > 0 && widget.progress.totalPoints >= _cartTotal)
                              ? _checkout
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: const Text('Buy All'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsStrip() {
    final previewBuilder =
        _currentCategory == ShopCategory.skins ? _buildSkinPreview : _buildHatPreview;

    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '✨ Add more to your cart',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _suggestedItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _suggestedItems[index];
                final price = _currentItems[item]!;
                return GestureDetector(
                  onTap: () => _toggleCartItem(item),
                  child: Container(
                    width: 84,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.green.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        previewBuilder(item),
                        const SizedBox(height: 4),
                        Text(
                          item.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 10, color: Colors.white),
                              Text(
                                price == 0 ? 'FREE' : '$price',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(ShopCategory category, String label) {
    final isSelected = _currentCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentCategory = category);
          HapticFeedback.selectionClick();
          _cart.clear();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.green.shade800 : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkinsGrid() {
    return _buildGrid(chocolatePrices, _buildSkinPreview);
  }

  Widget _buildHatsGrid() {
    return _buildGrid(hatPrices, _buildHatPreview);
  }

  Widget _buildGrid(Map<String, int> items, Widget Function(String) previewBuilder) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      physics: const NeverScrollableScrollPhysics(),
      children: items.keys.map((item) {
        final owned = _isOwned(item);
        final selected = _isSelected(item);
        final price = items[item]!;
        final inCart = _cart.contains(item);

        return _ShopItem(
          key: ValueKey('${_currentCategory.name}_$item'),
          name: item,
          price: price,
          owned: owned,
          selected: selected,
          inCart: inCart,
          isPurchasing: _purchasedItem == item,
          bounceController: _bounceController,
          previewChild: previewBuilder(item),
          onTapAddRemove: owned ? null : () => _toggleCartItem(item),
          onTapSelect: owned ? () => _selectItem(item) : null,
        );
      }).toList(),
    );
  }
}

// ============================================================================
// SHOP ITEM WITH CART TOGGLES
// ============================================================================

class _ShopItem extends StatefulWidget {
  final String name;
  final int price;
  final bool owned;
  final bool selected;
  final bool inCart;
  final bool isPurchasing;
  final AnimationController bounceController;
  final Widget previewChild;
  final VoidCallback? onTapAddRemove;
  final VoidCallback? onTapSelect;

  const _ShopItem({
    Key? key,
    required this.name,
    required this.price,
    required this.owned,
    required this.selected,
    required this.inCart,
    required this.isPurchasing,
    required this.bounceController,
    required this.previewChild,
    this.onTapAddRemove,
    this.onTapSelect,
  }) : super(key: key);

  @override
  State<_ShopItem> createState() => _ShopItemState();
}

class _ShopItemState extends State<_ShopItem> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = !widget.owned;
    final isSelected = widget.selected;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        if (widget.owned && widget.onTapSelect != null) {
          widget.onTapSelect!();
        } else if (!widget.owned && widget.onTapAddRemove != null) {
          widget.onTapAddRemove!();
        }
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressController, widget.bounceController]),
        builder: (context, child) {
          final pressScale = 1.0 - 0.05 * _pressController.value;
          final bounceScale = widget.isPurchasing
              ? 1.0 + 0.2 * (1 - widget.bounceController.value).abs()
              : 1.0;
          return Transform.scale(
            scale: pressScale * bounceScale,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [Colors.amber.shade300, Colors.amber.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : locked
                    ? LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Colors.white, Color(0xFFFFF8E1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.inCart
                  ? Colors.blue.shade700
                  : isSelected
                      ? Colors.amber.shade700
                      : Colors.white.withOpacity(0.6),
              width: widget.inCart ? 3 : (isSelected ? 3 : 2),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.inCart
                    ? Colors.blue.withOpacity(0.4)
                    : isSelected
                        ? Colors.amber.withOpacity(0.5)
                        : Colors.black26,
                blurRadius: widget.inCart ? 14 : (isSelected ? 14 : 6),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Opacity(
            opacity: locked ? 0.65 : 1.0,
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    widget.previewChild,
                    const SizedBox(height: 8),
                    Text(
                      widget.name.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected ? Colors.black87 : Colors.brown.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: locked ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.price == 0 ? 'FREE' : '${widget.price} pts',
                        style: TextStyle(
                          fontSize: 11,
                          color: locked ? Colors.red.shade700 : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (widget.owned)
                      ElevatedButton(
                        onPressed: widget.onTapSelect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? Colors.amber : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(40, 24),
                          textStyle: const TextStyle(fontSize: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(isSelected ? '✓ SELECTED' : 'SELECT'),
                      )
                    else
                      ElevatedButton(
                        onPressed: widget.onTapAddRemove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.inCart ? Colors.red : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(40, 24),
                          textStyle: const TextStyle(fontSize: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(widget.inCart ? 'REMOVE' : 'ADD'),
                      ),
                  ],
                ),
                if (locked)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.lock, size: 16, color: Colors.grey),
                  ),
                if (isSelected)
                  const Positioned(
                    top: 0,
                    left: 0,
                    child: Icon(Icons.check_circle, size: 20, color: Colors.green),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}