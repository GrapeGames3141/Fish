/* Build the preview's deterministic PNG keyframes, WebM and animated GIF.
 * Uses Chromium/WebGL for animation; this is an encoder, not a Python image edit.
 */
const fs = require('fs');
const path = require('path');
const http = require('http');
const runtimeModules = 'C:/Users/Tak/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const { chromium } = require(`${runtimeModules}/playwright`);
const sharp = require(`${runtimeModules}/sharp`);

const root = path.resolve(__dirname, '..');
const sourceDir = __dirname;
const frameDir = 'E:/CodexCache/haptic-fish-water-preview-v01/frames';
const gallery = path.join(root, 'gallery');
const validation = path.join(root, 'validation');
const W = 720, H = 1280, FPS = 20, SECONDS = 6, FRAMES = FPS * SECONDS;
const input = path.join(sourceDir, 'willow-line-out-720.png');
const html = path.join(sourceDir, 'water-motion-preview.html');
const gifOutput = path.join(gallery, 'willow-water-motion-v01.gif');
const webmOutput = path.join(gallery, 'willow-water-motion-v01.webm');

for (const dir of [frameDir, gallery, validation]) fs.mkdirSync(dir, { recursive: true });

function startLocalServer() {
  const rodAlpha = 'E:/AI Projects/games/haptic fish/art/ui_v1/runtime_source/rod-photoreal-alpha-v01.png';
  const server = http.createServer((req, res) => {
    const requestPath = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
    const target = requestPath === '/rod-alpha.png'
      ? rodAlpha
      : path.join(sourceDir, requestPath === '/' ? '/water-motion-preview.html' : requestPath);
    if ((!target.startsWith(sourceDir) && target !== rodAlpha) || !fs.existsSync(target)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': target.endsWith('.html') ? 'text/html; charset=utf-8' : 'image/png', 'Cache-Control': 'no-store' });
    fs.createReadStream(target).pipe(res);
  });
  return new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server)));
}

async function main() {
  console.log('water preview: preparing source');
  fs.copyFileSync(path.resolve(root, '..', 'header-v36', 'gallery', 'willow-line-out-720.png'), input);
  const server = await startLocalServer();
  const port = server.address().port;
  let browser;
  try {
  browser = await chromium.launch({
    executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    headless: true,
    args: ['--use-angle=swiftshader', '--use-gl=angle']
  });
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:${port}/water-motion-preview.html?capture=1`); await page.waitForFunction(() => window.previewReady === true);
  const maskDataUrl = await page.evaluate(() => window.getWaterMaskPng());
  fs.writeFileSync(path.join(gallery,'willow-water-motion-v01-mask.png'), Buffer.from(maskDataUrl.split(',')[1], 'base64'));
  console.log(`water preview: rendering ${FRAMES} frames`);
  for (let i=0; i<FRAMES; i++) {
    await page.evaluate((frame) => window.renderAt(frame / 20), i);
    await page.screenshot({ path: path.join(frameDir, `frame-${String(i).padStart(3,'0')}.png`), type: 'png' });
  }
  console.log('water preview: recording WebM');
  // Record a high-fidelity WebM companion directly from the same deterministic canvas.
  const webm = await page.evaluate(async ({ seconds, fps }) => {
    const stream = document.querySelector('#view').captureStream(fps);
    const chunks=[]; const rec=new MediaRecorder(stream, { mimeType:'video/webm;codecs=vp9', videoBitsPerSecond: 7_000_000 });
    rec.ondataavailable=e=>{if(e.data.size)chunks.push(e.data)}; const done=new Promise(r=>rec.onstop=r); rec.start();
    for(let i=0;i<seconds*fps;i++){ window.renderAt(i/fps); await new Promise(r=>setTimeout(r,1000/fps)); }
    rec.stop(); await done; const blob=new Blob(chunks,{type:'video/webm'}); const data=await blob.arrayBuffer(); return Array.from(new Uint8Array(data));
  }, { seconds: SECONDS, fps: FPS });
  fs.writeFileSync(webmOutput, Buffer.from(webm));
  } finally {
    if (browser) await browser.close();
    server.close();
  }
  console.log('water preview: encoding GIF');

  const {data: firstRaw}=await sharp(path.join(frameDir,'frame-000.png')).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const rgbFrames=[];
  for(let i=0;i<FRAMES;i++) {
    const {data}=await sharp(path.join(frameDir,`frame-${String(i).padStart(3,'0')}.png`)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    const rgb=Buffer.alloc(W*H*3);
    for(let p=0, q=0; p<data.length; p+=4, q+=3) { rgb[q]=data[p]; rgb[q+1]=data[p+1]; rgb[q+2]=data[p+2]; }
    rgbFrames.push(rgb);
  }
  await sharp(Buffer.concat(rgbFrames), { raw: { width: W, height: H * FRAMES, channels: 3, pageHeight: H }, limitInputPixels: false })
    .gif({ loop: 0, delay: Array(FRAMES).fill(50), colours: 256, effort: 5, dither: 0.5, interFrameMaxError: 0, keepDuplicateFrames: true })
    .toFile(gifOutput);
  const protectedChecks = [];
  const protectedRegions = [
    { name:'top_chrome_and_sky', x:0, y:0, w:W, h:500 },
    { name:'rod_tip', x:314, y:449, w:14, h:14 },
    { name:'fine_line_midpoint', x:412, y:545, w:10, h:10 },
    { name:'bobber', x:495, y:606, w:32, h:32 }
  ];
  for (const check of protectedRegions) {
    let maxDelta = 0;
    for (const frame of [20, 40, 80, 119]) {
      const {data}=await sharp(path.join(frameDir,`frame-${String(frame).padStart(3,'0')}.png`)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
      for (let y=check.y;y<check.y+check.h;y++) for (let x=check.x;x<check.x+check.w;x++) { const p=(y*W+x)*4; maxDelta=Math.max(maxDelta,Math.abs(data[p]-firstRaw[p]),Math.abs(data[p+1]-firstRaw[p+1]),Math.abs(data[p+2]-firstRaw[p+2])); }
    }
    protectedChecks.push({ ...check, maxChannelDelta: maxDelta });
  }
  const {data: loopLast}=await sharp(path.join(frameDir,'frame-119.png')).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let seamMean = 0; for (let i=0;i<firstRaw.length;i+=4) seamMean += Math.abs(loopLast[i]-firstRaw[i]) + Math.abs(loopLast[i+1]-firstRaw[i+1]) + Math.abs(loopLast[i+2]-firstRaw[i+2]);
  seamMean /= (W*H*3);
  const checks = {
    source: input, dimensions: [W,H], fps: FPS, seconds: SECONDS, frames: FRAMES,
    gif: { path: gifOutput, bytes: fs.statSync(gifOutput).size }, webm: { path: webmOutput, bytes: fs.statSync(webmOutput).size },
    mask: path.join(gallery,'willow-water-motion-v01-mask.png'),
    protectedFrameChecks: protectedChecks,
    seamMeanChannelDeltaFrame119To0: seamMean,
    protectedPixels: 'The shader multiplies hand-authored mask luminance by alpha. The shoreline, rod-alpha silhouette, fine line, bobber and foreground fade constrain motion before Sharp encodes the complete animated GIF.'
  };
  fs.writeFileSync(path.join(validation,'render-summary.json'), JSON.stringify(checks,null,2));
  fs.copyFileSync(path.join(frameDir,'frame-000.png'), path.join(gallery,'willow-water-motion-v01-frame-000.png'));
  fs.copyFileSync(path.join(frameDir,'frame-040.png'), path.join(gallery,'willow-water-motion-v01-frame-040.png'));
  fs.copyFileSync(path.join(frameDir,'frame-080.png'), path.join(gallery,'willow-water-motion-v01-frame-080.png'));
  console.log('water preview: complete');
}
main().catch(err => { console.error(err); process.exit(1); });
