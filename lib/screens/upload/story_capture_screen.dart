import 'package:flutter/material.dart';

class StoryCaptureScreen extends StatefulWidget {
  const StoryCaptureScreen({super.key});

  @override
  State<StoryCaptureScreen> createState() => _StoryCaptureScreenState();
}

class _StoryCaptureScreenState extends State<StoryCaptureScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview Placeholder
          Image.network(
            'https://images.unsplash.com/photo-1510414842594-a61c69b5ae57?auto=format&fit=crop&q=80&w=1000',
            fit: BoxFit.cover,
          ),

          // 2. Translucent Gradients
          _buildGradients(),

          // 3. Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
                Row(
                  children: [
                    Icon(Icons.flash_off_rounded, color: Colors.white.withValues(alpha: 0.9), size: 24),
                    const SizedBox(width: 20),
                    Icon(Icons.settings_outlined, color: Colors.white.withValues(alpha: 0.9), size: 24),
                  ],
                ),
              ],
            ),
          ),

          // 4. Capture Controls
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 60), // Balance for gallery icon
                // Large Capture Button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StoryPreviewScreen()),
                    );
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                // Gallery Icon
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom Tabs
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomModeSelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildGradients() {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomModeSelector() {
    return Container(
      height: 100,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E0A1E),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _modeItem(Icons.videocam_rounded, 'Story', true),
          const SizedBox(width: 20),
          _modeItem(Icons.grid_view_rounded, 'Gallery', false),
          const SizedBox(width: 20),
          _modeItem(Icons.sensors_rounded, 'Live', false),
        ],
      ),
    );
  }

  Widget _modeItem(IconData icon, String label, bool selected) {
    return GestureDetector(
      onTap: () {
        if (label == 'Gallery') Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDE106B) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StoryPreviewScreen extends StatefulWidget {
  const StoryPreviewScreen({super.key});

  @override
  State<StoryPreviewScreen> createState() => _StoryPreviewScreenState();
}

class _StoryPreviewScreenState extends State<StoryPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _captionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Captured Image
          Image.network(
            'https://images.unsplash.com/photo-1510414842594-a61c69b5ae57?auto=format&fit=crop&q=80&w=1000',
            fit: BoxFit.cover,
          ),

          // 2. Translucent Overlays when editing
          if (_isEditing || keyboardVisible)
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),

          // 3. Caption UI
          Positioned(
            left: 20,
            right: 20,
            bottom: keyboardVisible ? MediaQuery.of(context).viewInsets.bottom + 120 : 160,
            child: _isEditing || keyboardVisible
                ? TextField(
                    controller: _captionController,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(color: Colors.white60),
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() => _isEditing = true);
                      _focusNode.requestFocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          'Add a caption +',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          // 4. Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),

          // 5. Post Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildPostBar(keyboardVisible),
          ),
        ],
      ),
    );
  }

  Widget _buildPostBar(bool keyboardVisible) {
    double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E0A1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!keyboardVisible) ...[
            const SizedBox(height: 12),
            _buildThumbnailList(),
          ],
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: keyboardVisible ? bottomInset + 16 : MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Row(
              children: [
                Icon(Icons.photo_library_outlined, color: Colors.white.withValues(alpha: 0.9), size: 24),
                const SizedBox(width: 24),
                Icon(Icons.camera_alt_outlined, color: Colors.white.withValues(alpha: 0.9), size: 24),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StoryViewScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDE106B),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Text(
                      'Post',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailList() {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _thumb('https://picsum.photos/100/150', true),
          _thumb('https://picsum.photos/101/151', false),
          _thumb('https://picsum.photos/102/152', false),
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _thumb(String url, bool selected) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: selected ? Border.all(color: const Color(0xFFDE106B), width: 2) : null,
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: selected ? Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.black, size: 10),
        ),
      ) : null,
    );
  }
}

// ── Story Viewer ─────────────────────────────────────────────────────────────

class StoryViewScreen extends StatefulWidget {
  const StoryViewScreen({super.key});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  int _currentIndex = 0;
  final int _totalItems = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Content (Full screen or square centered)
          _currentIndex == 1 
            ? Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network('https://picsum.photos/800', fit: BoxFit.cover),
                ),
              )
            : Image.network(
                'https://images.unsplash.com/photo-1510414842594-a61c69b5ae57?auto=format&fit=crop&q=80&w=1000',
                fit: BoxFit.cover,
              ),

          // 2. Gradients
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // 3. Segmented Progress Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: Row(
              children: List.generate(_totalItems, (i) => Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= _currentIndex ? Colors.white : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ),

          // 4. Header Info
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                const CircleAvatar(radius: 18, backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=a')),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lexilongbottom', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('33m', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),

          // 5. Caption Overlay
          if (_currentIndex != 1)
            const Positioned(
              bottom: 60,
              left: 40,
              right: 40,
              child: Text(
                'A beautiful setting for the love of my life, it\'s today when I ask her to marry me! Wish me luck',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),

          // 6. Navigation Taps
          Positioned.fill(
            child: Row(
              children: [
                Expanded(child: GestureDetector(onTap: () => setState(() => _currentIndex = (_currentIndex - 1).clamp(0, _totalItems - 1)))),
                Expanded(child: GestureDetector(onTap: () => setState(() => _currentIndex = (_currentIndex + 1).clamp(0, _totalItems - 1)))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
