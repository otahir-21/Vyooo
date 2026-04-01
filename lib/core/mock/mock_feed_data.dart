/// Model for a single feed post (video). UI-only; prepare for video controller later.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.userAvatarUrl,
    required this.username,
    required this.userHandle,
    required this.caption,
    required this.likeCount,
    required this.viewCount,
    required this.commentCount,
    required this.thumbnailUrl,
    this.videoUrl = '',
  });

  final String id;
  final String userAvatarUrl;
  final String username;
  final String userHandle;
  final String caption;
  final int likeCount;
  final int viewCount;
  final int commentCount;
  final String thumbnailUrl;
  final String videoUrl;
}

/// Dummy feed data for UI. Replace with real data/controller later.
const List<FeedPost> mockFeedItems = [
  FeedPost(
    id: 'feed1',
    userAvatarUrl: 'https://i.pravatar.cc/100?img=1',
    username: 'Sofia Wells',
    userHandle: '@sofwells3',
    caption: 'The Summer where I turned pretty...',
    likeCount: 12800000,
    viewCount: 12500000,
    commentCount: 256,
    thumbnailUrl: 'https://picsum.photos/400/800?random=1',
  ),
  FeedPost(
    id: 'feed2',
    userAvatarUrl: 'https://i.pravatar.cc/100?img=2',
    username: 'Alex Rivera',
    userHandle: '@alexr',
    caption: 'Golden hour vibes only 🌅',
    likeCount: 892000,
    viewCount: 2100000,
    commentCount: 1204,
    thumbnailUrl: 'https://picsum.photos/400/800?random=2',
  ),
  FeedPost(
    id: 'feed3',
    userAvatarUrl: 'https://i.pravatar.cc/100?img=3',
    username: 'Jordan Lee',
    userHandle: '@jordanlee',
    caption: 'Weekend mood 🎬',
    likeCount: 456000,
    viewCount: 980000,
    commentCount: 567,
    thumbnailUrl: 'https://picsum.photos/400/800?random=3',
  ),
  FeedPost(
    id: 'feed4',
    userAvatarUrl: 'https://i.pravatar.cc/100?img=4',
    username: 'Morgan Blake',
    userHandle: '@morganb',
    caption: 'New drop coming soon 👀',
    likeCount: 2340000,
    viewCount: 5400000,
    commentCount: 892,
    thumbnailUrl: 'https://picsum.photos/400/800?random=4',
  ),
  FeedPost(
    id: 'feed5',
    userAvatarUrl: 'https://i.pravatar.cc/100?img=5',
    username: 'Casey Kim',
    userHandle: '@caseykim',
    caption: 'Behind the scenes #vyooo',
    likeCount: 678000,
    viewCount: 1200000,
    commentCount: 334,
    thumbnailUrl: 'https://picsum.photos/400/800?random=5',
  ),
];

/// Dummy story avatars for the horizontal list (id + image URL).
const List<Map<String, String>> mockStoryAvatars = [
  {'id': 's1', 'url': 'https://i.pravatar.cc/100?img=10'},
  {'id': 's2', 'url': 'https://i.pravatar.cc/100?img=11'},
  {'id': 's3', 'url': 'https://i.pravatar.cc/100?img=12'},
  {'id': 's4', 'url': 'https://i.pravatar.cc/100?img=13'},
  {'id': 's5', 'url': 'https://i.pravatar.cc/100?img=14'},
];
