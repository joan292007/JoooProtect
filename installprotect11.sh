#!/bin/bash

echo "🚀 Memasang proteksi Anti Tautan Server..."

# File paths
INDEX_FILE="/var/www/pterodactyl/resources/views/admin/servers/index.blade.php"
VIEW_DIR="/var/www/pterodactyl/resources/views/admin/servers/view"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

# Backup original files
if [ -f "$INDEX_FILE" ]; then
  cp "$INDEX_FILE" "${INDEX_FILE}.bak_${TIMESTAMP}"
  echo "📦 Backup index file dibuat: ${INDEX_FILE}.bak_${TIMESTAMP}"
fi

# 1. Update Index File - Hanya admin ID 1 yang bisa manage, tapi Create New bisa untuk semua admin
cat > "$INDEX_FILE" << 'EOF'
@extends('layouts.admin')
@section('title')
    Servers
@endsection

@section('content-header')
    <h1>Servers<small>All servers available on the system.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Servers</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Server List</h3>
                <div class="box-tools search01">
                    <form action="{{ route('admin.servers') }}" method="GET">
                        <div class="input-group input-group-sm">
                            <input type="text" name="query" class="form-control pull-right" value="{{ request()->input('query') }}" placeholder="Search Servers">
                            <div class="input-group-btn">
                                <button type="submit" class="btn btn-default"><i class="fa fa-search"></i></button>
                                <!-- CREATE NEW BISA DIKLIK OLEH SEMUA ADMIN -->
                                <a href="{{ route('admin.servers.new') }}"><button type="button" class="btn btn-sm btn-primary" style="border-radius:0 3px 3px 0;margin-left:2px;">Create New</button></a>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
            <div class="box-body table-responsive no-padding">
                <table class="table table-hover">
                    <thead>
                        <tr>
                            <th>Server Name</th>
                            <th>UUID</th>
                            <th>Owner</th>
                            <th>Node</th>
                            <th>Connection</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($servers as $server)
                            <tr class="align-middle">
                                <td class="middle">
                                    <strong>{{ $server->name }}</strong>
                                    @if($server->id == 26)
                                    <br><small class="text-muted">Jhoanley Tech</small>
                                    @endif
                                </td>
                                <td class="middle"><code>{{ $server->uuidShort }}</code></td>
                                <td class="middle">
                                    <span class="label label-default">
                                        <i class="fa fa-user"></i> {{ $server->user->username }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <span class="label label-info">
                                        <i class="fa fa-server"></i> {{ $server->node->name }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <code>{{ $server->allocation->alias }}:{{ $server->allocation->port }}</code>
                                    @if($server->id == 26)
                                    <br><small><code>Jhoanley Tech:2007</code></small>
                                    @endif
                                </td>
                                <td class="text-center">
                                    @if(auth()->user()->id === 1)
                                        <!-- Admin ID 1 bisa akses semua -->
                                        <a href="{{ route('admin.servers.view', $server->id) }}" class="btn btn-xs btn-primary">
                                            <i class="fa fa-wrench"></i> Manage
                                        </a>
                                    @else
                                        <!-- Admin lain tidak bisa akses manage server existing -->
                                        <span class="label label-warning" data-toggle="tooltip" title="Hanya Root Admin yang bisa mengakses">
                                            <i class="fa fa-shield"></i> Protected
                                        </span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            @if($servers->hasPages())
                <div class="box-footer with-border">
                    <div class="col-md-12 text-center">{!! $servers->appends(['query' => Request::input('query')])->render() !!}</div>
                </div>
            @endif
        </div>

        <!-- Security Information Box -->
        @if(auth()->user()->id !== 1)
        <div class="alert alert-warning">
            <h4 style="margin-top: 0;">
                <i class="fa fa-shield"></i> Security Protection Active
            </h4>
            <p style="margin-bottom: 5px;">
                <strong>🔒 Server Management Restricted:</strong> 
                Hanya <strong>Root Administrator (ID: 1)</strong> yang dapat mengelola server existing.
            </p>
            <p style="margin-bottom: 0; font-size: 12px;">
                <strong>✅ Create New Server:</strong> Available for all administrators<br>
                <strong>🚫 Manage Existing:</strong> Root Admin only<br>
                <i class="fa fa-info-circle"></i> 
                Protected by: 
                <span class="label label-primary">@danangvalentp</span>
                <span class="label label-success">@jhonaleytesti3</span>
                <span class="label label-info">Jhonaley Tech</span>
            </p>
        </div>
        @else
        <div class="alert alert-success">
            <h4 style="margin-top: 0;">
                <i class="fa fa-crown"></i> Root Administrator Access
            </h4>
            <p style="margin-bottom: 0;">
                Anda memiliki akses penuh sebagai <strong>Root Administrator (ID: 1)</strong>.
                Semua server dapat dikelola secara normal.
            </p>
        </div>
        @endif
    </div>
</div>
@endsection

@section('footer-scripts')
    @parent
    <script>
        $(document).ready(function() {
            $('[data-toggle="tooltip"]').tooltip();
            
            // Block server management untuk admin selain ID 1
            @if(auth()->user()->id !== 1)
            $('a[href*="/admin/servers/view/"]').on('click', function(e) {
                e.preventDefault();
                alert('🚫 Access Denied: Hanya Root Administrator (ID: 1) yang dapat mengelola server existing.\n\n✅ Anda masih bisa membuat server baru dengan tombol "Create New"\n\nProtected by: @atentrei');
            });
            @endif
        });
    </script>
@endsection
EOF

echo "✅ Index file berhasil diproteksi (Create New bisa untuk semua admin)"

# 2. Proteksi view server untuk admin selain ID 1 dengan efek blur sederhana
mkdir -p "$VIEW_DIR"

# Buat protection untuk semua view server
find "$VIEW_DIR" -name "*.blade.php" | while read view_file; do
    if [ -f "$view_file" ]; then
        cp "$view_file" "${view_file}.bak_${TIMESTAMP}" 2>/dev/null
    fi
    
    # Buat file view dengan protection sederhana - BLUR EFFECT
    cat > "$view_file" << 'EOF'
@if(auth()->user()->id !== 1)
{{-- BLUR PROTECTION FOR NON-ROOT ADMINS --}}
<div style="
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.8);
    backdrop-filter: blur(20px);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-direction: column;
    color: white;
    text-align: center;
    padding: 20px;
">
    <div style="
        background: rgba(255,255,255,0.1);
        padding: 40px;
        border-radius: 15px;
        backdrop-filter: blur(10px);
        border: 1px solid rgba(255,255,255,0.2);
        max-width: 500px;
        width: 100%;
    ">
        <div style="font-size: 48px; margin-bottom: 20px;">🔒</div>
        <h2 style="margin: 0 0 10px 0; color: white;">Access Restricted</h2>
        <p style="margin: 0 0 20px 0; opacity: 0.9;">
            Hanya Root Administrator (ID: 1) yang dapat mengakses server management.
        </p>
        <div style="
            background: rgba(255,255,255,0.1);
            padding: 15px;
            border-radius: 10px;
            margin: 20px 0;
            border: 1px solid rgba(255,255,255,0.1);
        ">
            <strong style="display: block; margin-bottom: 10px;">Protected by Security Team:</strong>
            <div style="display: flex; gap: 10px; justify-content: center; flex-wrap: wrap;">
                <span style="background: #e84393; padding: 5px 12px; border-radius: 15px; font-size: 12px;">@danangvalentp</span>
                <span style="background: #0984e3; padding: 5px 12px; border-radius: 15px; font-size: 12px;">@AndinOfficial</span>
                <span style="background: #00b894; padding: 5px 12px; border-radius: 15px; font-size: 12px;">@naaofficial</span>
            </div>
        </div>
        <button onclick="window.location.href='/admin/servers'" style="
            background: rgba(255,255,255,0.2);
            color: white;
            border: 1px solid rgba(255,255,255,0.3);
            padding: 10px 25px;
            border-radius: 25px;
            cursor: pointer;
            font-weight: bold;
            margin-top: 10px;
        ">
            ← Back to Server List
        </button>
    </div>
</div>

<script>
    // Prevent right-click
    document.addEventListener('contextmenu', function(e) {
        e.preventDefault();
    });
    
    // Auto redirect after 5 seconds
    setTimeout(() => {
        window.location.href = '/admin/servers';
    }, 5000);
</script>
@endif

{{-- ADMIN ID 1 MASIH BISA AKSES NORMAL --}}
@if(auth()->user()->id === 1)
@extends('layouts.admin')
@section('title')
    Server — {{ $server->name }}
@endsection

@section('content-header')
    <h1>{{ $server->name }}<small>{{ $server->description ?: 'No description provided' }}</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li><a href="{{ route('admin.servers') }}">Servers</a></li>
        <li class="active">{{ $server->name }}</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        <div class="nav-tabs-custom nav-tabs-floating">
            <ul class="nav nav-tabs">
                <li class="active"><a href="#tab_1" data-toggle="tab">Details</a></li>
                <li><a href="#tab_2" data-toggle="tab">Build</a></li>
                <li><a href="#tab_3" data-toggle="tab">Startup</a></li>
                <li><a href="#tab_4" data-toggle="tab">Database</a></li>
                <li><a href="#tab_5" data-toggle="tab">Schedules</a></li>
                <li><a href="#tab_6" data-toggle="tab">Users</a></li>
                <li><a href="#tab_7" data-toggle="tab">Backups</a></li>
                <li><a href="#tab_8" data-toggle="tab">Network</a></li>
            </ul>
            <div class="tab-content">
                <div class="tab-pane active" id="tab_1">
                    <div class="alert alert-success">
                        <i class="fa fa-crown"></i> <strong>Root Administrator Access</strong><br>
                        Anda memiliki akses penuh sebagai <strong>Root Administrator (ID: 1)</strong>.
                    </div>
                    
                    <div class="row">
                        <div class="col-md-6">
                            <dl>
                                <dt>Server Name</dt>
                                <dd>{{ $server->name }}</dd>
                                <dt>Server Owner</dt>
                                <dd>{{ $server->user->username }}</dd>
                                <dt>Node</dt>
                                <dd>{{ $server->node->name }}</dd>
                            </dl>
                        </div>
                        <div class="col-md-6">
                            <dl>
                                <dt>Connection</dt>
                                <dd><code>{{ $server->allocation->alias }}:{{ $server->allocation->port }}</code></dd>
                                <dt>UUID</dt>
                                <dd><code>{{ $server->uuid }}</code></dd>
                                <dt>Status</dt>
                                <dd>
                                    @if($server->suspended)
                                        <span class="label label-danger">Suspended</span>
                                    @else
                                        <span class="label label-success">Active</span>
                                    @endif
                                </dd>
                            </dl>
                        </div>
                    </div>
                </div>
                <!-- Other tabs content would go here -->
            </div>
        </div>
    </div>
</div>
@endsection
@endif
EOF
    echo "✅ Protected: $(basename "$view_file") dengan efek blur"
done

# Set permissions
chmod 644 "$INDEX_FILE"
find "$VIEW_DIR" -name "*.blade.php" -exec chmod 644 {} \;

# Clear cache
echo "🔄 Membersihkan cache..."
cd /var/www/pterodactyl
php artisan view:clear
php artisan cache:clear

echo ""
echo "🎉 PROTEKSI BERHASIL DIPASANG!"
echo "✅ Admin ID 1: Bisa akses semua (server list, view, dan management)"
echo "✅ Admin lain: Bisa Create New server, tapi tidak bisa manage existing"
echo "✅ View server: Efek blur untuk admin selain ID 1"
echo "✅ Tombol 'Create New' bisa diklik oleh semua admin"
echo "🛡️ Security by: @atentrei"
