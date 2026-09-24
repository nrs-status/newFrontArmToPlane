#!/usr/bin/env bash
# status-stats.sh -- rightmost status-bar segment: total CPU %, total RAM %
# and the average CPU temperature.
#
# Invoked through tmux's #(...) status-right mechanism, so it must print a
# single line.  tmux re-runs it at most once per status-interval (see
# `interval` in default.nix), which doubles as the sampling window for the
# CPU-usage delta.
#
# All inputs come from /proc and /sys, so it only needs bash + standard
# coreutils -- no lm_sensors / sysstat dependency.

# sampling window in seconds; tmux's status-right fragment invokes this as
# `interval=5 <script>`, which doubles as the CPU-usage measurement window.
interval="${interval:-5}"

# ---------------------------------------------------------------------------
# total CPU usage: sample /proc/stat twice around a `sleep interval` window
# ---------------------------------------------------------------------------
# /proc/stat's "cpu" aggregate line: user nice system idle iowait irq softirq
# steal ...  Busy = total - (idle + iowait).  Two samples around a sleep give
# a real utilisation percentage instead of a boot-average.
prev=$(awk '/^cpu / {print $2+$3+$4+$6+$7+$8, $5+$6}' /proc/stat 2>/dev/null)
sleep "$interval"
[ -n "$prev" ] || prev="0 0"
prev_busy=${prev% *}
prev_idle=${prev#* }

read -r cur_busy cur_idle <<< "$(awk '/^cpu / {print $2+$3+$4+$6+$7+$8, $5+$6}' /proc/stat 2>/dev/null)"
if [ -z "$cur_busy" ] || [ "$cur_busy" -le "$prev_busy" ] || [ "$cur_idle" -le "$prev_idle" ]; then
    cpu_pct=0
else
    # integer math only -- bash lacks floating point and awk(1) is not
    # guaranteed in the closure of a minimal tmux package.
    cpu_pct=$(((cur_busy - prev_busy) * 100 / ((cur_busy - prev_busy) + (cur_idle - prev_idle))))
fi

# ---------------------------------------------------------------------------
# total RAM usage: MemTotal / MemAvailable from /proc/meminfo
# ---------------------------------------------------------------------------
# MemAvailable is the kernel's estimate of memory available without swapping
# (free's "available" column), the standard way of reporting "used" as a
# percentage: used% = (total - available) / total.
mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
mem_avail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
if [ -z "$mem_avail" ]; then
    # very old kernels without MemAvailable: approximate from free+buffers+cache
    mem_avail=$((mem_total - $(awk '/^MemFree:/ {print $2}' /proc/meminfo) - $(awk '/^Buffers:/ {print $2}' /proc/meminfo) - $(awk '/^Cached:/ {print $2}' /proc/meminfo)))
fi
mem_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))

# ---------------------------------------------------------------------------
# average CPU temperature: mean of every Core N sensor under coretemp hwmon
# ---------------------------------------------------------------------------
# The "Package id" sensor covers the whole die; the per-core sensors are the
# fine-grained signal, so average the "Core N" ones.  Their _input files are
# millidegrees Celsius.
total=0
count=0
for chip in /sys/class/hwmon/hwmon*; do
    [ -r "$chip/name" ] && grep -q '^coretemp$' "$chip/name" 2>/dev/null || continue
    for input in "$chip"/temp*_input; do
        [ -e "$input" ] || continue
        label_file="${input%_input}_label"
        if [ -r "$label_file" ] && grep -q '^Core ' "$label_file" 2>/dev/null; then
            total=$((total + $(< "$input")))
            count=$((count + 1))
        fi
    done
done
if [ "$count" -gt 0 ]; then
    temp_c=$(( ((total / count) + 500) / 1000 ))   # millidegrees -> degrees, rounded
else
    temp_c=0
fi

printf 'CPU %d%% | RAM %d%% | %d°C\n' "$cpu_pct" "$mem_pct" "$temp_c"
