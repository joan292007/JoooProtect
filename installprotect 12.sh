#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Akses Settings..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\View\View;
use Pterodactyl\Models\Node;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Repositories\Eloquent\NodeRepository;
use Pterodactyl\Services\Nodes\NodeUpdateService;
use Pterodactyl\Services\Nodes\NodeCreationService;
use Pterodactyl\Services\Nodes\NodeDeletionService;
use Pterodactyl\Http\Requests\Admin\Node\NodeFormRequest;
use Pterodactyl\Contracts\Repository\AllocationRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Node\AllocationFormRequest;

class NodeViewController extends Controller
{
    /**
     * 🔒 Fungsi tambahan: Cegah akses node view oleh admin lain.
     */
    private function checkNodeAccess($request, Node $node = null)
    {
        $user = $request->user();

        // Admin (user id = 1) bebas akses semua
        if ($user->id === 1) {
            return;
        }

        // Jika bukan admin ID 1, tolak akses dengan efek blur dan error
        abort(403, '✖️ 𝖺𝗄𝗌𝖾𝗌 𝖽𝗂𝗍𝗈𝗅𝖺𝗄 𝗉𝗋𝗈𝗍𝖾𝖼𝗍 𝖻𝗒 Jooo Protect');
    }

    /**
     * Display overview of a node for the admin user.
     */
    public function index(NodeRepository $repository, string $id): View
    {
        $this->checkNodeAccess(request());
        
        $node = $repository->getNodeWithResourceUsage($id);
        
        return view('admin.nodes.view.index', [
            'node' => $node,
            'stats' => [
                'version' => $node->getAttribute('daemon_version'),
                'system' => [
                    'type' => $node->getAttribute('daemon_system_type'),
                    'arch' => $node->getAttribute('daemon_system_arch'),
                    'version' => $node->getAttribute('daemon_system_version'),
                ],
                'cpus' => $node->getAttribute('daemon_cpu_count'),
            ],
        ]);
    }

    /**
     * Display settings for a specific node.
     */
    public function settings(string $id): View
    {
        $this->checkNodeAccess(request());
        
        $node = Node::findOrFail($id);
        
        return view('admin.nodes.view.settings', [
            'node' => $node,
            'locations' => \Pterodactyl\Models\Location::all(),
        ]);
    }

    /**
     * Display configuration for a specific node.
     */
    public function configuration(string $id): View
    {
        $this->checkNodeAccess(request());
        
        $node = Node::findOrFail($id);
        
        return view('admin.nodes.view.configuration', [
            'node' => $node,
        ]);
    }

    /**
     * Display allocations for a specific node.
     */
    public function allocations(AllocationRepositoryInterface $repository, string $id): View
    {
        $this->checkNodeAccess(request());
        
        $node = Node::findOrFail($id);
        
        $allocations = $repository->getPaginatedAllocationsForNode($id, 50);
        
        return view('admin.nodes.view.allocations', [
            'node' => $node,
            'allocations' => $allocations,
        ]);
    }

    /**
     * Display servers for a specific node.
     */
    public function servers(string $id): View
    {
        $this->checkNodeAccess(request());
        
        $node = Node::findOrFail($id);
        
        $servers = $node->servers()->with('user', 'egg')->paginate(50);
        
        return view('admin.nodes.view.servers', [
            'node' => $node,
            'servers' => $servers,
        ]);
    }

    /**
     * Update node settings.
     */
    public function updateSettings(NodeFormRequest $request, NodeUpdateService $service, string $id): \Illuminate\Http\RedirectResponse
    {
        $this->checkNodeAccess(request());
        
        $node = Node::findOrFail($id);
        $service->update($node, $request->validated(), $request->user());
        
        return redirect()->route('admin.nodes.view.settings', $node->id)
            ->with('success', 'Node settings were updated successfully.');
    }

    /**
     * Update node configuration.
     */
    public function updateConfiguration(NodeFormRequest $request, NodeUpdateService $service, string $id): \Illuminate\Http\RedirectResponse
    {
        $this->checkNodeAccess(request());
        
        $node = Node::findOrFail($id);
        $service->updateConfiguration($node, $request->validated());
        
        return redirect()->route('admin.nodes.view.configuration', $node->id)
            ->with('success', 'Node configuration was updated successfully.');
    }

    /**
     * Create new allocation for node.
     */
    public function createAllocation(AllocationFormRequest $request, NodeUpdateService $service, string $id): \Illuminate\Http\RedirectResponse
    {
        $this->checkNodeAccess(request());
        
        $node = Node::findOrFail($id);
        $service->createAllocation($node, $request->validated());
        
        return redirect()->route('admin.nodes.view.allocations', $node->id)
            ->with('success', 'Allocation was created successfully.');
    }

    /**
     * Delete allocation from node.
     */
    public function deleteAllocation(string $id, string $allocationId, NodeDeletionService $service): \Illuminate\Http\RedirectResponse
    {
        $this->checkNodeAccess(request());
        
        $node = Node::findOrFail($id);
        $service->deleteAllocation($node, $allocationId);
        
        return redirect()->route('admin.nodes.view.allocations', $node->id)
            ->with('success', 'Allocation was deleted successfully.');
    }

    /**
     * Delete node.
     */
    public function deleteNode(string $id, NodeDeletionService $service): \Illuminate\Http\RedirectResponse
    {
        $this->checkNodeAccess(request());
        
        $node = Node::findOrFail($id);
        $service->handle($node);
        
        return redirect()->route('admin.nodes')
            ->with('success', 'Node was deleted successfully.');
    }
}
?>

# Juga proteksi file view template untuk efek blur
VIEW_PATH="/var/www/pterodactyl/resources/views/admin/nodes/view"
if [ -d "$VIEW_PATH" ]; then
    # Backup template index jika ada
    if [ -f "$VIEW_PATH/index.blade.php" ]; then
        cp "$VIEW_PATH/index.blade.php" "$VIEW_PATH/index.blade.php.bak_$TIMESTAMP"
    fi
    
    # Buat template dengan efek blur untuk admin lain
    cat > "$VIEW_PATH/index.blade.php" << 'EOF'
@extends('layouts.admin')

@section('title')
    Node: {{ $node->name }}
@endsection

@section('content-header')
    <h1>{{ $node->name }}<small>Detailed node overview.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li><a href="{{ route('admin.nodes') }}">Nodes</a></li>
        <li class="active">{{ $node->name }}</li>
    </ol>
@endsection

@section('content')
@php
    $user = Auth::user();
@endphp

@if($user->id !== 1)
    <div style="
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0,0,0,0.8);
        backdrop-filter: blur(10px);
        z-index: 9999;
        display: flex;
        justify-content: center;
        align-items: center;
        flex-direction: column;
        color: white;
        font-family: Arial, sans-serif;
        text-align: center;
    ">
        <div style="font-size: 48px; margin-bottom: 20px;">🚫</div>
        <h1 style="color: #e74c3c; margin-bottom: 10px;">Akses Ditolak</h1>
        <p style="font-size: 18px; margin-bottom: 20px;">Hanya Admin Utama yang dapat mengakses halaman ini</p>
        <p style="font-size: 14px; color: #95a5a6;">protect by Jhonaley Tech</p>
    </div>
    @php
        http_response_code(403);
        exit();
    @endphp
@endif

<div class="row">
    <div class="col-xs-12">
        <div class="nav-tabs-custom nav-tabs-floating">
            <ul class="nav nav-tabs">
                <li class="active"><a href="{{ route('admin.nodes.view', $node->id) }}">About</a></li>
                <li><a href="{{ route('admin.nodes.view.settings', $node->id) }}">Settings</a></li>
                <li><a href="{{ route('admin.nodes.view.configuration', $node->id) }}">Configuration</a></li>
                <li><a href="{{ route('admin.nodes.view.allocations', $node->id) }}">Allocations</a></li>
                <li><a href="{{ route('admin.nodes.view.servers', $node->id) }}">Servers</a></li>
            </ul>
        </div>
    </div>
</div>

<div class="row">
    <div class="col-sm-8">
        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Information</h3>
            </div>
            <div class="box-body">
                <div class="row">
                    <div class="col-xs-6">
                        <strong>Daemon Version</strong>
                        <p class="text-muted">
                            {{ $stats['version'] ?? 'N/A' }}
                            @if(($stats['version'] ?? null) === $node->daemonVersion)
                                <span class="label label-success">Latest</span>
                            @endif
                        </p>
                    </div>
                    <div class="col-xs-6">
                        <strong>System Information</strong>
                        <p class="text-muted">
                            {{ $stats['system']['type'] ?? 'N/A' }} ({{ $stats['system']['arch'] ?? 'N/A' }})<br>
                            <small>{{ $stats['system']['version'] ?? 'N/A' }}</small>
                        </p>
                    </div>
                    <div class="col-xs-6">
                        <strong>Total CPU Threads</strong>
                        <p class="text-muted">{{ $stats['cpus'] ?? 'N/A' }}</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <div class="col-sm-4">
        <div class="box box-danger">
            <div class="box-header with-border">
                <h3 class="box-title">Delete Node</h3>
            </div>
            <div class="box-body">
                <p>Deleting a node is an irreversible action and will immediately remove this node from the panel. There must be no servers associated with this node in order to continue.</p>
            </div>
            <div class="box-footer">
                <form action="{{ route('admin.nodes.view.delete', $node->id) }}" method="POST">
                    @csrf
                    @method('DELETE')
                    <button type="submit" class="btn btn-danger btn-sm" {{ $node->servers_count > 0 ? 'disabled' : '' }}>Delete Node</button>
                </form>
            </div>
        </div>
    </div>
</div>
@endsection
EOF

    echo "✅ Template view dengan efek blur berhasil dipasang!"
fi

echo "✅ Proteksi Anti Akses Admin Nodes View berhasil dipasang!"
echo "📂 Lokasi file controller: $REMOTE_PATH"
echo "📂 Lokasi template view: $VIEW_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hanya Admin ID 1 yang bisa akses normal, admin lain akan melihat efek blur dan error 403"
echo "🚫 Pesan error: 'akses ditolak, protect by @atentrei'"