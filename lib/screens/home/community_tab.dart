import 'package:flutter/material.dart';
import '../../app/theme.dart';

class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Text('커뮤니티', style: WeRoboTypography.heading2),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: WeRoboColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('글쓰기',
                        style: WeRoboTypography.caption.copyWith(
                            color: WeRoboColors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: const [
                _CategoryChip(label: '전체', isActive: true),
                SizedBox(width: 8),
                _CategoryChip(label: '토론'),
                SizedBox(width: 8),
                _CategoryChip(label: '뉴스'),
                SizedBox(width: 8),
                _CategoryChip(label: '전략'),
                SizedBox(width: 8),
                _CategoryChip(label: '초보 질문'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Posts list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              children: const [
                _PostCard(
                  tag: '토론',
                  tagColor: Color(0xFF5B8DEF),
                  title: '요즘 S&P 500 하락장인데 리밸런싱 타이밍 어떻게 잡으시나요?',
                  author: '투자초보Kim',
                  time: '2시간 전',
                  likes: 24,
                  comments: 12,
                ),
                _PostCard(
                  tag: '뉴스',
                  tagColor: Color(0xFF20A7DB),
                  title: 'Fed 금리 동결 결정, 포트폴리오 전략에 미치는 영향',
                  author: 'MarketWatch',
                  time: '5시간 전',
                  likes: 47,
                  comments: 8,
                ),
                _PostCard(
                  tag: '전략',
                  tagColor: Color(0xFF9B7FCC),
                  title: '균형형 포트폴리오에서 금 비중을 15%로 올리는 건 어떨까요?',
                  author: 'GoldBug2026',
                  time: '어제',
                  likes: 31,
                  comments: 19,
                ),
                _PostCard(
                  tag: '초보 질문',
                  tagColor: Color(0xFF34D399),
                  title: '이피션트 프론티어가 정확히 뭔가요? 쉽게 설명 부탁드립니다',
                  author: '주식시작',
                  time: '어제',
                  likes: 56,
                  comments: 23,
                ),
                _PostCard(
                  tag: '토론',
                  tagColor: Color(0xFF5B8DEF),
                  title: '미국 성장주 vs 가치주, 2026년 후반기 전망',
                  author: 'ValueHunter',
                  time: '2일 전',
                  likes: 38,
                  comments: 15,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isActive;

  const _CategoryChip({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? WeRoboColors.primary : WeRoboColors.card,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? null
            : Border.all(color: WeRoboColors.lightGray, width: 0.5),
      ),
      child: Text(
        label,
        style: WeRoboTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: isActive ? WeRoboColors.white : WeRoboColors.textSecondary,
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final String tag;
  final Color tagColor;
  final String title;
  final String author;
  final String time;
  final int likes;
  final int comments;

  const _PostCard({
    required this.tag,
    required this.tagColor,
    required this.title,
    required this.author,
    required this.time,
    required this.likes,
    required this.comments,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WeRoboColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tag + time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(widget.tag,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.tagColor)),
                  ),
                  const Spacer(),
                  Text(widget.time, style: WeRoboTypography.caption),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                widget.title,
                style: WeRoboTypography.bodySmall.copyWith(
                  color: WeRoboColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Author + stats
              Row(
                children: [
                  Text(widget.author,
                      style: WeRoboTypography.caption.copyWith(
                          color: WeRoboColors.textSecondary)),
                  const Spacer(),
                  Icon(Icons.favorite_border_rounded,
                      size: 14, color: WeRoboColors.textTertiary),
                  const SizedBox(width: 3),
                  Text('${widget.likes}',
                      style: WeRoboTypography.caption),
                  const SizedBox(width: 12),
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 14, color: WeRoboColors.textTertiary),
                  const SizedBox(width: 3),
                  Text('${widget.comments}',
                      style: WeRoboTypography.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
