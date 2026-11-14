import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../data/models/comment_model.dart';
import '../data/services/comment_service.dart';
import 'banana_status_icon.dart';

class AddCommentBottomSheet extends StatefulWidget {
  final int movieId;
  final String movieTitle;

  const AddCommentBottomSheet({
    super.key,
    required this.movieId,
    required this.movieTitle,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddCommentBottomSheet(
        movieId: movieId,
        movieTitle: movieTitle,
      ),
    );
  }

  @override
  State<AddCommentBottomSheet> createState() => _AddCommentBottomSheetState();
}

class _AddCommentBottomSheetState extends State<AddCommentBottomSheet> {
  final CommentService _commentService = CommentService();
  final TextEditingController _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  double _rating = 5.0; // Skala 1.0 - 5.0 (Rotten Tomatoes audience rating)
  bool _isSubmitting = false;
  String? _errorMessage;

  String get _currentVerdict => CommentModel.verdictFromRating(_rating);

  Color get _currentVerdictColor {
    if (_rating >= 4.0) {
      return AppColors.statusFresh;
    } else if (_rating >= 3.0) {
      return AppColors.statusBruised;
    } else {
      return AppColors.statusRotten;
    }
  }

  String get _currentVerdictLabel {
    if (_rating >= 5.0) {
      return 'Top Markotop';
    } else if (_rating >= 4.0) {
      return 'Cakep';
    } else if (_rating >= 3.0) {
      return 'Medioker';
    } else if (_rating >= 2.0) {
      return 'Kureng';
    } else {
      return 'Ampas';
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final content = _contentController.text.trim();
    if (content.length < 3) {
      setState(() => _errorMessage = 'Ulasan minimal 3 karakter.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _commentService.addComment(
        movieId: widget.movieId,
        content: content,
        rating: _rating,
        bananaVerdict: _currentVerdict,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag bar indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentYellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('🍌', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tulis Ulasan Film',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.movieTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Rating Bintang (Rotten Tomatoes Audience Style)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rating Film (Bintang):',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Text(
                      '${_rating.toInt()} / 5 Bintang',
                      style: const TextStyle(
                        color: AppColors.accentYellow,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Interactive Star Rating Bar & Dynamic Banana Verdict Indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.inputBorder, width: 0.8),
                ),
                child: Column(
                  children: [
                    // 5 Bintang Interaktif
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = (index + 1).toDouble();
                        final isFilled = starValue <= _rating;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _rating = starValue;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            child: AnimatedScale(
                              scale: isFilled ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 38,
                                color: isFilled ? AppColors.accentYellow : AppColors.textMuted,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),

                    // Badge Status Penilaian Berkarakter Pisang
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _currentVerdictColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _currentVerdictColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BananaStatusIcon(rating: _rating, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _currentVerdictLabel,
                            style: TextStyle(
                              color: _currentVerdictColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Input TextField
              const Text(
                'Pendapat / Ulasan Anda:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _contentController,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ceritakan trailer atau film ini... Apakah layak ditonton di bioskop?',
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.all(14),
                  counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentYellow, width: 1.2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.statusRotten),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.statusRotten, width: 1.2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ulasan tidak boleh kosong.';
                  }
                  if (val.trim().length < 3) {
                    return 'Ulasan minimal 3 karakter.';
                  }
                  return null;
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.statusRotten, fontSize: 12),
                ),
              ],

              const SizedBox(height: 14),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentYellow,
                    disabledBackgroundColor: AppColors.accentYellow.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'Kirim Ulasan',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
