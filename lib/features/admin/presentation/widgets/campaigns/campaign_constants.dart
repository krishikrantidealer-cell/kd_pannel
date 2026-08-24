import 'package:flutter/material.dart';

class CampaignConstants {
  static const List<Map<String, String>> defaultDeepLinkRoutes = [
    {
      'route': '/dashboard',
      'label': '🏠 Home & Flash Deals (/dashboard)',
      'defaultBtn': '🌾 Explore Deals',
    },
    {
      'route': '/products',
      'label': '🌾 Product Catalogue & Agrochemicals (/products)',
      'defaultBtn': '📦 View Catalog',
    },
    {
      'route': '/kyc',
      'label': '📋 KYC Verification & Margin Unlock (/kyc)',
      'defaultBtn': '⚡ Complete KYC',
    },
    {
      'route': '/cart',
      'label': '🛒 Cart & Bulk Wholesale Checkout (/cart)',
      'defaultBtn': '🛒 Open Cart',
    },
    {
      'route': '/orders',
      'label': '📦 My Orders & Live Tracking (/orders)',
      'defaultBtn': '📦 View Orders',
    },
    {
      'route': '/coupons',
      'label': '🏷️ Price Coupons & Discount Vouchers (/coupons)',
      'defaultBtn': '🏷️ Claim Coupon',
    },
    {
      'route': '/favorites',
      'label': '❤️ Wishlist & Saved Products (/favorites)',
      'defaultBtn': '❤️ View Wishlist',
    },
    {
      'route': '/notifications',
      'label': '🔔 In-App Offers & Notification Inbox (/notifications)',
      'defaultBtn': '🔔 Open Inbox',
    },
    {
      'route': '/search',
      'label': '🔍 Search Products & Brands (/search)',
      'defaultBtn': '🔍 Search Now',
    },
    {
      'route': '/profile',
      'label': '👤 Dealer Profile & Margin Level (/profile)',
      'defaultBtn': '👤 My Profile',
    },
    {
      'route': '/edit-profile',
      'label': '🏪 Edit Shop Name & License (/edit-profile)',
      'defaultBtn': '🏪 Update Shop',
    },
    {
      'route': '/shipping-address',
      'label': '📍 Delivery & Warehouse Addresses (/shipping-address)',
      'defaultBtn': '📍 Addresses',
    },
    {
      'route': '/contact',
      'label': '📞 WhatsApp Support & Dealer Helpline (/contact)',
      'defaultBtn': '📞 Contact Us',
    },
  ];

  static const List<Map<String, String>> quickCopyPresets = [
    {
      'category': 'Seasonal & Surge',
      'title': '🌧️ भारी बारिश का अलर्ट! फफूंदनाशक का स्टॉक तुरंत बढ़ाएं 🌾',
      'body':
          'नमस्ते {{name}} जी, {{shopName}} के लिए Fungicides व Weedicides पर आज भारी थोक छूट और एक्स्ट्रा मार्जिन उपलब्ध है!',
      'route': '/products',
      'btn1': '📦 स्टॉक चेक करें',
    },
    {
      'category': 'KYC Onboarding',
      'title': '⚡ {{name}} जी, KYC पूरा करें और 15% तक थोक मार्जिन पाएं!',
      'body':
          '{{shopName}} का फर्टिलाइजर/कीटनाशक लाइसेंस अपलोड करें और होलसेल रेट्स तुरंत अनलॉक करें।',
      'route': '/kyc',
      'btn1': '📋 KYC पूरा करें',
    },
    {
      'category': 'Cart Recovery',
      'title':
          '🛒 {{name}} जी, आपकी कार्ट में सामान बचा हुआ है! स्टॉक सीमित है',
      'body':
          '{{shopName}} के चुने हुए प्रोडक्ट्स पर स्पेशल बल्क डिस्काउंट अभी भी लागू है। अभी ऑर्डर कन्फर्म करें।',
      'route': '/cart',
      'btn1': '🛒 कार्ट खोलें',
    },
    {
      'category': 'VIP Re-engagement',
      'title': '💎 VIP डीलर स्पेशल ऑफर: {{city}} के लिए खास क्रेडिट स्कीम!',
      'body':
          'नमस्ते {{name}} जी, {{shopName}} के लिए आज स्पेशल प्री-पेमेंट डिस्काउंट और प्रायोरिटी डिस्पैच उपलब्ध है।',
      'route': '/dashboard',
      'btn1': '🌾 ऑफर देखें',
    },
    {
      'category': 'Scheme & Discount',
      'title': '🔥 सीमित समय: 50 बैग्स पर 2 बैग्स मुफ्त + 5% एक्स्ट्रा कैशबैक',
      'body':
          '{{name}} जी, आज ही अपनी दुकान {{shopName}} के लिए सीजनल लॉट बुक करें। ऑफर स्टॉक रहने तक।',
      'route': '/coupons',
      'btn1': '🏷️ कूपन लागू करें',
    },
  ];

  static const List<Map<String, dynamic>> targetingPresets = [
    {
      'key': 'KYC_PENDING',
      'name': 'Pre-KYC Leads (0 Docs)',
      'desc': 'Leads who registered but have not uploaded documents yet.',
      'cat': 'kyc',
      'route': '/kyc',
      'icon': Icons.assignment_late_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'key': 'CART_DROP',
      'name': 'Cart Abandonment',
      'desc': 'Dealers with active items left in wholesale cart > 30 mins.',
      'cat': 'cart',
      'route': '/cart',
      'icon': Icons.shopping_cart_checkout_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'key': 'NEW_SIGNUP',
      'name': 'Day 1 Onboarding',
      'desc': 'Dealers registered in the last 24 hours needing welcome nudge.',
      'cat': 'growth',
      'route': '/dashboard',
      'icon': Icons.fiber_new_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'key': 'SEASONAL_BLAST',
      'name': 'Seasonal Monsoon Surge',
      'desc': 'Monsoon crop protection & fungicide blast for all dealers.',
      'cat': 'seasonal',
      'route': '/products',
      'icon': Icons.cloudy_snowing,
      'color': Color(0xFF0EA5E9),
    },
    {
      'key': 'DORMANT_RECOVERY',
      'name': 'Dormant Dealer Win-Back',
      'desc': 'Dealers with no orders in past 45 days.',
      'cat': 'retention',
      'route': '/coupons',
      'icon': Icons.history_toggle_off_rounded,
      'color': Color(0xFFEF4444),
    },
    {
      'key': 'REPEAT_BUYERS',
      'name': 'Repeat Buyers (Loyalty)',
      'desc': 'Dealers who ordered at least once in the last 30 days.',
      'cat': 'loyalty',
      'route': '/products',
      'icon': Icons.repeat_rounded,
      'color': Color(0xFF6366F1),
    },
  ];

  static String replaceVariables(
    String text, {
    String name = 'Ramesh Patel',
    String shopName = 'Kisan Krishi Kendra',
    String city = 'Indore',
  }) {
    return text
        .replaceAll('{{name}}', name)
        .replaceAll('{{shopName}}', shopName)
        .replaceAll('{{city}}', city)
        .replaceAll('{name}', name)
        .replaceAll('{shopName}', shopName)
        .replaceAll('{city}', city);
  }
}
