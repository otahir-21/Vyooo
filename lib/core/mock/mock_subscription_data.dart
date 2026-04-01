/// UI model for a subscription plan (mock or mapped from RevenueCat).
class SubscriptionUIModel {
  final String id;
  final String title;
  final String price;
  final bool isPopular;

  const SubscriptionUIModel({
    required this.id,
    required this.title,
    required this.price,
    this.isPopular = false,
  });
}

/// Mock plans for development when RevenueCat offerings are empty or [AppConfig.useMockSubscriptions] is true.
/// Three plans only: Standard, Subscriber, Creator (no Free plan).
const mockSubscriptionPlans = [
  SubscriptionUIModel(
    id: 'standard',
    title: 'Standard',
    price: 'FREE',
  ),
  SubscriptionUIModel(
    id: 'subscriber',
    title: 'Subscriber',
    price: '\$4.99/M',
    isPopular: true,
  ),
  SubscriptionUIModel(
    id: 'creator',
    title: 'Creator',
    price: '\$19.99/M',
  ),
];
