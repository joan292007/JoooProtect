#!/bin/bash

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Memasang proteksi Nests (Sembunyikan + Block Akses)..."
echo ""

# === LANGKAH 1: Restore NestController dari backup asli ===
CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
LATEST_BACKUP=$(ls -t "${CONTROLLER}.bak_"* 2>/dev/null | tail -1)

if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CONTROLLER"
  echo "📦 Controller di-restore dari backup paling awal: $LATEST_BACKUP"
else
  echo "⚠️ Tidak ada backup, menggunakan file saat ini"
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_${TIMESTAMP}"

# === LANGKAH 2: Inject proteksi ke NestController ===
python3 << 'PYEOF'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Proteksi sudah ada di NestController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke NestController")
PYEOF

echo ""
echo "📋 Verifikasi NestController (cari PROTEKSI):"
grep -n "PROTEKSI_JHONALEY" "$CONTROLLER"
echo ""

# === LANGKAH 3: Proteksi juga EggController (halaman egg di dalam nest) ===
EGG_CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"
if [ -f "$EGG_CONTROLLER" ]; then
  if ! grep -q "PROTEKSI_JHONALEY" "$EGG_CONTROLLER"; then
    cp "$EGG_CONTROLLER" "${EGG_CONTROLLER}.bak_${TIMESTAMP}"
    
    python3 << 'PYEOF2'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Sudah ada proteksi di EggController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ EggController juga diproteksi")
PYEOF2
  else
    echo "⚠️ EggController sudah diproteksi"
  fi
fi

# === LANGKAH 4: Sembunyikan menu Nests di sidebar ===
echo "🔧 Menyembunyikan menu Nests dari sidebar..."

SIDEBAR_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"
)

SIDEBAR_FOUND=""
for SF in "${SIDEBAR_FILES[@]}"; do
  if [ -f "$SF" ]; then
    SIDEBAR_FOUND="$SF"
    break
  fi
done

if [ -z "$SIDEBAR_FOUND" ]; then
  SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/layouts/ 2>/dev/null | head -1)
  if [ -z "$SIDEBAR_FOUND" ]; then
    SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/partials/ 2>/dev/null | head -1)
  fi
fi

if [ -n "$SIDEBAR_FOUND" ]; then
  # Backup hanya kalau belum di-backup oleh protect12
  if [ ! -f "${SIDEBAR_FOUND}.bak_${TIMESTAMP}" ]; then
    cp "$SIDEBAR_FOUND" "${SIDEBAR_FOUND}.bak_${TIMESTAMP}"
  fi
  echo "📂 Sidebar ditemukan: $SIDEBAR_FOUND"
  
  echo "📋 Baris terkait Nests di sidebar:"
  grep -n -i "nest" "$SIDEBAR_FOUND" | head -10
  echo ""
  
  python3 << PYEOF3
sidebar = "$SIDEBAR_FOUND"

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_NESTS_SIDEBAR" in content:
    print("⚠️ Sidebar Nests sudah diproteksi")
    exit(0)

import re

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    
    # Cari baris yang mengandung referensi ke nests menu
    if ('admin.nests' in line or "route('admin.nests')" in line) and 'admin.nests.view' not in line and 'admin.nests.egg' not in line:
        # Mundur ke baris <li> terdekat
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1
        
        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_NESTS_SIDEBAR --}}")
            new_lines.insert(li_start, "@if((int) Auth::user()->id === 1)")
            
            new_lines.append(line)
            i += 1
            
            # Cari </li> penutup
            li_depth = 1
            while i < len(lines) and li_depth > 0:
                curr = lines[i]
                li_depth += curr.count('<li') - curr.count('</li')
                new_lines.append(curr)
                i += 1
            
            new_lines.append("@endif")
            continue
    
    new_lines.append(line)
    i += 1

with open(sidebar, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Menu Nests disembunyikan dari sidebar")
PYEOF3

else
  echo "⚠️ File sidebar tidak ditemukan."
fi

# === LANGKAH 5: Clear semua cache ===
cd /var/www/pterodactyl
php artisan route:clear 2>/dev/null
php artisan config:clear 2>/dev/null
php artisan cache:clear 2>/dev/null
php artisan view:clear 2>/dev/null
echo "✅ Semua cache dibersihkan"

echo ""
echo "==========================================="
echo "✅ Proteksi Nests LENGKAP selesai!"
echo "==========================================="
echo "🔒 Menu Nests disembunyikan dari sidebar (selain ID 1)"
echo "🔒 Akses /admin/nests diblock (selain ID 1)"
echo "🔒 Akses /admin/nests/view/* diblock (selain ID 1)"
echo "🔒 EggController juga diproteksi"
echo "🚀 Panel tetap normal, server tetap jalan"
echo "==========================================="
echo ""
echo "⚠️ Jika ada masalah, restore:"
echo "   cp ${CONTROLLER}.bak_${TIMESTAMP} $CONTROLLER"
if [ -n "$SIDEBAR_FOUND" ]; then
echo "   cp ${SIDEBAR_FOUND}.bak_${TIMESTAMP} $SIDEBAR_FOUND"
fi
echo "   cd /var/www/pterodactyl && php artisan view:clear && php artisan route:clear"

# ============================================================
# === BRANDING: Inject footer Jhonaley Tech ke layout panel ===
# ============================================================
echo ""
echo "🎨 Memasang bbranding Jooo Protect..."

LAYOUT_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/master.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/auth.blade.php"
)

inject_branding() {
  local FILE="$1"
  local LABEL="$2"

  if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    return
  fi

  if grep -q "BRANDING_JHONALEY" "$FILE"; then
    echo "⚠️ Branding sudah ada di $LABEL, skip."
    return
  fi

  if [ ! -f "${FILE}.bak_${TIMESTAMP}" ]; then
    cp "$FILE" "${FILE}.bak_${TIMESTAMP}"
  fi

  python3 << BRANDING_EOF
layout = "$FILE"

with open(layout, "r") as f:
    content = f.read()

if "BRANDING_JHONALEY" in content:
    exit(0)

branding_css = """
<!-- BRANDING_JHONALEY: Custom Branding -->
<style>
  .jhonaley-footer {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 9999;
    background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
    padding: 10px 20px;
    text-align: center;
    border-top: 2px solid rgba(99, 102, 241, 0.5);
    box-shadow: 0 -4px 20px rgba(99, 102, 241, 0.15);
    font-family: 'Segoe UI', system-ui, sans-serif;
  }
  .jhonaley-footer .jt-inner {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    flex-wrap: wrap;
  }
  .jhonaley-footer .jt-badge {
    background: linear-gradient(135deg, #6366f1, #8b5cf6);
    color: #fff;
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1px;
    text-transform: uppercase;
    box-shadow: 0 2px 10px rgba(99, 102, 241, 0.4);
  }
  .jhonaley-footer .jt-text {
    color: #c4b5fd;
    font-size: 13px;
    font-weight: 500;
  }
  .jhonaley-footer .jt-text a {
    color: #818cf8;
    text-decoration: none;
    font-weight: 600;
    transition: all 0.3s ease;
  }
  .jhonaley-footer .jt-text a:hover {
    color: #a78bfa;
    text-shadow: 0 0 10px rgba(139, 92, 246, 0.5);
  }
  .jhonaley-footer .jt-separator {
    color: #4338ca;
    font-size: 10px;
  }
  .jhonaley-footer .jt-tg {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: rgba(99, 102, 241, 0.15);
    border: 1px solid rgba(99, 102, 241, 0.3);
    padding: 3px 10px;
    border-radius: 15px;
    color: #a5b4fc;
    font-size: 12px;
    text-decoration: none;
    transition: all 0.3s ease;
  }
  .jhonaley-footer .jt-tg:hover {
    background: rgba(99, 102, 241, 0.3);
    border-color: rgba(129, 140, 248, 0.5);
    color: #c7d2fe;
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(99, 102, 241, 0.2);
  }
  .jhonaley-footer .jt-tg svg {
    width: 14px;
    height: 14px;
    fill: currentColor;
  }
  .jhonaley-footer .jt-promo {
    color: #fbbf24;
    font-size: 12px;
    font-weight: 600;
    text-shadow: 0 0 8px rgba(251, 191, 36, 0.3);
  }
  .jhonaley-footer .jt-promo a {
    color: #facc15;
    text-decoration: none;
    font-weight: 700;
    transition: all 0.3s ease;
  }
  .jhonaley-footer .jt-promo a:hover {
    color: #fde68a;
    text-shadow: 0 0 12px rgba(253, 224, 71, 0.5);
  }
  body {
    padding-bottom: 50px !important;
  }
</style>
"""

branding_html = """
<!-- BRANDING_JHONALEY: Footer -->
<div class="jhonaley-footer">
  <div class="jt-inner">
    <span class="jt-badge">⚡ Protected</span>
    <span class="jt-text">Panel by <a href="https://t.me/danangvalentp" target="_blank">Jooo Protect</a></span>
    <span class="jt-separator">●</span>
    <a class="jt-tg" href="https://t.me/atentrei" target="_blank">
      <svg viewBox="0 0 24 24"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>
      @atentrei
    </a>
    <span class="jt-separator">●</span>
    <span class="jt-promo">Butuh panel yang anti mokad? Langsung aja ke <a href="https://t.me/JoCpanel_bot" target="_blank">@JoCpanel_bot</a></span>
  </div>
</div>
"""

if "</body>" in content:
    content = content.replace("</body>", branding_css + branding_html + "\\n</body>")
elif "</html>" in content:
    content = content.replace("</html>", branding_css + branding_html + "\\n</html>")
else:
    content += branding_css + branding_html

with open(layout, "w") as f:
    f.write(content)

print("✅ Branding dipasang di " + layout)
BRANDING_EOF

  echo "✅ Branding dipasang di $LABEL"
}

for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ]; then
    inject_branding "$LF" "$(basename $LF)"
  fi
done

# Ubah title panel
for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ]; then
    if grep -q "<title>" "$LF" && ! grep -q "Jhonaley Tech" "$LF"; then
      sed -i 's/<title>.*<\/title>/<title>Pterodactyl - Jhonaley Tech<\/title>/g' "$LF" 2>/dev/null
      echo "✅ Title diubah di $(basename $LF)"
    fi
  fi
done

php artisan view:clear 2>/dev/null
echo ""
echo "🎨 Branding Jooo Protect terpasang!"
echo "   ⚡ Footer gradient + badge Protected"
echo "   📱 Link Telegram @atentrei"
echo "   📝 Promo @JoCpanel_bot"
echo "   📝 Title panel diubah"
