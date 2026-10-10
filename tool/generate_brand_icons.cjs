// Render the shared SVG as platform icons. Requires Puppeteer and Chromium.
// Optional paths: BYTELAB_PUPPETEER_MODULE, BYTELAB_CHROME_PATH.
const fs = require('node:fs');
const path = require('node:path');
const puppeteer = require(process.env.BYTELAB_PUPPETEER_MODULE || 'puppeteer');
const root = path.resolve(__dirname, '..');
(async () => {
  const browser = await puppeteer.launch({
    executablePath: process.env.BYTELAB_CHROME_PATH || undefined,
    headless: true,
    args: process.env.BYTELAB_CHROME_NO_SANDBOX === '1' ? ['--no-sandbox'] : [],
  });
  try {
    const page = await browser.newPage();
    const source = fs.readFileSync(path.join(root, 'assets/branding/bytelab-icon.svg'), 'utf8');
    const cache = new Map();
    async function render(size) {
      if (!cache.has(size)) {
        await page.setViewport({ width: size, height: size, deviceScaleFactor: 1 });
        await page.setContent(`<style>html,body{margin:0;width:100%;height:100%}svg{display:block;width:100%;height:100%}</style>${source}`);
        // Opaque screenshots produce RGB PNGs, including App Store icons.
        cache.set(size, Buffer.from(await page.screenshot({ type: 'png', omitBackground: false })));
      }
      return cache.get(size);
    }
    async function write(file, size) {
      fs.writeFileSync(path.join(root, file), await render(size));
    }
    await write('assets/branding/bytelab-icon.png', 512);
    await write('web/favicon.png', 32);
    // A branded filename bypasses old cached Flutter favicons and installed icons.
    await write('web/bytelab-favicon.png', 32);
    fs.copyFileSync(path.join(root, 'assets/branding/bytelab-icon.svg'), path.join(root, 'web/bytelab-icon.svg'));
    for (const size of [192, 512]) {
      for (const stem of ['Icon', 'Icon-maskable', 'bytelab', 'bytelab-maskable']) {
        await write(`web/icons/${stem}-${size}.png`, size);
      }
    }
    await write('web/icons/bytelab-apple-touch.png', 180);
    for (const [folder, size] of [['mdpi',48], ['hdpi',72], ['xhdpi',96], ['xxhdpi',144], ['xxxhdpi',192]]) {
      await write(`android/app/src/main/res/mipmap-${folder}/ic_launcher.png`, size);
    }
    for (const platform of ['ios', 'macos']) {
      const directory = `${platform}/Runner/Assets.xcassets/AppIcon.appiconset`;
      const spec = JSON.parse(fs.readFileSync(path.join(root, directory, 'Contents.json'), 'utf8'));
      for (const image of spec.images) {
        if (image.filename) await write(`${directory}/${image.filename}`, Math.round(parseFloat(image.size) * parseFloat(image.scale)));
      }
    }
    // ICO supports PNG frames, preserving crisp icons at each Windows DPI.
    const sizes = [16,24,32,48,64,128,256];
    const header = Buffer.alloc(6 + sizes.length * 16);
    header.writeUInt16LE(1, 2);
    header.writeUInt16LE(sizes.length, 4);
    const frames = [];
    let offset = header.length;
    for (let i = 0; i < sizes.length; i++) {
      const png = await render(sizes[i]);
      const entry = 6 + i * 16;
      header[entry] = header[entry + 1] = sizes[i] === 256 ? 0 : sizes[i];
      header.writeUInt16LE(1, entry + 4);
      header.writeUInt16LE(32, entry + 6);
      header.writeUInt32LE(png.length, entry + 8);
      header.writeUInt32LE(offset, entry + 12);
      frames.push(png); offset += png.length;
    }
    fs.writeFileSync(path.join(root, 'windows/runner/resources/app_icon.ico'), Buffer.concat([header, ...frames]));
    console.log('Rendered ByteLab icons for the shared UI, web, Android, iOS, macOS, and Windows.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
