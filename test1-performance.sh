#!/usr/bin/env bash
set -e
echo "⚡ Starte Performance-Tuning …"

# ── Pakete
sudo apt install -y cpufrequtils zram-tools smartmontools util-linux

# ── ZRAM-Optimierung
sudo tee /etc/default/zramswap >/dev/null <<'EOF'
ALGO=zstd
PERCENT=60
PRIORITY=100
EOF
sudo systemctl enable --now zramswap.service

# ── CPU-Governor (performance bei Netzbetrieb)
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils >/dev/null
sudo systemctl disable ondemand.service 2>/dev/null || true
sudo systemctl enable --now cpufrequtils.service

# ── Kernel-Parameter (sysctl tuning)
sudo tee /etc/sysctl.d/99-performance.conf >/dev/null <<'EOF'
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.vfs_cache_pressure=50
kernel.sched_latency_ns=6000000
kernel.sched_min_granularity_ns=750000
kernel.sched_migration_cost_ns=500000
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sudo sysctl --system >/dev/null

# ── SSD-Trim (automatisch wöchentlich)
sudo systemctl enable fstrim.timer
sudo systemctl start fstrim.timer

# ── Scheduler (SSD + Multicore optimiert)
for dev in $(lsblk -nd --output NAME,ROTA | awk '$2==0 {print $1}'); do
  if [ -w /sys/block/$dev/queue/scheduler ]; then
    echo "mq-deadline" | sudo tee /sys/block/$dev/queue/scheduler >/dev/null
  fi
done

# ── Ausgabe
echo
echo "✅ Performance-Tuning abgeschlossen!"
echo "🧠 CPU-Governor: Performance"
echo "💾 ZRAM aktiv (zstd, 60%)"
echo "⚙️  SSD-Trim wöchentlich aktiviert"
echo "🚀 Sysctl & I/O Scheduler optimiert"
