const sharp = require('sharp');
const path = require('path');

const INPUT = 'd:/code/Chronoisle2/logo_source.png';
const OUTPUT_DIR = 'd:/code/Chronoisle2/entry/src/main/resources/base/media';

async function processIcon() {
  const meta = await sharp(INPUT).metadata();
  const W = meta.width, H = meta.height;
  const raw = await sharp(INPUT)
    .flatten({ background: { r: 255, g: 255, b: 255 } })
    .raw()
    .toBuffer();
  const CH = 3;

  const get = (x, y) => {
    if (x < 0 || x >= W || y < 0 || y >= H) return { r: 242, g: 246, b: 249 };
    const i = (y * W + x) * CH;
    return { r: raw[i], g: raw[i + 1], b: raw[i + 2] };
  };

  const isContent = (r, g, b) => {
    const avg = (r + g + b) / 3;
    const sat = Math.max(r, g, b) - Math.min(r, g, b);
    return avg < 220 || sat > 30;
  };

  let top = 0, bot = H - 1, lft = 0, rht = W - 1;
  for (let y = 0; y < H; y++) { let f = false; for (let x = 0; x < W; x++) { const p = get(x, y); if (isContent(p.r, p.g, p.b)) { f = true; break; } } if (f) { top = y; break; } }
  for (let y = H - 1; y >= 0; y--) { let f = false; for (let x = 0; x < W; x++) { const p = get(x, y); if (isContent(p.r, p.g, p.b)) { f = true; break; } } if (f) { bot = y; break; } }
  for (let x = 0; x < W; x++) { let f = false; for (let y = 0; y < H; y++) { const p = get(x, y); if (isContent(p.r, p.g, p.b)) { f = true; break; } } if (f) { lft = x; break; } }
  for (let x = W - 1; x >= 0; x--) { let f = false; for (let y = 0; y < H; y++) { const p = get(x, y); if (isContent(p.r, p.g, p.b)) { f = true; break; } } if (f) { rht = x; break; } }

  const maxDim = Math.max(rht - lft + 1, bot - top + 1);
  const cx = Math.round((lft + rht) / 2);
  const cy = Math.round((top + bot) / 2);
  
  // Crop by 6 pixels on all sides effectively destroying the straight-edge shadows
  const padInward = 6;
  const half = Math.ceil(maxDim / 2) - padInward; 
  const cropL = cx - half, cropT = cy - half, sz = half * 2;

  const C_SIZE = 160; 

  // We define the 4 corners
  const corners = [
    { xmin: 0, xmax: C_SIZE, ymin: 0, ymax: C_SIZE, cx: C_SIZE, cy: C_SIZE }, // TL
    { xmin: sz - C_SIZE, xmax: sz, ymin: 0, ymax: C_SIZE, cx: sz - C_SIZE, cy: C_SIZE }, // TR
    { xmin: 0, xmax: C_SIZE, ymin: sz - C_SIZE, ymax: sz, cx: C_SIZE, cy: sz - C_SIZE }, // BL
    { xmin: sz - C_SIZE, xmax: sz, ymin: sz - C_SIZE, ymax: sz, cx: sz - C_SIZE, cy: sz - C_SIZE } // BR
  ];

  const mask = new Uint8Array(sz * sz);
  
  const isBg = (r, g, b) => {
     const avg = (r + g + b) / 3;
     const sat = Math.max(r, g, b) - Math.min(r, g, b);
     return avg > 200 && sat < 25;
  };

  for (const c of corners) {
    for (let y = c.ymin; y < c.ymax; y++) {
      for (let x = c.xmin; x < c.xmax; x++) {
        // Measure Euclidean distance from the absolute corner point
        let cornerX = (c.xmin === 0) ? 0 : sz - 1;
        let cornerY = (c.ymin === 0) ? 0 : sz - 1;
        const dist = Math.sqrt((x - cornerX)**2 + (y - cornerY)**2);
        
        if (dist < 130) {
          const p = get(x + cropL, y + cropT);
          if (isBg(p.r, p.g, p.b)) {
             mask[y * sz + x] = 1;
          }
        }
      }
    }
  }

  // Dilate by 10 pixels within the corner bounds to swallow anti-aliased edge
  const maskExpanded = new Uint8Array(mask);
  for (let i = 0; i < 10; i++) {
    const prev = new Uint8Array(maskExpanded);
    for (const c of corners) {
      for (let y = c.ymin; y < c.ymax; y++) {
        for (let x = c.xmin; x < c.xmax; x++) {
          if (prev[y * sz + x]) {
             if (x > c.xmin) maskExpanded[y * sz + (x - 1)] = 1;
             if (x < c.xmax - 1) maskExpanded[y * sz + (x + 1)] = 1;
             if (y > c.ymin) maskExpanded[(y - 1) * sz + x] = 1;
             if (y < c.ymax - 1) maskExpanded[(y + 1) * sz + x] = 1;
          }
        }
      }
    }
  }

  const outBuf = Buffer.alloc(sz * sz * CH);

  for (let y = 0; y < sz; y++) {
    for (let x = 0; x < sz; x++) {
      const idx = (y * sz + x) * CH;
      
      let inAnyCorner = false;
      let targetC = null;
      for (const c of corners) {
        if (x >= c.xmin && x < c.xmax && y >= c.ymin && y < c.ymax) {
           inAnyCorner = true;
           targetC = c;
           break;
        }
      }

      if (inAnyCorner && maskExpanded[y * sz + x]) {
        // Radial projection ray casting!
        const dx = targetC.cx - x;
        const dy = targetC.cy - y;
        const len = Math.sqrt(dx * dx + dy * dy);
        
        if (len === 0) {
           const p = get(x + cropL, y + cropT);
           outBuf[idx] = p.r; outBuf[idx+1] = p.g; outBuf[idx+2] = p.b;
           continue;
        }

        const vx = dx / len;
        const vy = dy / len;
        
        let tx = x;
        let ty = y;
        let foundSafe = false;
        
        // march inward until we exit the mask
        for (let t = 1; t < 200; t++) {
           tx = Math.round(x + vx * t);
           ty = Math.round(y + vy * t);
           if (tx < targetC.xmin || tx >= targetC.xmax || ty < targetC.ymin || ty >= targetC.ymax) {
              // Went outside corner box, fallback
              break;
           }
           if (!maskExpanded[ty * sz + tx]) {
              // Found the edge! Step 3 more pixels inward for pure safety
              tx = Math.round(tx + vx * 3);
              ty = Math.round(ty + vy * 3);
              foundSafe = true;
              break;
           }
        }
        
        if (foundSafe) {
           const p = get(tx + cropL, ty + cropT);
           outBuf[idx] = p.r; outBuf[idx+1] = p.g; outBuf[idx+2] = p.b;
        } else {
           // fallback generic raw copy if geometry fails
           const p = get(x + cropL, y + cropT);
           outBuf[idx] = p.r; outBuf[idx+1] = p.g; outBuf[idx+2] = p.b;
        }
      } else {
        // Unedited region: pure copy
        const p = get(x + cropL, y + cropT);
        outBuf[idx] = p.r; outBuf[idx+1] = p.g; outBuf[idx+2] = p.b;
      }
    }
  }

  for (const { size, name } of [
    { size: 216, name: 'icon_appgallery_216.png' },
    { size: 512, name: 'icon_appgallery_512.png' },
    { size: 1024, name: 'icon_appgallery_1024.png' }
  ]) {
    await sharp(outBuf, { raw: { width: sz, height: sz, channels: CH } })
      .resize(size, size, { kernel: sharp.kernel.lanczos3, fit: 'cover' })
      .png()
      .toFile(path.join(OUTPUT_DIR, name));
    console.log(`Saved: ${name}`);
  }
}

processIcon().catch(console.error);
