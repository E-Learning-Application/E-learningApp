import 'package:flutter/material.dart';

class MatchScoreAnimation extends StatefulWidget {
  final double score;
  final double height;
  final Duration animationDuration;

  const MatchScoreAnimation({
    Key? key,
    required this.score,
    this.height = 20,
    this.animationDuration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<MatchScoreAnimation> createState() => _MatchScoreAnimationState();
}

class _MatchScoreAnimationState extends State<MatchScoreAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.score,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Match Score: ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Text(
                    '${(_animation.value * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(_animation.value),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _animation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            _getScoreColor(_animation.value),
                            _getScoreColor(_animation.value).withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        boxShadow: [
                          BoxShadow(
                            color: _getScoreColor(_animation.value)
                                .withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) {
      return Colors.green;
    } else if (score >= 0.6) {
      return Colors.orange;
    } else if (score >= 0.4) {
      return Colors.yellow[700]!;
    } else {
      return Colors.red;
    }
  }
}
