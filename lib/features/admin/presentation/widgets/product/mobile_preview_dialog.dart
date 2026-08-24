import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class PreviewHtmlBlock {
  final List<InlineSpan> spans;
  final TextAlign alignment;
  final String blockType;
  final Widget? widget;

  PreviewHtmlBlock({
    required this.spans,
    this.alignment = TextAlign.left,
    this.blockType = 'p',
    this.widget,
  });
}

class MobilePreviewDialog extends StatefulWidget {
  final String html;

  const MobilePreviewDialog({super.key, required this.html});

  static void show(BuildContext context, {required String html}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobilePreviewDialog(html: html),
    );
  }

  @override
  State<MobilePreviewDialog> createState() => _MobilePreviewDialogState();
}

class _MobilePreviewDialogState extends State<MobilePreviewDialog> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    // Simulated phone background and text colors
    final phoneBg = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final phoneAppBarBg = _isDarkMode
        ? const Color(0xFF1F1F1F)
        : const Color(0xFF00A651);
    const phoneAppBarText = Colors.white;

    return Container(
      height: screenHeight * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Slate background behind the phone
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header of the Bottom Sheet
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.phone_android_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'KrishiKranti Mobile Simulator',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Theme Toggle
                    IconButton(
                      icon: Icon(
                        _isDarkMode
                            ? Icons.wb_sunny_rounded
                            : Icons.nights_stay_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      tooltip: 'Toggle Light/Dark Preview',
                      onPressed: () {
                        setState(() {
                          _isDarkMode = !_isDarkMode;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content Area containing the simulated phone frame
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Container(
                  width: 375, // Standard iPhone/Android width
                  height: 680,
                  decoration: BoxDecoration(
                    color: phoneBg,
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: const Color(0xFF1E293B),
                      width: 12,
                    ), // Phone Bezel
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Simulated Phone Status Bar
                      Container(
                        height: 24,
                        color: phoneAppBarBg,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '9:41',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: phoneAppBarText,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.signal_cellular_4_bar,
                                  size: 11,
                                  color: phoneAppBarText,
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.wifi,
                                  size: 11,
                                  color: phoneAppBarText,
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.battery_std_rounded,
                                  size: 11,
                                  color: phoneAppBarText,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Simulated App Bar
                      Container(
                        height: 48,
                        color: phoneAppBarBg,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: phoneAppBarText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Product Details',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: phoneAppBarText,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.share_rounded,
                              size: 18,
                              color: phoneAppBarText,
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.shopping_cart_rounded,
                              size: 18,
                              color: phoneAppBarText,
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),

                      // Simulated Mobile Screen Body (Scrollable description details)
                      Expanded(
                        child: Container(
                          color: phoneBg,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Mock Product Media / Title Header just to frame the description nicely
                                Container(
                                  height: 180,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _isDarkMode
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 48,
                                      color: _isDarkMode
                                          ? Colors.white30
                                          : Colors.black26,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: 120,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _isDarkMode
                                        ? Colors.white12
                                        : Colors.black12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 220,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _isDarkMode
                                        ? Colors.white24
                                        : Colors.black26,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Tab selection simulated
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFF00A651),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Description',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF00A651),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Specifications',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _isDarkMode
                                            ? Colors.white54
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(
                                  height: 1,
                                  color: _isDarkMode
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                                const SizedBox(height: 16),

                                // Actual Rich HTML Description Rendered
                                Builder(
                                  builder: (context) {
                                    final parsedBlocks = previewParseHtml(
                                      widget.html,
                                    );
                                    if (parsedBlocks.isEmpty) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 32.0,
                                          ),
                                          child: Text(
                                            'No description provided.',
                                            style: TextStyle(
                                              color: _isDarkMode
                                                  ? Colors.white54
                                                  : Colors.black54,
                                              fontStyle: FontStyle.italic,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return previewBuildHtmlContent(
                                      context,
                                      parsedBlocks,
                                      isDarkMode: _isDarkMode,
                                    );
                                  },
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewFaqExpansionTile extends StatelessWidget {
  final String question;
  final String answerHtml;
  final Map<String, Widget> widgetMap;

  const PreviewFaqExpansionTile({
    super.key,
    required this.question,
    required this.answerHtml,
    required this.widgetMap,
  });

  @override
  Widget build(BuildContext context) {
    final cleanQuestion = question.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cleanQuestion,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final innerBlocks = previewParseHtml(
                answerHtml,
                widgetMap: widgetMap,
              );
              return previewBuildHtmlContent(context, innerBlocks);
            },
          ),
        ],
      ),
    );
  }
}

class PreviewFaqTableWidget extends StatelessWidget {
  final String tableHtml;

  const PreviewFaqTableWidget({super.key, required this.tableHtml});

  @override
  Widget build(BuildContext context) {
    final trRegex = RegExp(
      r'<tr[^>]*>(.*?)</tr>',
      dotAll: true,
      caseSensitive: false,
    );
    final cellRegex = RegExp(
      r'<(td|th)[^>]*>(.*?)</\1>',
      dotAll: true,
      caseSensitive: false,
    );

    final trMatches = trRegex.allMatches(tableHtml).toList();
    if (trMatches.isEmpty) return const SizedBox.shrink();

    final List<TableRow> rows = [];

    for (int rowIndex = 0; rowIndex < trMatches.length; rowIndex++) {
      final trHtml = trMatches[rowIndex].group(1)!;
      final cellMatches = cellRegex.allMatches(trHtml).toList();

      final List<Widget> rowCells = [];
      final bool isHeader =
          trMatches[rowIndex].group(0)!.toLowerCase().startsWith('<tr') &&
          trHtml.toLowerCase().contains('<th');

      for (int colIndex = 0; colIndex < cellMatches.length; colIndex++) {
        final cellMatch = cellMatches[colIndex];
        final cellInnerHtml = cellMatch.group(2)!;

        Widget cellContent;
        if (isHeader) {
          final cellBlocks = previewParseHtml(cellInnerHtml);
          cellContent = previewBuildHtmlContent(
            context,
            cellBlocks,
            defaultTextColor: Colors.black87,
          );
        } else {
          bool enforceBold = false;
          if (colIndex == 0) {
            enforceBold = true;
          }

          final cellBlocks = previewParseHtml(cellInnerHtml);
          Widget child = previewBuildHtmlContent(context, cellBlocks);

          if (enforceBold) {
            child = DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.bold),
              child: child,
            );
          }
          cellContent = child;
        }

        rowCells.add(
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            alignment: Alignment.centerLeft,
            child: cellContent,
          ),
        );
      }

      if (rowCells.isNotEmpty) {
        rows.add(TableRow(children: rowCells));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: const Color(0xFFDDDDDD), width: 1),
          children: rows,
        ),
      ),
    );
  }
}

Widget buildPreviewStyledBox(
  String innerHtml,
  String boxClass,
  Map<String, Widget> wMap,
) {
  Color? defaultTextColor;
  BoxDecoration decoration;

  if (boxClass == 'intro') {
    decoration = const BoxDecoration(
      color: Color(0xFFF9F9F9),
      border: Border(left: BorderSide(color: Color(0xFF00A651), width: 6)),
    );
  } else if (boxClass == 'warn') {
    defaultTextColor = const Color(0xFFCC0000);
    decoration = const BoxDecoration(
      color: Color(0xFFFFF5F5),
      border: Border(left: BorderSide(color: Color(0xFFCC0000), width: 6)),
    );
  } else if (boxClass == 'highlight') {
    decoration = const BoxDecoration(
      color: Color(0xFFF9F9F9),
      border: Border(left: BorderSide(color: Colors.black, width: 6)),
    );
  } else {
    // table-note
    decoration = const BoxDecoration(
      color: Color(0xFFF9F9F9),
      border: Border(
        top: BorderSide(color: Color(0xFF00A651), width: 3),
        left: BorderSide(color: Color(0xFFDDDDDD), width: 1),
        right: BorderSide(color: Color(0xFFDDDDDD), width: 1),
        bottom: BorderSide(color: Color(0xFFDDDDDD), width: 1),
      ),
    );
  }

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    decoration: decoration,
    child: Builder(
      builder: (context) {
        final innerBlocks = previewParseHtml(innerHtml, widgetMap: wMap);
        return previewBuildHtmlContent(
          context,
          innerBlocks,
          defaultTextColor: defaultTextColor,
        );
      },
    ),
  );
}

Widget buildPreviewTableWidget(String tableHtml) {
  return PreviewFaqTableWidget(tableHtml: tableHtml);
}

Widget buildPreviewFaqWidget(String detailsHtml, Map<String, Widget> wMap) {
  final summaryRegex = RegExp(
    r'<summary[^>]*>(.*?)</summary>',
    dotAll: true,
    caseSensitive: false,
  );
  final summaryMatch = summaryRegex.firstMatch(detailsHtml);
  String question = 'FAQ';
  if (summaryMatch != null) {
    question = summaryMatch.group(1)!;
  }

  String answerHtml = detailsHtml
      .replaceFirst(summaryRegex, '')
      .replaceFirst(RegExp(r'^<details[^>]*>', caseSensitive: false), '')
      .replaceFirst(RegExp(r'</details>$', caseSensitive: false), '')
      .trim();

  return PreviewFaqExpansionTile(
    question: question,
    answerHtml: answerHtml,
    widgetMap: wMap,
  );
}

Color? previewParseColor(String colorStr) {
  if (colorStr.startsWith('#')) {
    final hex = colorStr.substring(1);
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    } else if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 3) {
      final r = hex[0];
      final g = hex[1];
      final b = hex[2];
      return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
    }
  }
  if (colorStr.startsWith('rgb')) {
    final match = RegExp(
      r'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)',
    ).firstMatch(colorStr);
    if (match != null) {
      final r = int.parse(match.group(1)!);
      final g = int.parse(match.group(2)!);
      final b = int.parse(match.group(3)!);
      return Color.fromARGB(255, r, g, b);
    }
  }
  final lower = colorStr.toLowerCase();
  if (lower == 'red') return Colors.red;
  if (lower == 'blue') return Colors.blue;
  if (lower == 'green') return Colors.green;
  if (lower == 'yellow') return Colors.yellow;
  if (lower == 'orange') return Colors.orange;
  if (lower == 'black') return Colors.black;
  if (lower == 'white') return Colors.white;
  if (lower == 'grey' || lower == 'gray') return Colors.grey;
  return null;
}

String topLevelStripHtmlCssAndClasses(String html) {
  return html
      .replaceAll('\r', '')
      .replaceAll(
        RegExp(r'''\s*style\s*=\s*["'][^"']*["']''', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'''\s*class\s*=\s*["'][^"']*["']''', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'''\s*id\s*=\s*["'][^"']*["']''', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(
          r'<script[^>]*>.*?</script>',
          dotAll: true,
          caseSensitive: false,
        ),
        '',
      );
}

List<PreviewHtmlBlock> previewParseHtml(
  String html, {
  Map<String, Widget>? widgetMap,
}) {
  final List<PreviewHtmlBlock> blocks = [];
  final Map<String, Widget> wMap = widgetMap ?? {};

  String cleanHtml = topLevelStripHtmlCssAndClasses(html);

  int placeholderCount = wMap.length;

  // 1. Extract <details> (FAQ)
  final detailsRegex = RegExp(
    r'<details[^>]*>.*?</details>',
    dotAll: true,
    caseSensitive: false,
  );
  while (true) {
    final match = detailsRegex.firstMatch(cleanHtml);
    if (match == null) break;
    final detailsHtml = match.group(0)!;
    final placeholder = '<!--W_${placeholderCount++}-->';
    wMap[placeholder] = buildPreviewFaqWidget(detailsHtml, wMap);
    cleanHtml = cleanHtml.replaceRange(match.start, match.end, placeholder);
  }

  // 2. Extract <table>
  final tableRegex = RegExp(
    r'<table[^>]*>.*?</table>',
    dotAll: true,
    caseSensitive: false,
  );
  while (true) {
    final match = tableRegex.firstMatch(cleanHtml);
    if (match == null) break;
    final tableHtml = match.group(0)!;
    final placeholder = '<!--W_${placeholderCount++}-->';
    wMap[placeholder] = buildPreviewTableWidget(tableHtml);
    cleanHtml = cleanHtml.replaceRange(match.start, match.end, placeholder);
  }

  // 3. Extract styled boxes (divs with class intro, warn, highlight, table-note)
  final divRegex = RegExp(
    r'''<div\s+class=["'](intro|warn|highlight|table-note)["'][^>]*>(.*?)</div>''',
    dotAll: true,
    caseSensitive: false,
  );
  while (true) {
    final match = divRegex.firstMatch(cleanHtml);
    if (match == null) break;
    final boxClass = match.group(1)!.toLowerCase();
    final innerHtml = match.group(2)!;
    final placeholder = '<!--W_${placeholderCount++}-->';
    wMap[placeholder] = buildPreviewStyledBox(innerHtml, boxClass, wMap);
    cleanHtml = cleanHtml.replaceRange(match.start, match.end, placeholder);
  }

  final regex = RegExp(r'<!--W_\d+-->|<[^>]+>|[^<]+');
  final matches = regex.allMatches(cleanHtml);

  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;
  bool isStrike = false;
  List<Color> colorStack = [];
  List<Color> bgStack = [];
  List<String> fontStack = [];
  List<Map<String, bool>> spanPushedStack = [];
  String? currentLinkUrl;

  List<InlineSpan> currentSpans = [];
  TextAlign currentAlignment = TextAlign.left;
  String currentBlockType = 'p';

  bool inOrderedList = false;
  int orderedListIndex = 0;

  void commitBlock() {
    if (currentSpans.isNotEmpty) {
      blocks.add(
        PreviewHtmlBlock(
          spans: List.from(currentSpans),
          alignment: currentAlignment,
          blockType: currentBlockType,
        ),
      );
      currentSpans.clear();
    }
    currentAlignment = TextAlign.left;
    currentBlockType = 'p';
  }

  for (final match in matches) {
    final token = match.group(0)!;
    if (token.startsWith('<!--W_') && token.endsWith('-->')) {
      commitBlock();
      final widget = wMap[token];
      if (widget != null) {
        blocks.add(
          PreviewHtmlBlock(spans: [], blockType: 'widget', widget: widget),
        );
      }
      continue;
    }
    if (token.startsWith('<') && token.endsWith('>')) {
      final tag = token.toLowerCase();

      if (tag.startsWith('<span')) {
        final styleMatch = RegExp(
          r'''style=["']([^"']*)["']''',
        ).firstMatch(token);
        bool pushedColor = false;
        bool pushedBg = false;
        bool pushedFont = false;
        if (styleMatch != null) {
          final styleContent = styleMatch.group(1)!;
          final colorMatch = RegExp(
            r'(?<!-)color:\s*([^;]+)',
          ).firstMatch(styleContent);
          if (colorMatch != null) {
            final colorStr = colorMatch.group(1)!.trim();
            final parsedColor = previewParseColor(colorStr);
            if (parsedColor != null) {
              colorStack.add(parsedColor);
              pushedColor = true;
            }
          }
          final bgMatch = RegExp(
            r'background-color:\s*([^;]+)',
          ).firstMatch(styleContent);
          if (bgMatch != null) {
            final bgStr = bgMatch.group(1)!.trim();
            final parsedBg = previewParseColor(bgStr);
            if (parsedBg != null) {
              bgStack.add(parsedBg);
              pushedBg = true;
            }
          }
          final fontMatch = RegExp(
            r'font-family:\s*([^;]+)',
          ).firstMatch(styleContent);
          if (fontMatch != null) {
            final fontStr = fontMatch
                .group(1)!
                .trim()
                .replaceAll(RegExp(r'''['"]'''), '');
            if (fontStr.isNotEmpty) {
              fontStack.add(fontStr);
              pushedFont = true;
            }
          }
        }
        spanPushedStack.add({
          'color': pushedColor,
          'bg': pushedBg,
          'font': pushedFont,
        });
      } else if (tag == '</span>') {
        if (spanPushedStack.isNotEmpty) {
          final pushed = spanPushedStack.removeLast();
          if (pushed['color'] == true && colorStack.isNotEmpty) {
            colorStack.removeLast();
          }
          if (pushed['bg'] == true && bgStack.isNotEmpty) {
            bgStack.removeLast();
          }
          if (pushed['font'] == true && fontStack.isNotEmpty) {
            fontStack.removeLast();
          }
        } else {
          if (colorStack.isNotEmpty) colorStack.removeLast();
          if (bgStack.isNotEmpty) bgStack.removeLast();
          if (fontStack.isNotEmpty) fontStack.removeLast();
        }
      } else if (tag.startsWith('<a')) {
        final hrefMatch = RegExp(
          r'''href=["']([^"']*)["']''',
        ).firstMatch(token);
        if (hrefMatch != null) {
          currentLinkUrl = hrefMatch.group(1);
        }
      } else if (tag == '</a>') {
        currentLinkUrl = null;
      } else if (tag.startsWith('<p') || tag.startsWith('<div')) {
        commitBlock();
        if (tag.contains('ql-align-center') ||
            tag.contains('text-align: center') ||
            tag.contains('text-align:center')) {
          currentAlignment = TextAlign.center;
        } else if (tag.contains('ql-align-right') ||
            tag.contains('text-align: right') ||
            tag.contains('text-align:right')) {
          currentAlignment = TextAlign.right;
        } else if (tag.contains('ql-align-justify') ||
            tag.contains('text-align: justify') ||
            tag.contains('text-align:justify')) {
          currentAlignment = TextAlign.justify;
        }
      } else if (tag == '<strong>' || tag == '<b>') {
        isBold = true;
      } else if (tag == '</strong>' || tag == '</b>') {
        isBold = false;
      } else if (tag == '<em>' || tag == '<i>') {
        isItalic = true;
      } else if (tag == '</em>' || tag == '</i>') {
        isItalic = false;
      } else if (tag == '<u>') {
        isUnderline = true;
      } else if (tag == '</u>') {
        isUnderline = false;
      } else if (tag == '<s>' || tag == '<strike>' || tag == '<del>') {
        isStrike = true;
      } else if (tag == '</s>' || tag == '</strike>' || tag == '</del>') {
        isStrike = false;
      } else if (tag == '<ol>') {
        inOrderedList = true;
        orderedListIndex = 0;
      } else if (tag == '</ol>') {
        inOrderedList = false;
      } else if (tag == '<ul>') {
        inOrderedList = false;
      } else if (tag == '</ul>') {
        // No-op
      } else if (tag.startsWith('<li')) {
        commitBlock();
        if (inOrderedList) {
          orderedListIndex++;
          currentBlockType = 'ol-li-$orderedListIndex';
        } else {
          currentBlockType = 'ul-li';
        }
      } else if (tag == '</li>') {
        commitBlock();
      } else if (tag.startsWith('<h1')) {
        commitBlock();
        currentBlockType = 'h1';
      } else if (tag == '</h1>') {
        commitBlock();
      } else if (tag.startsWith('<h2')) {
        commitBlock();
        currentBlockType = 'h2';
      } else if (tag == '</h2>') {
        commitBlock();
      } else if (tag.startsWith('<h3')) {
        commitBlock();
        currentBlockType = 'h3';
      } else if (tag == '</h3>') {
        commitBlock();
      } else if (tag == '<br>' || tag == '<br/>' || tag == '<br />') {
        currentSpans.add(const TextSpan(text: '\n'));
      }
    } else {
      final text = token;
      if (text.isNotEmpty) {
        final Color? textColor = colorStack.isNotEmpty ? colorStack.last : null;
        final Color? bgColor = bgStack.isNotEmpty ? bgStack.last : null;
        final String? fontFam = fontStack.isNotEmpty ? fontStack.last : null;

        TextStyle textStyle = TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: TextDecoration.combine([
            if (isUnderline) TextDecoration.underline,
            if (isStrike) TextDecoration.lineThrough,
          ]),
          color: textColor,
          backgroundColor: bgColor,
        );

        if (fontFam != null) {
          try {
            textStyle = GoogleFonts.getFont(fontFam, textStyle: textStyle);
          } catch (_) {
            textStyle = textStyle.copyWith(fontFamily: fontFam);
          }
        }

        if (currentLinkUrl != null) {
          final targetUrl = currentLinkUrl;
          textStyle = textStyle.copyWith(
            color: Colors.blue.shade800,
            decoration: TextDecoration.underline,
          );
          currentSpans.add(
            TextSpan(
              text: text,
              style: textStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final uri = Uri.tryParse(targetUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
            ),
          );
        } else {
          currentSpans.add(TextSpan(text: text, style: textStyle));
        }
      }
    }
  }
  commitBlock();
  return blocks;
}

Widget previewBuildHtmlContent(
  BuildContext context,
  List<PreviewHtmlBlock> blocks, {
  Color? defaultTextColor,
  bool isDarkMode = false,
}) {
  final Color kBodyColor =
      defaultTextColor ??
      (isDarkMode ? Colors.white70 : const Color(0xFF111111));
  const double kBodyFontSize = 13.0;
  const double kLineHeight = 1.9;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: blocks.map((block) {
      if (block.widget != null) {
        final blockPadding = block.blockType == 'widget'
            ? EdgeInsets.zero
            : const EdgeInsets.only(bottom: 12);
        return Padding(padding: blockPadding, child: block.widget!);
      }

      final spans = block.spans.map((span) {
        if (span is TextSpan && span.text != null) {
          final existing = span.style;
          return TextSpan(
            text: span.text,
            style: (existing ?? const TextStyle()).copyWith(
              color: existing?.color ?? kBodyColor,
              height: existing?.height ?? kLineHeight,
              fontSize: existing?.fontSize ?? kBodyFontSize,
            ),
            recognizer: span.recognizer,
          );
        }
        return span;
      }).toList();

      Widget widget;

      // ── ORDERED LIST ITEM ──
      if (block.blockType.startsWith('ol-li-')) {
        final number = block.blockType.substring(6);
        widget = Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number. ',
                style: TextStyle(
                  fontSize: kBodyFontSize,
                  height: kLineHeight,
                  color: kBodyColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(children: spans),
                  textAlign: block.alignment,
                ),
              ),
            ],
          ),
        );

        // ── UNORDERED LIST ITEM ──
      } else if (block.blockType == 'ul-li' || block.blockType == 'li') {
        widget = Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ',
                style: TextStyle(
                  fontSize: kBodyFontSize,
                  height: kLineHeight,
                  color: kBodyColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(children: spans),
                  textAlign: block.alignment,
                ),
              ),
            ],
          ),
        );

        // ── H1 ──
      } else if (block.blockType == 'h1') {
        widget = RichText(
          text: TextSpan(
            children: spans.map((s) {
              if (s is TextSpan) {
                return TextSpan(
                  text: s.text,
                  recognizer: s.recognizer,
                  style: (s.style ?? const TextStyle()).copyWith(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w800,
                    color: s.style?.color ?? kBodyColor,
                    height: 1.35,
                  ),
                );
              }
              return s;
            }).toList(),
          ),
          textAlign: block.alignment,
        );

        // ── H2 ──
      } else if (block.blockType == 'h2') {
        widget = RichText(
          text: TextSpan(
            children: spans.map((s) {
              if (s is TextSpan) {
                return TextSpan(
                  text: s.text,
                  recognizer: s.recognizer,
                  style: (s.style ?? const TextStyle()).copyWith(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w700,
                    color: s.style?.color ?? kBodyColor,
                    height: 1.4,
                  ),
                );
              }
              return s;
            }).toList(),
          ),
          textAlign: block.alignment,
        );

        // ── H3 ──
      } else if (block.blockType == 'h3') {
        widget = SizedBox(
          width: double.infinity,
          child: RichText(
            text: TextSpan(
              children: spans.map((s) {
                if (s is TextSpan) {
                  return TextSpan(
                    text: s.text,
                    recognizer: s.recognizer,
                    style: (s.style ?? const TextStyle()).copyWith(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: s.style?.color ?? kBodyColor,
                      height: 1.5,
                    ),
                  );
                }
                return s;
              }).toList(),
            ),
            textAlign: block.alignment,
          ),
        );

        // ── PARAGRAPH / DEFAULT ──
      } else {
        widget = SizedBox(
          width: double.infinity,
          child: RichText(
            text: TextSpan(children: spans),
            textAlign: block.alignment,
          ),
        );
      }

      // Spacing between blocks
      EdgeInsets blockPadding;
      if (block.blockType == 'h1') {
        blockPadding = const EdgeInsets.only(bottom: 14, top: 4);
      } else if (block.blockType == 'h2') {
        blockPadding = const EdgeInsets.only(top: 24, bottom: 12);
      } else if (block.blockType == 'h3') {
        blockPadding = const EdgeInsets.only(top: 14, bottom: 8);
      } else if (block.blockType == 'ul-li' ||
          block.blockType == 'li' ||
          block.blockType.startsWith('ol-li-')) {
        blockPadding = const EdgeInsets.only(bottom: 6);
      } else {
        blockPadding = const EdgeInsets.only(bottom: 12);
      }

      return Padding(padding: blockPadding, child: widget);
    }).toList(),
  );
}
