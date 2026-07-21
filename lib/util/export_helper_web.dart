// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// export_helper_web.dart
// Web implementation of CSV file saving and Estimate printing using dart:html.

import 'dart:convert';
import 'dart:html' as html;

void saveCsvFile(String csvContent, String fileName) {
  // Convert CSV content to UTF-8 bytes
  final bytes = utf8.encode(csvContent);

  // Create a Blob from the bytes
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');

  // Create an Object URL for the blob
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Create a temporary AnchorElement to trigger the download
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  // Append to the DOM, click, and clean up
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  // Revoke the Object URL to release memory
  html.Url.revokeObjectUrl(url);
}

void printQuotation(Map<String, dynamic> data) {
  final htmlContent = generateQuotationHtml(data);

  // Create a Blob from the HTML content
  final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');

  // Create an Object URL for the blob
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Open the URL in a new tab/window
  html.window.open(url, '_blank');
}

String formatCurrency(double value) {
  final stringValue = value.toStringAsFixed(2);
  final parts = stringValue.split('.');
  String integerPart = parts[0];
  final decimalPart = parts[1];

  if (integerPart.length <= 3) {
    return '₹ ' + integerPart + '.' + decimalPart;
  }

  final lastThree = integerPart.substring(integerPart.length - 3);
  final remaining = integerPart.substring(0, integerPart.length - 3);

  String formattedRemaining = '';
  int count = 0;
  for (int i = remaining.length - 1; i >= 0; i--) {
    formattedRemaining = remaining[i] + formattedRemaining;
    count++;
    if (count == 2 && i > 0) {
      formattedRemaining = ',' + formattedRemaining;
      count = 0;
    }
  }

  return '₹ ' + formattedRemaining + ',' + lastThree + '.' + decimalPart;
}

String numberToWords(double amount) {
  if (amount == 0) return 'Zero Rupees only';

  final units = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  final tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  String convertLessThanOneThousand(int number) {
    if (number <= 0) return '';
    String soFar = '';
    if (number % 100 < 20) {
      final idx = (number % 100).toInt();
      if (idx >= 0 && idx < units.length) {
        soFar = units[idx];
      }
      number = number ~/ 100;
    } else {
      final unitIdx = (number % 10).toInt();
      if (unitIdx >= 0 && unitIdx < units.length) {
        soFar = units[unitIdx];
      }
      number = number ~/ 10;
      final tenIdx = (number % 10).toInt();
      if (tenIdx >= 0 && tenIdx < tens.length) {
        soFar = tens[tenIdx] + (soFar.isNotEmpty ? ' $soFar' : '');
      }
      number = number ~/ 10;
    }
    if (number == 0) return soFar;
    final hundredIdx = number.toInt();
    if (hundredIdx >= 0 && hundredIdx < units.length) {
      return units[hundredIdx] + ' Hundred' + (soFar.isNotEmpty ? ' and $soFar' : '');
    }
    return soFar;
  }

  int numVal = amount.floor();
  String words = '';

  int crores = numVal ~/ 10000000;
  numVal = numVal % 10000000;

  int lakhs = numVal ~/ 100000;
  numVal = numVal % 100000;

  int thousands = numVal ~/ 1000;
  numVal = numVal % 1000;

  int hundreds = numVal;

  if (crores > 0) {
    words += convertLessThanOneThousand(crores) + ' Crore ';
  }
  if (lakhs > 0) {
    words += convertLessThanOneThousand(lakhs) + ' Lakh ';
  }
  if (thousands > 0) {
    words += convertLessThanOneThousand(thousands) + ' Thousand ';
  }
  if (hundreds > 0) {
    words += convertLessThanOneThousand(hundreds) + ' ';
  }

  words = words.trim();

  int paise = ((amount - amount.floor()) * 100).round();
  String paiseStr = '';
  if (paise > 0) {
    paiseStr = ' and ' + convertLessThanOneThousand(paise) + ' Paise';
  }

  return '$words Rupees$paiseStr only'.replaceAll(RegExp(r'\s+'), ' ');
}

String generateQuotationHtml(Map<String, dynamic> data) {
  final companyName = data['companyName'] ?? 'KRISHIKRANTI ORGANICS';
  final companyGst = data['companyGst'] ?? '23ABEFK9255G1Z9';
  final companyState = data['companyState'] ?? '23-Madhya Pradesh';
  final companyPhone = data['companyPhone'] ?? '9399022060';
  final companyEmail = data['companyEmail'] ?? 'krishikrantiorganics@gmail.com';
  final companyAddress =
      data['companyAddress'] ??
      'EWS - 101, The Bellaire Appartment, Gondermau Gandhi Nagar, Bhopal 462036, Madhya Pradesh';

  final estimateNo = data['estimateNo'] ?? 'EBS/25-26/EST/02689';
  final date = data['estimateDate'] ?? '18/07/2026';

  final clientName = data['clientName'] ?? '';
  final clientAddress = data['clientAddress'] ?? '';
  final clientPhone = data['clientPhone'] ?? '';
  final logoBase64 = data['logoBase64'] as String?;

  final List items = data['items'] ?? [];
  double baseSubtotal = 0.0;
  double gstTotal = 0.0;
  int totalQuantity = 0;

  final List<String> tableRows = [];
  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final double price = ((item['price'] ?? 0.0) as num).toDouble();
    final int qty = ((item['quantity'] ?? 0) as num).toInt();
    final double gst = ((item['gst'] ?? 18.0) as num).toDouble();
    final double subtotal = price * qty;
    final double gstAmt = subtotal * (gst / 100);
    final double amt = subtotal + gstAmt;
    
    baseSubtotal += subtotal;
    gstTotal += gstAmt;
    totalQuantity += qty;

    final isOdd = i % 2 == 1;
    final rowClass = isOdd ? 'class="alternate-row"' : '';

    tableRows.add('''
      <tr $rowClass>
        <td class="center">${i + 1}</td>
        <td class="bold">${item['name'] ?? ''}</td>
        <td class="center">${qty}</td>
        <td class="center">${item['unit'] ?? 'liter'}</td>
        <td class="num">${formatCurrency(price)}</td>
        <td class="center">${gst.toStringAsFixed(0)}%</td>
        <td class="num">${formatCurrency(amt)}</td>
      </tr>
    ''');
  }

  final grandTotal = baseSubtotal + gstTotal;
  final grandTotalWords = numberToWords(grandTotal);

  final formattedEmail = companyEmail.replaceFirst('@', '@<br>');
  String formattedAddress = companyAddress;
  if (formattedAddress.contains('Arvind Vihar')) {
    formattedAddress = formattedAddress
        .replaceFirst('Arvind Vihar, ', 'Arvind Vihar,<br>')
        .replaceFirst('Colony , ', 'Colony ,<br>');
  } else if (formattedAddress.contains('Bellaire')) {
    formattedAddress = formattedAddress
        .replaceFirst('Bellaire Appartment, ', 'Bellaire Appartment,<br>')
        .replaceFirst('Gandhi Nagar, ', 'Gandhi Nagar,<br>');
  }

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Estimate - $estimateNo</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;700;800&display=swap');
    
    body {
      font-family: 'Outfit', sans-serif;
      margin: 0;
      padding: 40px;
      color: #111827;
      background-color: #fff;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    
    .container {
      max-width: 900px;
      margin: 0 auto;
      border: 1px solid #e5e7eb;
      border-radius: 12px;
      padding: 30px;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
    }
    
    /* Header Contact Bar */
    .header-banner {
      background-color: #C21820;
      color: #ffffff;
      display: flex;
      align-items: stretch;
      height: 75px;
      position: absolute;
      top: 30px;
      right: 30px;
      width: 80%;
      border-radius: 0 4px 0 100px;
      z-index: 2;
      padding-left: 50px;
      box-sizing: border-box;
    }
    
    .logo-box {
      position: absolute;
      top: 15px;
      left: 30px;
      background-color: transparent;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 0;
      width: 110px;
      height: 70px;
      z-index: 10;
    }
    
    .logo-spacer {
      width: 170px;
      flex-shrink: 0;
    }
    
    .logo-img {
      max-height: 55px;
      max-width: 100%;
      object-fit: contain;
    }
    
    .logo-text {
      color: #C21820;
      font-weight: 800;
      font-size: 20px;
      letter-spacing: 0.5px;
    }
    
    .contact-col {
      display: flex;
      align-items: center;
      padding: 12px 18px;
      flex-grow: 1;
    }
    
    .contact-col.border-left {
      border-left: 1px solid rgba(255, 255, 255, 0.4);
    }
    
    .contact-item {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    
    .contact-icon {
      width: 16px;
      height: 16px;
      fill: #ffffff;
      flex-shrink: 0;
    }
    
    .contact-text {
      font-size: 11px;
      font-weight: 500;
      line-height: 1.3;
    }
    
    /* Company Details & Title */
    .meta-section {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 30px;
    }
    
    .company-info-wave {
      background-color: #1A2536; /* Dark navy */
      color: #ffffff;
      padding: 85px 50px 8px 30px;
      border-radius: 0 0 100px 0; /* Creates the curvy wave shape at bottom-right */
      margin-left: -30px; /* Pulls it to the left edge of the container */
      width: 55%;
      height: 100%;
      box-sizing: border-box;
      box-shadow: 0 2px 4px rgba(0,0,0,0.05);
      position: relative;
    }
    
    .company-info-wave h1 {
      margin: 0 0 4px 0;
      font-size: 20px;
      font-weight: 700;
      color: #ffffff;
    }
    
    .company-info-wave p {
      margin: 2px 0;
      font-size: 11px;
      color: #E2E8F0;
      opacity: 0.9;
    }
    
    .estimate-title-block {
      text-align: left;
    }
    
    .estimate-title-block h2 {
      margin: 0 0 10px 0;
      font-size: 28px;
      font-weight: 700;
      color: #111827;
      letter-spacing: -0.5px;
    }
    
    .meta-details-table {
      border-collapse: collapse;
      margin-left: 0;
    }
    
    .meta-details-table td {
      padding: 4px 12px;
      font-size: 13px;
    }
    
    .meta-details-table td.label {
      font-weight: 700;
      color: #374151;
      padding-left: 0;
      text-align: left;
    }
    
    .meta-details-table td.value {
      font-weight: 700;
      color: #111827;
      text-align: left;
    }
    
    /* Client Section */
    .client-section {
      margin-bottom: 30px;
      display: flex;
      justify-content: space-between;
    }
    
    .client-info-block {
      max-width: 60%;
    }
    
    .section-label {
      color: #C21820;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 8px;
    }
    
    .client-name {
      font-size: 18px;
      font-weight: 800;
      color: #000000;
      margin: 0 0 6px 0;
      text-transform: lowercase;
    }
    
    .client-address {
      font-size: 13px;
      color: #4B5563;
      line-height: 1.5;
      margin: 0 0 8px 0;
    }
    
    .client-contact {
      font-size: 13px;
      color: #374151;
      font-weight: 700;
    }
    
    /* Items Table */
    .items-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
    }
    
    .items-table th {
      background-color: #C21820;
      color: #ffffff;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      padding: 10px 14px;
      border: 1px solid #C21820;
    }
    
    .items-table th.center, .items-table td.center {
      text-align: center;
    }
    
    .items-table th.num, .items-table td.num {
      text-align: right;
    }
    
    .items-table td {
      padding: 12px 14px;
      border: 1px solid #E5E7EB;
      font-size: 13px;
      color: #374151;
    }
    
    .items-table tr.alternate-row {
      background-color: #FFF5F5;
    }
    
    .items-table td.bold {
      font-weight: 700;
      color: #111827;
    }
    
    .items-table tr.total-row td {
      background-color: #C21820;
      color: #ffffff;
      font-weight: 700;
      border: 1px solid #C21820;
    }
    
    /* Summary Section */
    .summary-section {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-top: 15px;
    }
    
    .amount-words {
      max-width: 50%;
    }
    
    .amount-words-title {
      color: #C21820;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      margin-bottom: 4px;
    }
    
    .amount-words-text {
      font-size: 13px;
      color: #4B5563;
      line-height: 1.4;
    }
    
    .totals-box {
      width: 300px;
    }
    
    .totals-table {
      width: 100%;
      border-collapse: collapse;
    }
    
    .totals-table td {
      padding: 8px 14px;
      font-size: 13px;
      color: #374151;
      border: 1px solid #E5E7EB;
    }
    
    .totals-table td.label {
      font-weight: 700;
    }
    
    .totals-table td.val {
      text-align: right;
      font-weight: 700;
    }
    
    .totals-table tr.grand-total td {
      background-color: #C21820;
      color: #ffffff;
      font-weight: 700;
      border: 1px solid #C21820;
    }
    
    /* Footer / Authorized Signatory */
    .footer-section {
      margin-top: 50px;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
    }
    
    .sign-box {
      text-align: center;
      width: 220px;
    }
    
    .sign-box p {
      margin: 0;
      font-size: 12px;
      color: #374151;
    }
    
    .stamp-area {
      height: 70px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 10px;
      position: relative;
    }
    
    .seal-stamp {
      width: 75px;
      height: 75px;
      border: 2px dashed rgba(60, 50, 160, 0.4);
      border-radius: 50%;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      color: rgba(60, 50, 160, 0.5);
      font-size: 8px;
      font-weight: 700;
      text-transform: uppercase;
      transform: rotate(-10deg);
    }
    
    .seal-stamp span {
      font-size: 12px;
      font-weight: 800;
    }
    
    .signatory-label {
      padding-top: 6px;
      font-size: 12px;
      font-weight: 700;
      color: #111827;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .bottom-accent {
      margin-top: 60px;
      height: 16px;
      background-color: #C21820;
      position: relative;
      border-radius: 0 0 8px 8px;
    }
    
    .bottom-accent::after {
      content: '';
      position: absolute;
      bottom: 0;
      right: 0;
      width: 250px;
      height: 48px;
      background-color: #1A2536; /* Dark navy */
      border-radius: 48px 0 8px 0;
    }
    
    /* Control Toolbar (Only visible on screen, not print) */
    .print-toolbar {
      max-width: 900px;
      margin: 0 auto 20px auto;
      background-color: #F3F4F6;
      padding: 12px 24px;
      border-radius: 8px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border: 1px solid #E5E7EB;
    }
    
    .toolbar-title {
      font-size: 14px;
      font-weight: 700;
      color: #374151;
    }
    
    .print-btn {
      background-color: #C21820;
      color: #ffffff;
      border: none;
      padding: 8px 16px;
      font-size: 13px;
      font-weight: 700;
      border-radius: 6px;
      cursor: pointer;
      font-family: inherit;
      box-shadow: 0 1px 2px rgba(0,0,0,0.05);
    }
    
    .print-btn:hover {
      background-color: #9b1318;
    }
    
    @media print {
      body {
        padding: 0;
      }
      .container {
        border: none;
        box-shadow: none;
        padding: 0;
      }
      .print-toolbar {
        display: none;
      }
      .header-banner {
        top: 0;
        right: 0;
      }
      .company-info-wave {
        margin-left: 0;
      }
      .logo-box {
        left: 30px;
      }
      .bottom-accent::after {
        border-radius: 48px 0 0 0;
      }
    }
  </style>
</head>
<body>

  <!-- Print Control Toolbar -->
  <div class="print-toolbar">
    <span class="toolbar-title">Document Ready - Click Print to Save as PDF</span>
    <button class="print-btn" onclick="window.print()">Print / Save PDF</button>
  </div>

  <div class="container">
    <!-- Top Contact Banner -->
    <div class="header-banner">
      <div class="contact-col">
        <div class="contact-item">
          <svg viewBox="0 0 24 24" class="contact-icon"><path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/></svg>
          <span class="contact-text">$companyPhone</span>
        </div>
      </div>
      <div class="contact-col border-left">
        <div class="contact-item">
          <svg viewBox="0 0 24 24" class="contact-icon"><path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"/></svg>
          <span class="contact-text">$formattedEmail</span>
        </div>
      </div>
      <div class="contact-col border-left">
        <div class="contact-item">
          <svg viewBox="0 0 24 24" class="contact-icon"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>
          <span class="contact-text">$formattedAddress</span>
        </div>
      </div>
    </div>
    
    <!-- Meta Details & Logo -->
    <div class="meta-section" style="position: relative; height: 150px;">
      <div class="company-info-wave">
        <div class="logo-box">
          ${logoBase64 != null ? '<img src="data:image/png;base64,$logoBase64" class="logo-img" alt="Logo" />' : '<span class="logo-text">EBS</span>'}
        </div>
        <h1>$companyName</h1>
        <p>GSTIN: $companyGst</p>
        <p>State: $companyState</p>
      </div>
    </div>
    
    <!-- Client Info -->
    <div class="client-section">
      <div class="client-info-block">
        <div class="section-label">Estimate For:</div>
        <div class="client-name">$clientName</div>
        <div class="client-address">$clientAddress</div>
        <div class="client-contact">Contact No.: $clientPhone</div>
      </div>
      
      <div class="estimate-title-block">
        <h2>Estimate</h2>
        <table class="meta-details-table">
          <tr>
            <td class="label">Estimate No.:</td>
            <td class="value bold" style="color: #111827;">$estimateNo</td>
          </tr>
          <tr>
            <td class="label">Date:</td>
            <td class="value">$date</td>
          </tr>
        </table>
      </div>
    </div>
    
    <!-- Items Table -->
    <table class="items-table">
      <thead>
        <tr>
          <th class="center" style="width: 5%">#</th>
          <th style="width: 40%">Item name</th>
          <th class="center" style="width: 10%">Quantity</th>
          <th class="center" style="width: 10%">Unit</th>
          <th class="num" style="width: 11%">Price/Unit</th>
          <th class="center" style="width: 11%">GST</th>
          <th class="num" style="width: 13%">Amount</th>
        </tr>
      </thead>
      <tbody>
        ${tableRows.join('\n')}
        <tr class="total-row">
          <td class="center"></td>
          <td>TOTAL</td>
          <td class="center">$totalQuantity</td>
          <td class="center"></td>
          <td class="num"></td>
          <td class="center"></td>
          <td class="num">${formatCurrency(grandTotal)}</td>
        </tr>
      </tbody>
    </table>
    
    <!-- Summary Section -->
    <div class="summary-section">
      <div class="amount-words">
        <div class="amount-words-title">Estimate Amount In Words</div>
        <div class="amount-words-text">$grandTotalWords</div>
      </div>
      
      <div class="totals-box">
        <table class="totals-table">
          <tr>
            <td class="label">Sub Total (Excl. GST)</td>
            <td class="val">${formatCurrency(baseSubtotal)}</td>
          </tr>
          <tr>
            <td class="label">GST Total</td>
            <td class="val">${formatCurrency(gstTotal)}</td>
          </tr>
          <tr class="grand-total">
            <td class="label">Grand Total</td>
            <td class="val">${formatCurrency(grandTotal)}</td>
          </tr>
        </table>
      </div>
    </div>
    
    <!-- Footer / Signatory -->
    <div class="footer-section">
      <div class="sign-box" style="text-align: left; width: auto;">
        <!-- Extra info if needed -->
      </div>
      
      <div class="sign-box">
        <p>For : $companyName</p>
        <div class="stamp-area">
          <div class="seal-stamp">
            <span>SEAL</span>
            EBS
          </div>
        </div>
        <div class="signatory-label">Authorized Signatory</div>
      </div>
    </div>
    
    <!-- Bottom Accent Bar -->
    <div class="bottom-accent"></div>
  </div>
  
  <!-- Auto invoke print dialog on load -->
  <script>
    window.onload = function() {
      setTimeout(function() {
        window.print();
      }, 500);
    };
  </script>
</body>
</html>
  ''';
}
