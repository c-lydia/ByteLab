import 'package:flutter/material.dart';
import '../core/byte_color.dart';
import 'app_controls.dart';
import 'code_block.dart';

class NeovimGuide extends StatelessWidget {
  const NeovimGuide({super.key});
  @override
  Widget build(BuildContext context) => const AppPanel(
    title: 'Neovim, plugins & transparency',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Install Neovim 0.9+ and make nvim available on PATH. In Settings, choose Neovim under Preferred editor and Save settings. Open a project, then select a file or click Start Neovim. This is your actual Neovim running inside ByteLab.',
        ),
        SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Setup, motions, plugins, and troubleshooting'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Configuration and plugins',
                style: TextStyle(
                  color: ByteColor.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Normal mode loads your existing init.lua/init.vim, plugins, mappings, colorscheme, and inherited environment (including NVIM_APPNAME and XDG_CONFIG_HOME). ByteLab does not install plugins or rewrite your dotfiles. Use :echo stdpath("config") to see the config directory. The Plugins button opens Lazy or Packer when installed; other managers are available through their usual commands.',
            ),
            SizedBox(height: 14),
            CodeBlock(
              language: 'text',
              title: 'Neovim quick reference · default mappings',
              code:
                  'Esc          Return to Normal mode\ni / a        Insert before / after the cursor\nh j k l      Move left / down / up / right\nw / b / e    Next word / previous word / word end\n0 / ^ / \$    Line start / first nonblank / line end\ngg / G       First / last line\n5j / 3w      Repeat a motion with a count\nv / V        Visual selection / whole lines\ndd / yy / p  Delete line / yank line / paste\nciw / dw     Change inner word / delete a word\nu / Ctrl+R   Undo / redo\n/text        Search; n / N go forward / backward\n:w / :wa     Save current buffer / all buffers\n:q / :qa     Quit window / all windows\n:qa!         Discard all unsaved buffers and quit\n:Tutor       Interactive tutorial\n:help        Built-in Neovim documentation',
            ),
            SizedBox(height: 14),
            Text(
              'Mappings from your config may override these defaults. Keyboard input goes directly to Neovim; Ctrl+S is not ByteLab’s save shortcut here. Use :w, :wa, or Save all. For line numbers, use :set number relativenumber (or set those options in your config).',
            ),
            SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Saving, builds, and recovery',
                style: TextStyle(
                  color: ByteColor.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Neovim saves directly to disk using your Neovim backup/undo settings; ByteLab’s .bytelab-backups applies only to its built-in editor. Save every modified buffer before building, flashing, switching projects, or changing editor mode. ByteLab checks all Neovim buffers and pauses terminal input while a firmware operation runs. Configuration → Edit in Neovim opens that file in Project; use Reload in the configuration editor after saving externally. Stop Neovim asks before discarding unsaved or unknown buffer state. After a crash, follow Neovim’s swap-file recovery prompt.',
            ),
            SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Troubleshooting',
                style: TextStyle(
                  color: ByteColor.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '“Not found”: verify nvim --version in the environment launching ByteLab. Plugin errors or a startup prompt: respond in the terminal; use Stop Neovim, enable Clean Neovim configuration in Settings, save, and restart. Clean mode skips your config and third-party plugins. If no plugin manager is found, configure one in Neovim first. Existing plugin system tools and language servers must also be on PATH. To return to the original editor, save/stop Neovim, choose Built-in under Preferred editor, and save settings.',
            ),
            SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Underlight transparency',
                style: TextStyle(
                  color: ByteColor.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Settings → Underlight transparency controls native Linux window opacity from 70% to 100%. Save settings to apply and retain it; 100% restores an opaque window. Opacity affects text as well as backgrounds. Hyprland/compositor rules control desktop blur and may combine with this opacity. Unsupported platforms keep their normal window appearance.',
            ),
            SizedBox(height: 12),
          ],
        ),
      ],
    ),
  );
}
