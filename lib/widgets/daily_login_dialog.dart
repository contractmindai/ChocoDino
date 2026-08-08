import 'dart:async';
import 'package:flutter/material.dart';
import '../models/player_progress.dart';
import '../models/daily_login_reward.dart';
import '../widgets/emoji_icon.dart';

/// Shows the daily login calendar dialog if today's reward hasn't been
/// claimed yet. Returns the claimed reward, or null if the player already
/// claimed today or closed the dialog without claiming.
Future<DailyLoginReward?> maybeShowDailyLoginDialog(
  BuildContext context,
  PlayerProgress progress,
) async {
  final now = DateTime.now();
  final todayKey = dateKeyFor(now);
  if (progress.lastLoginRewardDate == todayKey) return null; // already claimed today

  final yesterdayKey = dateKeyFor(now.subtract(const Duration(days: 1)));
  final continuesStreak = progress.lastLoginRewardDate == yesterdayKey;
  final streakDayIfClaimed = continuesStreak ? progress.loginStreak + 1 : 1;

  if (!context.mounted) return null;
  return showDialog<DailyLoginReward>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _DailyLoginDialog(
      progress: progress,
      streakDayIfClaimed: streakDayIfClaimed,
      todayKey: todayKey,
    ),
  );
}

class _DailyLoginDialog extends StatefulWidget {
  final PlayerProgress progress;
  final int streakDayIfClaimed;
  final String todayKey;

  const _DailyLoginDialog({
    required this.progress,
    required this.streakDayIfClaimed,
    required this.todayKey,
  });

  @override
  State<_DailyLoginDialog> createState() => _DailyLoginDialogState();
}

class _DailyLoginDialogState extends State<_DailyLoginDialog>
    with SingleTickerProviderStateMixin {
  bool _claimed = false;

  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _claim() {
    final reward = dailyLoginRewardForStreak(widget.streakDayIfClaimed);
    widget.progress.totalPoints += reward.coinAmount;
    widget.progress.loginStreak = widget.streakDayIfClaimed;
    widget.progress.lastLoginRewardDate = widget.todayKey;
    if (widget.progress.loginStreak > widget.progress.bestLoginStreak) {
      widget.progress.bestLoginStreak = widget.progress.loginStreak;
    }
    unawaited(widget.progress.save());
    setState(() => _claimed = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.pop(context, reward);
    });
  }

  @override
  Widget build(BuildContext context) {
    final positionInCycle =
        ((widget.streakDayIfClaimed - 1) % kDailyLoginRewards.length) + 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _entry,
        builder: (context, child) {
          final t = Curves.easeOutBack.transform(_entry.value.clamp(0.0, 1.0));
          return Transform.scale(
            scale: 0.85 + 0.15 * t,
            child: Opacity(opacity: _entry.value.clamp(0.0, 1.0), child: child),
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, minWidth: 280),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0, 0.5, 1],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.16), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: const Color(0xFFFFD54F).withOpacity(0.18),
                  blurRadius: 60,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  // Ambient decorative glow — purely cosmetic depth, no assets needed.
                  Positioned(
                    top: -50,
                    right: -40,
                    child: _glowCircle(140, const Color(0xFFFFF176).withOpacity(0.16)),
                  ),
                  Positioned(
                    bottom: -60,
                    left: -30,
                    child: _glowCircle(150, Colors.white.withOpacity(0.06)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cardCount = kDailyLoginRewards.length;
                        const cardHMargin = 4.0; // 2px padding on each side, per card
                        const minCardWidth = 48.0;
                        const maxCardWidth = 76.0;
                        final rawCardWidth =
                            (constraints.maxWidth - cardHMargin * cardCount) / cardCount;
                        final cardWidth = rawCardWidth.clamp(minCardWidth, maxCardWidth);
                        final rowContentWidth =
                            cardWidth * cardCount + cardHMargin * cardCount;

                        final dayFontSize = (cardWidth / 6.4).clamp(8.0, 11.0);
                        final emojiFontSize = (cardWidth / 2.8).clamp(16.0, 24.0);
                        final coinFontSize = (cardWidth / 6.0).clamp(8.5, 12.0);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Header(streakDay: widget.streakDayIfClaimed),
                            const SizedBox(height: 18),
                            // Even with correct math, an unusual device width or a
                            // large text-scale factor could still make the cards
                            // too wide — scroll instead of overflowing in that
                            // case, but stay centered and static normally.
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: rowContentWidth > constraints.maxWidth
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(cardCount, (i) {
                                    final dayNum = i + 1;
                                    final reward = kDailyLoginRewards[i];
                                    final isPast = dayNum < positionInCycle;
                                    final isToday = dayNum == positionInCycle;
                                    final isFuture = dayNum > positionInCycle;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: _DayCard(
                                        reward: reward,
                                        dayNum: dayNum,
                                        isPast: isPast,
                                        isToday: isToday,
                                        isFuture: isFuture,
                                        justClaimed: isToday && _claimed,
                                        width: cardWidth,
                                        dayFontSize: dayFontSize,
                                        emojiFontSize: emojiFontSize,
                                        coinFontSize: coinFontSize,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _ClaimButton(claimed: _claimed, onPressed: _claim),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => Navigator.pop(context, null),
                              child: Text(
                                _claimed ? 'Close' : 'Maybe later',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Badge + title header, replacing a bare emoji-and-text row with a proper
/// bevelled icon badge and letter-spaced game-style title.
class _Header extends StatelessWidget {
  final int streakDay;
  const _Header({required this.streakDay});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE082), Color(0xFFFFA000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8F00).withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(child: EmojiIcon('🎁', size: 30)),
        ),
        const SizedBox(height: 10),
        const Text(
          'DAILY REWARDS',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.8,
            shadows: [Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmojiIcon('🔥', size: 15),
              const SizedBox(width: 6),
              Text(
                '$streakDay day streak',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gentle continuous scale pulse — used to draw the eye to today's claimable
/// card without being distracting.
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + 0.045 * _controller.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _DayCard extends StatelessWidget {
  final DailyLoginReward reward;
  final int dayNum;
  final bool isPast;
  final bool isToday;
  final bool isFuture;
  final bool justClaimed;
  final double width;
  final double dayFontSize;
  final double emojiFontSize;
  final double coinFontSize;

  const _DayCard({
    required this.reward,
    required this.dayNum,
    required this.isPast,
    required this.isToday,
    required this.isFuture,
    required this.justClaimed,
    required this.width,
    required this.dayFontSize,
    required this.emojiFontSize,
    required this.coinFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        gradient: isToday
            ? const LinearGradient(
                colors: [Color(0xFFFFE082), Color(0xFFFFA000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: isToday
            ? null
            : (isPast ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.14)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.12),
          width: isToday ? 2 : 1,
        ),
        // A hard-edged, unblurred bottom shadow reads as a chunky physical
        // "chip" rather than a flat rectangle — classic mobile-game chrome.
        boxShadow: [
          BoxShadow(
            color: isToday
                ? const Color(0xFFE65100).withOpacity(0.7)
                : Colors.black.withOpacity(0.25),
            offset: const Offset(0, 3),
          ),
          if (isToday)
            BoxShadow(
              color: const Color(0xFFFFD54F).withOpacity(0.55),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DAY $dayNum',
            style: TextStyle(
              fontSize: dayFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: isToday ? const Color(0xFF6D4C00) : Colors.white.withOpacity(isFuture ? 0.5 : 0.9),
            ),
          ),
          const SizedBox(height: 5),
          if (isPast || justClaimed)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: justClaimed ? 0.0 : 1.0, end: 1.0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Icon(
                Icons.check_circle_rounded,
                color: isToday ? const Color(0xFF6D4C00) : const Color(0xFF69F0AE),
                size: emojiFontSize * 1.15,
              ),
            )
          else if (isFuture)
            Icon(
              Icons.lock_rounded,
              color: Colors.white.withOpacity(0.35),
              size: emojiFontSize * 0.85,
            )
          else
            EmojiIcon(reward.emoji, size: emojiFontSize),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isToday ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+${reward.coinAmount}',
              style: TextStyle(
                fontSize: coinFontSize,
                fontWeight: FontWeight.bold,
                color: isToday ? const Color(0xFF6D4C00) : Colors.white.withOpacity(isFuture ? 0.5 : 0.85),
              ),
            ),
          ),
        ],
      ),
    );

    if (isToday && !justClaimed) return _Pulse(child: card);
    return card;
  }
}

/// The primary claim button, styled as a chunky gold chip with the same
/// hard-edged bevel shadow used on today's day card, so the two visually
/// agree with each other as "the thing you're meant to tap."
class _ClaimButton extends StatelessWidget {
  final bool claimed;
  final VoidCallback onPressed;
  const _ClaimButton({required this.claimed, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: claimed ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: claimed
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: claimed ? Colors.white.withOpacity(0.15) : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: claimed ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: claimed
                ? []
                : [
                    BoxShadow(color: const Color(0xFFE65100).withOpacity(0.7), offset: const Offset(0, 4)),
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Row(
                key: ValueKey(claimed),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    claimed ? Icons.check_circle_rounded : Icons.card_giftcard_rounded,
                    color: claimed ? Colors.white70 : const Color(0xFF6D4C00),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    claimed ? 'Claimed!' : 'Claim Reward',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: claimed ? Colors.white70 : const Color(0xFF6D4C00),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}