const fs = require('fs');
const path = require('path');

// SVG 主图标内容
const mainIconSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FF6B6B;stop-opacity:1" />
      <stop offset="50%" style="stop-color:#FF8E8E;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#FFB4B4;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="glassHighlight" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#FFFFFF;stop-opacity:0.6" />
      <stop offset="50%" style="stop-color:#FFFFFF;stop-opacity:0.1" />
      <stop offset="100%" style="stop-color:#FFFFFF;stop-opacity:0" />
    </linearGradient>
    <linearGradient id="playGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FFFFFF;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#F0F0F0;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect x="32" y="32" width="448" height="448" rx="96" ry="96" fill="url(#bgGradient)"/>
  <rect x="32" y="32" width="448" height="224" rx="96" ry="96" fill="url(#glassHighlight)"/>
  <g opacity="0.3">
    <rect x="80" y="120" width="120" height="8" rx="4" fill="#FFFFFF"/>
    <rect x="220" y="120" width="80" height="8" rx="4" fill="#FFFFFF"/>
    <rect x="100" y="150" width="160" height="8" rx="4" fill="#FFFFFF"/>
    <rect x="280" y="150" width="100" height="8" rx="4" fill="#FFFFFF"/>
  </g>
  <circle cx="256" cy="280" r="100" fill="url(#playGradient)"/>
  <path d="M228 230 L228 330 L308 280 Z" fill="#FF6B6B"/>
  <path d="M120 400 Q256 440 392 400" stroke="#FFFFFF" stroke-width="6" fill="none" opacity="0.4" stroke-linecap="round"/>
</svg>`;

const sizes = [72, 96, 128, 144, 152, 192, 384, 512];
const iconsDir = path.join(__dirname, '../public/icons');

// 确保目录存在
if (!fs.existsSync(iconsDir)) {
  fs.mkdirSync(iconsDir, { recursive: true });
}

// 为每个尺寸创建 SVG（PNG 需要额外工具转换）
sizes.forEach(size => {
  const scaledSvg = mainIconSvg.replace('viewBox="0 0 512 512"', `viewBox="0 0 512 512" width="${size}" height="${size}"`);
  fs.writeFileSync(path.join(iconsDir, `icon-${size}x${size}.svg`), scaledSvg);
  console.log(`Created icon-${size}x${size}.svg`);
});

console.log('\\nSVG icons generated! For PNG conversion, use a tool like sharp or imagemagick.');
console.log('Or use an online SVG to PNG converter.');
