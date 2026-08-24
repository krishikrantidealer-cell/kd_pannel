import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/leads_bloc.dart';
import 'package:kd_pannel/util/dealers.dart';

bool isGenericProfileName(String name) {
  final low = name.toLowerCase().trim();
  return low.isEmpty ||
      low == 'new customer' ||
      low == 'guest' ||
      low == 'unknown' ||
      low == 'unknown user' ||
      low == 'dealer' ||
      low == 'lead' ||
      low == 'customer' ||
      low == 'admin' ||
      low == 'sales' ||
      low == 'staff' ||
      RegExp(r'^\d+$').hasMatch(low);
}

void navigateToProfile(
  BuildContext context,
  String user, {
  String? phone,
  String? name,
  Map<String, dynamic>? userDetails,
}) {
  if (user.isEmpty &&
      (phone == null || phone.isEmpty) &&
      (name == null || name.isEmpty)) {
    return;
  }

  final String cleanUser = user.trim();
  final String? cleanPhone = (phone != null && phone.trim().isNotEmpty)
      ? phone.trim()
      : (RegExp(r'^\+?\d{10,13}$').hasMatch(cleanUser) ? cleanUser : null);
  final String? cleanName =
      (name != null && name.trim().isNotEmpty && !isGenericProfileName(name))
          ? name.trim()
          : (!cleanUser.contains('@') &&
                  !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(cleanUser) &&
                  !RegExp(r'^\+?\d+$').hasMatch(cleanUser) &&
                  !isGenericProfileName(cleanUser)
              ? cleanUser
              : null);
  final String? cleanEmail = cleanUser.contains('@')
      ? cleanUser.toLowerCase()
      : userDetails?['email']?.toString().toLowerCase();
  final String? cleanId =
      (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(cleanUser) ||
              (cleanUser.length > 15 && !cleanUser.contains(' ')))
          ? cleanUser
          : (userDetails?['_id'] ?? userDetails?['id'])?.toString();

  final String phoneDigits = (cleanPhone ?? cleanUser).replaceAll(
    RegExp(r'\D'),
    '',
  );
  final String phoneLast10 = phoneDigits.length >= 10
      ? phoneDigits.substring(phoneDigits.length - 10)
      : '';

  bool isUserMatch(Map<String, dynamic> u) {
    final String uid = (u['_id'] ?? u['id'] ?? '').toString();
    if (cleanId != null && cleanId.isNotEmpty && uid == cleanId) return true;

    final String uPhone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();
    final String uCleanP = uPhone.replaceAll(RegExp(r'\D'), '');
    final String uP10 = uCleanP.length >= 10
        ? uCleanP.substring(uCleanP.length - 10)
        : '';

    if (phoneLast10.isNotEmpty && uP10.isNotEmpty && phoneLast10 == uP10) {
      return true;
    }

    final String uEmail = (u['email'] ?? '').toString().toLowerCase().trim();
    if (cleanEmail != null &&
        cleanEmail.isNotEmpty &&
        uEmail.isNotEmpty &&
        uEmail == cleanEmail) {
      return true;
    }

    if (cleanName != null && cleanName.isNotEmpty) {
      final String fullName = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
          .trim()
          .toLowerCase();
      final String shopName = (u['shopName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final String targetName = cleanName.toLowerCase();

      if (fullName.isNotEmpty && fullName == targetName) return true;
      if (shopName.isNotEmpty && shopName == targetName) return true;
    }

    return false;
  }

  // 1. Try to find in Dealers first (Real database records)
  try {
    final dealersState = context.read<DealersBloc>().state;
    final Map<String, dynamic>? dealerData = dealersState.allRawUsers
        .firstWhere(isUserMatch, orElse: () => <String, dynamic>{});

    if (dealerData != null && dealerData.isNotEmpty) {
      final kycStatus =
          dealerData['kycStatus']?.toString().toLowerCase() ?? 'pending';
      final isDealer = kycStatus == 'verified';

      if (isDealer) {
        final agentName = dealerData['assignedAgent'] != null
            ? '${dealerData['assignedAgent']['firstName'] ?? ''} ${dealerData['assignedAgent']['lastName'] ?? ''}'
                .trim()
            : '-';

        final String personName =
            (dealerData['firstName'] != null || dealerData['lastName'] != null)
                ? '${dealerData['firstName'] ?? ''} ${dealerData['lastName'] ?? ''}'
                    .trim()
                : '';

        final dealer = Dealer(
          name: personName.isNotEmpty
              ? personName
              : (dealerData['phoneNumber'] ?? user),
          phone: dealerData['phoneNumber'] ?? '',
          city: dealerData['address']?['cityTehsil'] ?? '',
          state: dealerData['address']?['state'] ?? '',
          agent: agentName,
          gstStatus: 'Verified',
          totalOrders: 0,
          purchaseValue: '₹0',
          isHighValue: false,
          isInactive: false,
          id: dealerData['_id'],
          agentId: dealerData['assignedAgent']?['_id'],
          kycStatus: dealerData['kycStatus'],
          shopName: dealerData['shopName'],
          address: dealerData['address'],
          status:
              dealerData['status'] ?? dealerData['leadStatus'] ?? 'prospect',
          notes: dealerData['notes'] ?? dealerData['leadNotes'] ?? '',
          notesHistory: dealerData['notesHistory'] != null
              ? List<Map<String, dynamic>>.from(dealerData['notesHistory'])
              : [],
        );

        Navigator.pushNamed(context, '/dealers/profile', arguments: dealer);
        return;
      } else {
        // Treat as Lead
        final String personName =
            (dealerData['firstName'] != null || dealerData['lastName'] != null)
                ? '${dealerData['firstName'] ?? ''} ${dealerData['lastName'] ?? ''}'
                    .trim()
                : '';

        final leadMap = {
          'id': dealerData['_id'],
          '_id': dealerData['_id'],
          'name': personName.isNotEmpty
              ? personName
              : (dealerData['phoneNumber'] ?? user),
          'phone': dealerData['phoneNumber'] ?? '',
          'shopName': dealerData['shopName'] ?? '',
          'villageArea': dealerData['address']?['villageArea'] ?? '',
          'city': dealerData['address']?['cityTehsil'] ?? '',
          'state': dealerData['address']?['state'] ?? '',
          'pincode': dealerData['address']?['pincode'] ?? '',
          'source': dealerData['source'] ?? 'App',
          'kycStatus': dealerData['kycStatus'] ?? 'pending',
          'status':
              dealerData['status'] ?? dealerData['leadStatus'] ?? 'prospect',
          'notes': dealerData['notes'] ?? dealerData['leadNotes'] ?? '',
          'notesHistory': dealerData['notesHistory'] ?? [],
        };

        Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
        return;
      }
    }
  } catch (_) {}

  // 2. Try to find in Leads
  try {
    final leadsState = context.read<LeadsBloc>().state;
    final Map<String, dynamic>? leadData = leadsState.allRawUsers.firstWhere(
      isUserMatch,
      orElse: () => <String, dynamic>{},
    );

    if (leadData != null && leadData.isNotEmpty) {
      final kycStatus =
          leadData['kycStatus']?.toString().toLowerCase() ?? 'pending';
      final isDealer = kycStatus == 'verified';

      if (isDealer) {
        final agentName = leadData['assignedAgent'] != null
            ? '${leadData['assignedAgent']['firstName'] ?? ''} ${leadData['assignedAgent']['lastName'] ?? ''}'
                .trim()
            : '-';

        final String personName =
            (leadData['firstName'] != null || leadData['lastName'] != null)
                ? '${leadData['firstName'] ?? ''} ${leadData['lastName'] ?? ''}'
                    .trim()
                : '';

        final dealer = Dealer(
          name: personName.isNotEmpty
              ? personName
              : (leadData['phoneNumber'] ?? user),
          phone: leadData['phoneNumber'] ?? '',
          city: (leadData['address'] as Map?)?['cityTehsil'] ?? '',
          state: (leadData['address'] as Map?)?['state'] ?? '',
          agent: agentName,
          gstStatus: 'Verified',
          totalOrders: 0,
          purchaseValue: '₹0',
          isHighValue: false,
          isInactive: false,
          id: leadData['_id'],
          agentId: leadData['assignedAgent']?['_id'],
          kycStatus: 'verified',
          shopName: leadData['shopName'],
          address: leadData['address'],
          status: leadData['status'] ?? leadData['leadStatus'] ?? 'prospect',
          notes: leadData['notes'] ?? leadData['leadNotes'] ?? '',
          notesHistory: leadData['notesHistory'] != null
              ? List<Map<String, dynamic>>.from(leadData['notesHistory'])
              : [],
        );

        Navigator.pushNamed(context, '/dealers/profile', arguments: dealer);
        return;
      } else {
        // Map raw user to lead map format expected by LeadProfilePage
        final String personName =
            (leadData['firstName'] != null || leadData['lastName'] != null)
                ? '${leadData['firstName'] ?? ''} ${leadData['lastName'] ?? ''}'
                    .trim()
                : '';

        final leadMap = {
          'id': leadData['_id'],
          '_id': leadData['_id'],
          'name': personName.isNotEmpty
              ? personName
              : (leadData['phoneNumber'] ?? user),
          'phone': leadData['phoneNumber'] ?? '',
          'shopName': leadData['shopName'] ?? '',
          'villageArea': leadData['address']?['villageArea'] ?? '',
          'city': leadData['address']?['cityTehsil'] ?? '',
          'state': leadData['address']?['state'] ?? '',
          'pincode': leadData['address']?['pincode'] ?? '',
          'source': leadData['source'] ?? 'App',
          'kycStatus': leadData['kycStatus'] ?? 'pending',
          'status': leadData['status'] ?? leadData['leadStatus'] ?? 'prospect',
          'notes': leadData['notes'] ?? leadData['leadNotes'] ?? '',
          'notesHistory': leadData['notesHistory'] ?? [],
        };

        Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
        return;
      }
    }
  } catch (_) {}

  // 3. Try to find in fallback static dealers list (allDealers)
  Dealer? matchedDealer;
  for (final d in allDealers) {
    final dPhoneDigits = d.phone.replaceAll(RegExp(r'\D'), '');
    final dP10 = dPhoneDigits.length >= 10
        ? dPhoneDigits.substring(dPhoneDigits.length - 10)
        : '';
    if ((phoneLast10.isNotEmpty && dP10.isNotEmpty && phoneLast10 == dP10) ||
        (cleanName != null &&
            cleanName.isNotEmpty &&
            d.name.toLowerCase() == cleanName.toLowerCase()) ||
        (cleanId != null && d.id != null && d.id == cleanId)) {
      matchedDealer = d;
      break;
    }
  }

  if (matchedDealer != null) {
    Navigator.pushNamed(context, '/dealers/profile', arguments: matchedDealer);
    return;
  }

  // 4. Default fallback: Navigate to leads profile with full leadMap
  final String personName = (cleanName != null && cleanName.isNotEmpty)
      ? cleanName
      : (userDetails?['firstName'] != null
          ? '${userDetails!['firstName'] ?? ''} ${userDetails['lastName'] ?? ''}'
              .trim()
          : (cleanPhone ??
              (cleanUser.isNotEmpty && !isGenericProfileName(cleanUser)
                  ? cleanUser
                  : 'Customer')));

  final leadMap = {
    'id': cleanId ?? cleanUser,
    '_id': cleanId,
    'name': personName.isNotEmpty ? personName : 'Customer',
    'phone': cleanPhone ?? (phoneDigits.length >= 10 ? phoneDigits : ''),
    'shopName': userDetails?['shopName'] ?? '',
    'villageArea': userDetails?['address']?['villageArea'] ?? '',
    'city': (userDetails?['address'] is Map)
        ? (userDetails!['address']['cityTehsil'] ??
            userDetails['address']['city'] ??
            'Unknown')
        : (userDetails?['city'] ?? 'Unknown'),
    'state': (userDetails?['address'] is Map)
        ? (userDetails!['address']['state'] ?? 'Unknown')
        : (userDetails?['state'] ?? 'Unknown'),
    'pincode': (userDetails?['address'] is Map)
        ? (userDetails!['address']['pincode'] ?? '')
        : (userDetails?['pincode'] ?? ''),
    'source': userDetails?['source'] ?? 'App',
    'kycStatus': userDetails?['kycStatus'] ?? 'pending',
    'status':
        userDetails?['status'] ?? userDetails?['leadStatus'] ?? 'prospect',
    'notes': userDetails?['notes'] ?? '',
    'notesHistory': userDetails?['notesHistory'] ?? [],
  };
  Navigator.pushNamed(context, '/leads/profile', arguments: leadMap);
}
