import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/repositories/campaign_repository.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/push_campaigns_state.dart';

class PushCampaignsBloc
    extends Bloc<PushCampaignsEvent, PushCampaignsState> {
  final CampaignRepository _campaignRepo = CampaignRepository();
  PushCampaignsBloc() : super(const PushCampaignsState()) {
    on<FetchPushCampaignsEvent>(_onFetchPushCampaigns);
    on<SelectCampaignEvent>(_onSelectCampaign);
    on<ToggleCampaignEnabledEvent>(_onToggleCampaignEnabled);
    on<UpdateCampaignScheduleEvent>(_onUpdateCampaignSchedule);
    on<UpdateCampaignConfigEvent>(_onUpdateCampaignConfig);
    on<CreateCampaignSegmentEvent>(_onCreateCampaignSegment);
    on<DeleteCampaignSegmentEvent>(_onDeleteCampaignSegment);
    on<AddCampaignTemplateEvent>(_onAddCampaignTemplate);
    on<UpdateCampaignTemplateEvent>(_onUpdateCampaignTemplate);
    on<DeleteCampaignTemplateEvent>(_onDeleteCampaignTemplate);
    on<ReorderCampaignTemplatesEvent>(_onReorderCampaignTemplates);
    on<TogglePinTemplateEvent>(_onTogglePinTemplate);
    on<TriggerBroadcastEvent>(_onTriggerBroadcast);
    on<SendTestPushEvent>(_onSendTestPush);
    on<ClearPushCampaignsMessageEvent>(_onClearMessage);
    on<ResetPushCampaignsEvent>(_onReset);
  }

  static const List<Map<String, String>> _defaultTargetRules = [
    {
      'code': 'KYC_NOT_SUBMITTED',
      'label': '📄 KYC Not Started (App Installed → 0 Docs Uploaded)',
      'desc': 'Leads who downloaded the app but haven\'t uploaded any KYC documents.',
      'category': 'kyc',
      'suggestedRoute': '/kyc',
      'suggestedBtn': '⚡ Complete KYC',
    },
    {
      'code': 'KYC_UNDER_REVIEW',
      'label': '⏳ KYC Under Review (Docs Uploaded → Pending Admin Approval)',
      'desc': 'Leads whose KYC documents were submitted and are in the review queue.',
      'category': 'kyc',
      'suggestedRoute': '/kyc',
      'suggestedBtn': '🔍 Check Status',
    },
    {
      'code': 'KYC_REJECTED',
      'label': '❌ KYC Rejected / Needs Re-upload',
      'desc': 'Leads whose submitted KYC documents were rejected and need to re-upload.',
      'category': 'kyc',
      'suggestedRoute': '/kyc',
      'suggestedBtn': '📄 Re-upload Docs',
    },
    {
      'code': 'VERIFIED_ZERO_ORDERS',
      'label': '🎉 Verified Dealers → Never Placed an Order',
      'desc': 'Dealers whose KYC is approved but haven\'t placed their 1st order yet.',
      'category': 'marketing',
      'suggestedRoute': '/dashboard',
      'suggestedBtn': '🛍️ 1st Order Offer',
    },
    {
      'code': 'ABANDONED_CART',
      'label': '🛒 Cart Abandoned (Items in Cart → No Checkout)',
      'desc': 'Dealers with active items in their wholesale cart left unpaid for > 30 minutes.',
      'category': 'cart',
      'suggestedRoute': '/cart',
      'suggestedBtn': '🛒 Open Cart',
    },
    {
      'code': 'INACTIVE_15_30D',
      'label': '⚠️ Inactive Dealers (No Order in Last 15–30 Days)',
      'desc': 'Dealers who previously ordered but have been inactive for 15 to 30 days.',
      'category': 're-engagement',
      'suggestedRoute': '/dashboard',
      'suggestedBtn': '🌾 Restock Now',
    },
    {
      'code': 'DORMANT_30D_PLUS',
      'label': '💤 Dormant Dealers (No Order in 30+ Days)',
      'desc': 'Verified dealers with zero orders placed in the last 30 days.',
      'category': 're-engagement',
      'suggestedRoute': '/dashboard',
      'suggestedBtn': '🎁 Welcome Back',
    },
    {
      'code': 'ACTIVE_REPEAT_BUYERS',
      'label': '🔥 Active Repeat Buyers (≥ 2 Lifetime Orders)',
      'desc': 'Active wholesale buyers who frequently purchase agrochemicals.',
      'category': 'marketing',
      'suggestedRoute': '/dashboard',
      'suggestedBtn': '🆕 New Arrivals',
    },
    {
      'code': 'VIP_HIGH_VOLUME',
      'label': '💎 VIP / High Volume (GMV ≥ ₹50,000)',
      'desc': 'High GMV bulk buyers who generate high platform revenue.',
      'category': 'marketing',
      'suggestedRoute': '/dashboard',
      'suggestedBtn': '💎 VIP Margin',
    },
    {
      'code': 'ALL_DEALERS',
      'label': '📢 All Registered App Users (Broadcast)',
      'desc': 'Network-wide broadcast to every registered dealer with an active FCM token.',
      'category': 'general',
      'suggestedRoute': '/dashboard',
      'suggestedBtn': '⚡ Open Offer',
    },
    {
      'code': 'CUSTOM',
      'label': '⚙️ Custom Filter / Audience Rule (Write Below)...',
      'desc': 'Custom rule specified by administrator.',
      'category': 'general',
      'suggestedRoute': '/dashboard',
      'suggestedBtn': '⚡ Open Offer',
    },
  ];

  static const List<Map<String, String>> _defaultCategories = [
    {'value': 'kyc', 'label': '📋 KYC & Onboarding'},
    {'value': 'cart', 'label': '🛒 Cart & Checkout Recovery'},
    {'value': 'orders', 'label': '📦 Order & Purchase Lifecycle'},
    {'value': 'marketing', 'label': '🌾 Marketing & Catalog Discovery'},
    {'value': 'promotional', 'label': '🏷️ Promotional & Margin Flash Deals'},
    {'value': 'seasonal', 'label': '🌧️ Seasonal Surge & Demand'},
    {'value': 're-engagement', 'label': '🔄 Win-Back & Re-engagement'},
    {'value': 'general', 'label': '📢 General Broadcast'},
  ];

  Future<void> _onFetchPushCampaigns(
    FetchPushCampaignsEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    if (!event.forceRefresh && state.status == PushCampaignsStatus.success) {
      // Background silent refresh
    } else {
      emit(state.copyWith(status: PushCampaignsStatus.loading));
    }

    try {
      final payload = await _campaignRepo.fetchFullMarketingPayload();
      final rawData = payload['campaignsData'] as Map<String, dynamic>? ?? {};
      final bannersList = payload['banners'] as List? ?? [];

      final List<Map<String, String>> dynamicBanners = [];
      for (final b in bannersList) {
        final url = (b['imageUrl'] ?? b['image'] ?? '').toString().trim();
        final title = (b['title'] ?? b['name'] ?? 'App Banner').toString().trim();
        final type = (b['type'] ?? 'Banner').toString().toUpperCase();
        if (url.isNotEmpty && !dynamicBanners.any((item) => item['url'] == url)) {
          dynamicBanners.add({'name': '🎨 [$type] $title', 'url': url});
        }
      }

      final campaignsList = List<Map<String, dynamic>>.from(
        rawData['campaigns'] ?? [],
      );

          // 1. Target Rules
          final backendRules = rawData['targetRules'] ?? rawData['rules'];
          List<Map<String, String>> targetRulesToSet = List.from(_defaultTargetRules);
          if (backendRules is List && backendRules.isNotEmpty) {
            final List<Map<String, String>> parsedRules = [];
            for (final r in backendRules) {
              if (r is Map) {
                parsedRules.add({
                  'code': (r['code'] ?? r['key'] ?? '').toString(),
                  'label': (r['label'] ?? r['name'] ?? r['code'] ?? '').toString(),
                  'desc': (r['desc'] ?? r['description'] ?? '').toString(),
                  'category': (r['category'] ?? 'general').toString().toLowerCase(),
                  'suggestedRoute': (r['suggestedRoute'] ?? r['route'] ?? '/dashboard').toString(),
                  'suggestedBtn': (r['suggestedBtn'] ?? r['btnText'] ?? '⚡ Open Offer').toString(),
                });
              }
            }
            if (!parsedRules.any((r) => r['code'] == 'CUSTOM')) {
              parsedRules.add({
                'code': 'CUSTOM',
                'label': '⚙️ Custom Filter / Audience Rule (Write Below)...',
                'desc': 'Custom rule specified by administrator.',
                'category': 'general',
                'suggestedRoute': '/dashboard',
                'suggestedBtn': '⚡ Open Offer',
              });
            }
            targetRulesToSet = parsedRules;
          }

          // 2. Categories
          final backendCats = rawData['categories'];
          List<Map<String, String>> categoriesToSet = List.from(_defaultCategories);
          if (backendCats is List && backendCats.isNotEmpty) {
            final List<Map<String, String>> parsedCats = [];
            for (final c in backendCats) {
              if (c is Map) {
                parsedCats.add({
                  'value': (c['value'] ?? c['key'] ?? c['id'] ?? '').toString().toLowerCase(),
                  'label': (c['label'] ?? c['name'] ?? c['value'] ?? '').toString(),
                });
              }
            }
            if (parsedCats.isNotEmpty) categoriesToSet = parsedCats;
          }

          for (final c in campaignsList) {
            final cat = c['category']?.toString().toLowerCase().trim() ?? '';
            if (cat.isNotEmpty && !categoriesToSet.any((item) => item['value'] == cat)) {
              categoriesToSet.add({
                'value': cat,
                'label': '🏷️ ${cat.toUpperCase()}',
              });
            }
          }

          // Auto-select first or restore current selected campaign
          Map<String, dynamic>? selected = state.selectedCampaign;
          if (selected != null) {
            selected = campaignsList.firstWhere(
              (c) => c['segmentKey'] == selected!['segmentKey'],
              orElse: () => campaignsList.isNotEmpty ? campaignsList.first : {},
            );
          } else if (campaignsList.isNotEmpty) {
            selected = campaignsList.first;
          }

          emit(state.copyWith(
            status: PushCampaignsStatus.success,
            campaigns: campaignsList,
            selectedCampaign: () => selected,
            banners: dynamicBanners,
            targetRules: targetRulesToSet,
            categories: categoriesToSet,
            totalUsers: rawData['totalUsers'] ?? 0,
            usersWithToken: rawData['usersWithToken'] ?? 0,
            errorMessage: () => null,
          ));
    } catch (e) {
      emit(state.copyWith(
        status: PushCampaignsStatus.failure,
        errorMessage: () => 'Error connecting to server: $e',
      ));
    }
  }

  void _onSelectCampaign(
    SelectCampaignEvent event,
    Emitter<PushCampaignsState> emit,
  ) {
    emit(state.copyWith(selectedCampaign: () => event.campaign));
  }

  Future<void> _onToggleCampaignEnabled(
    ToggleCampaignEnabledEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    // Optimistic local update
    final updatedList = state.campaigns.map((c) {
      if (c['segmentKey'] == event.segmentKey) {
        return {...c, 'isEnabled': event.isEnabled};
      }
      return c;
    }).toList();

    Map<String, dynamic>? updatedSelected = state.selectedCampaign;
    if (updatedSelected?['segmentKey'] == event.segmentKey) {
      updatedSelected = {...updatedSelected!, 'isEnabled': event.isEnabled};
    }

    emit(state.copyWith(
      campaigns: updatedList,
      selectedCampaign: () => updatedSelected,
    ));

    try {
      await _campaignRepo.updateCampaignConfig(
        event.segmentKey,
        {'isEnabled': event.isEnabled},
      );
      emit(state.copyWith(
        successMessage: () =>
            'Segment ${event.segmentKey} ${event.isEnabled ? "Enabled" : "Disabled"}',
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: () => 'Failed to update toggle: $e',
      ));
    }
  }

  Future<void> _onUpdateCampaignSchedule(
    UpdateCampaignScheduleEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    final updatedList = state.campaigns.map((c) {
      if (c['segmentKey'] == event.segmentKey) {
        return {...c, 'scheduledTime': event.scheduledTime};
      }
      return c;
    }).toList();

    Map<String, dynamic>? updatedSelected = state.selectedCampaign;
    if (updatedSelected?['segmentKey'] == event.segmentKey) {
      updatedSelected = {...updatedSelected!, 'scheduledTime': event.scheduledTime};
    }

    emit(state.copyWith(
      campaigns: updatedList,
      selectedCampaign: () => updatedSelected,
    ));

    try {
      await _campaignRepo.updateCampaignConfig(
        event.segmentKey,
        {'scheduledTime': event.scheduledTime},
      );
      emit(state.copyWith(
        successMessage: () =>
            'Schedule updated to ${event.scheduledTime} IST for Segment ${event.segmentKey}',
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: () => 'Failed to update schedule: $e',
      ));
    }
  }

  Future<void> _onUpdateCampaignConfig(
    UpdateCampaignConfigEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _campaignRepo.updateCampaignConfig(
        event.segmentKey,
        event.updates,
      );
      add(const FetchPushCampaignsEvent(forceRefresh: true));
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: () => 'Segment ${event.segmentKey} updated successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: () => 'Update failed: $e',
      ));
    }
  }

  Future<void> _onCreateCampaignSegment(
    CreateCampaignSegmentEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _campaignRepo.createSegment(event.segmentData);
      add(const FetchPushCampaignsEvent(forceRefresh: true));
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: () =>
            'Segment ${event.segmentData['segmentKey']} created successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: () => 'Creation failed: $e',
      ));
    }
  }

  Future<void> _onDeleteCampaignSegment(
    DeleteCampaignSegmentEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _campaignRepo.deleteCampaignSegment(event.segmentKey);
      if (state.selectedCampaign?['segmentKey'] == event.segmentKey) {
        emit(state.copyWith(selectedCampaign: () => null));
      }
      add(const FetchPushCampaignsEvent(forceRefresh: true));
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: () => 'Segment ${event.segmentKey} deleted successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: () => 'Delete failed: $e',
      ));
    }
  }

  Future<void> _onAddCampaignTemplate(
    AddCampaignTemplateEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _campaignRepo.addCampaignTemplate(
        event.segmentKey,
        event.templateData,
      );
      add(const FetchPushCampaignsEvent(forceRefresh: true));
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: () => 'New notification copy added successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: () => 'Error adding copy: $e',
      ));
    }
  }

  Future<void> _onUpdateCampaignTemplate(
    UpdateCampaignTemplateEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _campaignRepo.updateCampaignTemplate(
        event.segmentKey,
        event.templateId,
        event.templateData,
      );
      add(const FetchPushCampaignsEvent(forceRefresh: true));
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: () => 'Notification copy updated successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: () => 'Error updating copy: $e',
      ));
    }
  }

  Future<void> _onDeleteCampaignTemplate(
    DeleteCampaignTemplateEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _campaignRepo.deleteCampaignTemplate(
        event.segmentKey,
        event.templateId,
      );
      add(const FetchPushCampaignsEvent(forceRefresh: true));
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: () => 'Notification copy deleted successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: () => 'Error deleting copy: $e',
      ));
    }
  }

  Future<void> _onReorderCampaignTemplates(
    ReorderCampaignTemplatesEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    final campaign = state.campaigns.firstWhere(
      (c) => c['segmentKey'] == event.segmentKey,
      orElse: () => {},
    );
    if (campaign.isEmpty) return;

    final templates = List<Map<String, dynamic>>.from(campaign['templates'] ?? []);
    if (event.oldIndex < 0 ||
        event.oldIndex >= templates.length ||
        event.newIndex < 0 ||
        event.newIndex >= templates.length) {
      return;
    }

    final item = templates.removeAt(event.oldIndex);
    templates.insert(event.newIndex, item);

    // Optimistic update
    final updatedList = state.campaigns.map((c) {
      if (c['segmentKey'] == event.segmentKey) {
        return {...c, 'templates': templates};
      }
      return c;
    }).toList();

    Map<String, dynamic>? updatedSelected = state.selectedCampaign;
    if (updatedSelected?['segmentKey'] == event.segmentKey) {
      updatedSelected = {...updatedSelected!, 'templates': templates};
    }

    emit(state.copyWith(
      campaigns: updatedList,
      selectedCampaign: () => updatedSelected,
    ));

    try {
      await _campaignRepo.updateCampaignConfig(
        event.segmentKey,
        {'templates': templates},
      );
    } catch (e) {
      emit(state.copyWith(
        errorMessage: () => 'Failed to save reordered copies: $e',
      ));
    }
  }

  Future<void> _onTogglePinTemplate(
    TogglePinTemplateEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    final newMode = event.isCurrentlyPinned ? 'rotating' : 'pinned';
    final newPinnedId = event.isCurrentlyPinned ? null : event.templateId;

    // Optimistic update
    final updatedList = state.campaigns.map((c) {
      if (c['segmentKey'] == event.segmentKey) {
        return {
          ...c,
          'mode': newMode,
          'pinnedTemplateId': newPinnedId,
        };
      }
      return c;
    }).toList();

    Map<String, dynamic>? updatedSelected = state.selectedCampaign;
    if (updatedSelected?['segmentKey'] == event.segmentKey) {
      updatedSelected = {
        ...updatedSelected!,
        'mode': newMode,
        'pinnedTemplateId': newPinnedId,
      };
    }

    emit(state.copyWith(
      campaigns: updatedList,
      selectedCampaign: () => updatedSelected,
    ));

    try {
      await _campaignRepo.updateCampaignConfig(
        event.segmentKey,
        {
          'mode': newMode,
          'pinnedTemplateId': newPinnedId,
        },
      );
      emit(state.copyWith(
        successMessage: () => event.isCurrentlyPinned
            ? 'Unpinned copy. Segment returned to daily rotation.'
            : 'Pinned copy! Segment locked to this template.',
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: () => 'Failed to toggle pin: $e',
      ));
    }
  }

  Future<void> _onTriggerBroadcast(
    TriggerBroadcastEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      final data = await _campaignRepo.triggerCampaignNow(
        event.segmentKey,
        customTemplate: event.customTemplate,
      );
      final count = data['count'] ?? 0;
      add(const FetchPushCampaignsEvent(forceRefresh: true));
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: () =>
            '🚀 Broadcast sent successfully to $count eligible users!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: () => 'Broadcast error: $e',
      ));
    }
  }

  Future<void> _onSendTestPush(
    SendTestPushEvent event,
    Emitter<PushCampaignsState> emit,
  ) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _campaignRepo.sendSegmentTestPush(
        event.segmentKey,
        event.phone,
        event.templateData,
      );
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: () => '📲 Test notification sent to ${event.phone}!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: () => 'Failed to send test push: $e',
      ));
    }
  }

  void _onClearMessage(
    ClearPushCampaignsMessageEvent event,
    Emitter<PushCampaignsState> emit,
  ) {
    emit(state.copyWith(
      errorMessage: () => null,
      successMessage: () => null,
    ));
  }

  void _onReset(
    ResetPushCampaignsEvent event,
    Emitter<PushCampaignsState> emit,
  ) {
    emit(const PushCampaignsState());
  }
}
