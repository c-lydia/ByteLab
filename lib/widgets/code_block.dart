import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/byte_color.dart';

const codeStyle = TextStyle(
  fontFamily: 'Ubuntu Sans Mono',
  fontFamilyFallback: ['Noto Sans Mono', 'monospace'],
  fontSize: 13,
  height: 1.65,
  color: ByteColor.text,
);

String codeLanguage(String path) {
  final name = path.replaceAll('\\', '/').split('/').last.toLowerCase();
  if (name == 'cmakelists.txt' || name.endsWith('.cmake')) return 'cmake';
  if (name.startsWith('sdkconfig') || name.startsWith('kconfig')) {
    return 'config';
  }
  if (RegExp(r'\.(c|h|cpp|hpp|cc|cxx)$').hasMatch(name)) return 'cpp';
  if (name.endsWith('.json')) return 'json';
  if (RegExp(r'\.(sh|bash)$').hasMatch(name)) return 'bash';
  if (RegExp(r'\.(yml|yaml)$').hasMatch(name)) return 'yaml';
  return 'text';
}

/// A small lexical highlighter for the firmware languages ByteLab edits.
/// Matches whole strings and multiline comments before looking for keywords.
List<TextSpan> highlightCode(String source, String language) {
  if (language == 'text') return [TextSpan(text: source)];
  final c = language == 'cpp' || language == 'c';
  final pattern = RegExp(
    (c ? r'/\*[\s\S]*?(?:\*/|(?![\s\S]))|//[^\n]*|^\s*#\s*\w+' : r'#[^\n]*') +
        r'''|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:0x[0-9a-fA-F]+|\d+(?:\.\d+)?)\b|\$\{[^}]*\}|\$[A-Za-z_]\w*|\b[A-Za-z_]\w*\b''',
    multiLine: true,
  );
  const keywords = {
    'void',
    'int',
    'float',
    'double',
    'char',
    'bool',
    'const',
    'static',
    'return',
    'if',
    'else',
    'for',
    'while',
    'switch',
    'case',
    'break',
    'struct',
    'typedef',
    'enum',
    'unsigned',
    'signed',
    'long',
    'short',
    'sizeof',
    'include',
    'define',
    'true',
    'false',
    'null',
    'NULL',
    'volatile',
    'extern',
    'class',
    'public',
    'private',
    'namespace',
    'auto',
    'constexpr',
    'using',
    'new',
    'delete',
    'continue',
    'set',
    'project',
    'cmake_minimum_required',
    'idf_component_register',
    'REQUIRES',
    'SRCS',
    'INCLUDE_DIRS',
    'export',
    'source',
    'then',
    'fi',
    'do',
    'done',
  };
  final spans = <TextSpan>[];
  var end = 0;
  for (final match in pattern.allMatches(source)) {
    if (match.start > end) {
      spans.add(TextSpan(text: source.substring(end, match.start)));
    }
    final token = match.group(0)!;
    final trimmed = token.trimLeft();
    Color? color;
    if (trimmed.startsWith('//') ||
        trimmed.startsWith('/*') ||
        (!c && trimmed.startsWith('#'))) {
      color = ByteColor.secondsaryText;
    } else if (token.startsWith('"') || token.startsWith("'")) {
      color = ByteColor.success;
    } else if (RegExp(r'^\d').hasMatch(token)) {
      color = ByteColor.warning;
    } else if (keywords.contains(token) || (c && trimmed.startsWith('#'))) {
      color = ByteColor.purple;
    } else if (token.startsWith(r'$') || token.startsWith('CONFIG_')) {
      color = ByteColor.info;
    } else if (RegExp(r'\s*\(').matchAsPrefix(source, match.end) != null) {
      color = ByteColor.cyan;
    }
    spans.add(
      TextSpan(
        text: token,
        style: color == null ? null : TextStyle(color: color),
      ),
    );
    end = match.end;
  }
  if (end < source.length) spans.add(TextSpan(text: source.substring(end)));
  return spans;
}

class CodeEditingController extends TextEditingController {
  CodeEditingController({this.language = 'text'});
  String language;
  String? _highlightedText, _highlightedLanguage;
  List<TextSpan> _spans = [];
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.isComposingRangeValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    if (_highlightedText != text || _highlightedLanguage != language) {
      _highlightedText = text;
      _highlightedLanguage = language;
      _spans = highlightCode(text, language);
    }
    return TextSpan(style: style, children: _spans);
  }
}

class CodeBlock extends StatelessWidget {
  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    this.title,
  });
  final String code, language;
  final String? title;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ByteColor.terminal,
      border: Border.all(color: ByteColor.border),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: ByteColor.panel,
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title ?? language.toUpperCase(),
                  style: const TextStyle(
                    color: ByteColor.secondsaryText,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy code'),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text(
                  List.generate(
                    '\n'.allMatches(code).length + 1,
                    (i) => '${i + 1}',
                  ).join('\n'),
                  textAlign: TextAlign.right,
                  style: codeStyle.copyWith(color: ByteColor.mutedText),
                ),
              ),
              const SizedBox(width: 20),
              SelectableText.rich(
                TextSpan(
                  style: codeStyle,
                  children: highlightCode(code, language),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
