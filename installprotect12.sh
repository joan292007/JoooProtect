#!/bin/bash

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Memasang proteksi Nodes (Sembunyikan + Block Akses)..."
echo ""

# === LANGKAH 1: Restore controller dari backup asli ===
CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"
LATEST_BACKUP=$(ls -t "${CONTROLLER}.bak_"* 2>/dev/null | tail -1)

if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CONTROLLER"
  echo "📦 Controller di-restore dari backup paling awal: $LATEST_BACKUP"
else
  echo "⚠️ Tidak ada backup, menggunakan file saat ini"
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_${TIMESTAMP}"

# === LANGKAH 2: Inject proteksi ke controller pakai python3 ===
python3 << 'PYEOF'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"

with open(controller, "r") as f:
    content = f.read()

# Skip jika sudah ada proteksi
if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Proteksi sudah ada di controller")
    exit(0)

# Tambahkan use Auth jika belum ada
if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

# Cari semua public function (kecuali __construct) dan inject pengecekan
lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    # Detect public function (bukan constructor)
    if re.search(r'public function (?!__construct)', line):
        # Cari opening brace {
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        # Tambahkan pengecekan setelah {
        new_lines.append("        // PROTEKSI_JHONALEY: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jooo Protect');")
        new_lines.append("        }")
        
        if j > i:
            i = j  # Skip lines we already added
    
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke controller")
PYEOF

echo ""
echo "📋 Verifikasi controller (cari PROTEKSI):"
grep -n "PROTEKSI_JHONALEY" "$CONTROLLER"
echo ""

# === LANGKAH 3: Sembunyikan menu Nodes di sidebar ===
echo "🔧 Menyembunyikan menu Nodes dari sidebar..."

# Cari file sidebar layout
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
  # Cari file yang mengandung menu Nodes
  SIDEBAR_FOUND=$(grep -rl "admin.nodes" /var/www/pterodactyl/resources/views/layouts/ 2>/dev/null | head -1)
  if [ -z "$SIDEBAR_FOUND" ]; then
    SIDEBAR_FOUND=$(grep -rl "admin.nodes" /var/www/pterodactyl/resources/views/partials/ 2>/dev/null | head -1)
  fi
fi

if [ -n "$SIDEBAR_FOUND" ]; then
  cp "$SIDEBAR_FOUND" "${SIDEBAR_FOUND}.bak_${TIMESTAMP}"
  echo "📂 Sidebar ditemukan: $SIDEBAR_FOUND"
  
  # Tampilkan baris terkait nodes
  echo "📋 Baris terkait Nodes di sidebar:"
  grep -n -i "node" "$SIDEBAR_FOUND" | head -10
  echo ""
  
  # Sembunyikan menu Nodes dengan menambahkan @if(Auth::user()->id === 1)
  python3 << PYEOF2
sidebar = "$SIDEBAR_FOUND"

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_NODES_SIDEBAR" in content:
    print("⚠️ Sidebar sudah diproteksi")
    exit(0)

# Cari link/menu yang mengandung 'admin.nodes' atau 'Nodes'
# Biasanya berbentuk <li> atau <a> element
import re

lines = content.split("\n")
new_lines = []
i = 0
nodes_block_start = False
brace_count = 0

while i < len(lines):
    line = lines[i]
    
    # Cari baris yang mengandung referensi ke nodes menu
    # Pattern: <li yang di dalamnya ada route('admin.nodes') atau href nodes
    if not nodes_block_start and ('admin.nodes' in line or "route('admin.nodes')" in line) and 'admin.nodes.view' not in line:
        # Cari awal <li> sebelum baris ini
        # Mundur ke baris <li> terdekat
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1
        
        if li_start >= 0:
            # Insert @if sebelum <li>
            new_lines.insert(li_start, "{{-- PROTEKSI_NODES_SIDEBAR --}}")
            new_lines.insert(li_start, "@if((int) Auth::user()->id === 1)")
            
            # Cari penutup </li> yang sesuai
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

print("✅ Menu Nodes disembunyikan dari sidebar")
PYEOF2

else
  echo "⚠️ File sidebar tidak ditemukan. Menu Nodes tidak disembunyikan."
  echo "   Cari manual file layout admin dan tambahkan @if(Auth::user()->id === 1) di sekitar menu Nodes"
fi

# === LANGKAH 4: Proteksi juga NodeController (halaman list nodes) ===
NODE_LIST="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
if [ -f "$NODE_LIST" ]; then
  if ! grep -q "PROTEKSI_JHONALEY" "$NODE_LIST"; then
    cp "$NODE_LIST" "${NODE_LIST}.bak_${TIMESTAMP}"
    
    python3 << 'PYEOF3'
controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Sudah ada proteksi")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

import re
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
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jooo Protect');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ NodeController juga diproteksi")
PYEOF3
  else
    echo "⚠️ NodeController sudah diproteksi"
  fi
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
echo "✅ Proteksi Nodes LENGKAP selesai!"
echo "==========================================="
echo "🔒 Menu Nodes disembunyikan dari sidebar (selain ID 1)"
echo "🔒 Akses /admin/nodes diblock (selain ID 1)"
echo "🔒 Akses /admin/nodes/view/* diblock (selain ID 1)"
echo "🚀 Panel tetap normal, server tetap jalan"
echo "==========================================="
echo ""
echo "⚠️ Jika ada masalah, restore:"
echo "   cp ${CONTROLLER}.bak_${TIMESTAMP} $CONTROLLER"
if [ -n "$SIDEBAR_FOUND" ]; then
echo "   cp ${SIDEBAR_FOUND}.bak_${TIMESTAMP} $SIDEBAR_FOUND"
fi
echo "   cd /var/www/pterodactyl && php artisan view:clear && php artisan route:clear"
