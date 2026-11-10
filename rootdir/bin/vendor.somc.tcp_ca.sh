#!/vendor/bin/sh
#
# Voltage: native TCP Optimiser: per-transport TCP congestion control.
#
# The kernel boots with bbr as the default congestion control. This
# service keeps net.ipv4.tcp_congestion_control in sync with the active
# transport (wifi and mobile -> bbr, no link -> boot default) and
# re-asserts the global sysctl tuning on every poll:
#
#   tcp_slow_start_after_idle = 0        (keep cwnd after idle periods)
#   tcp_notsent_lowat         = 131072   (cap unsent bytes per socket)
#   net.core.rmem_max / wmem_max = 16 MB (cap for SO_RCVBUF/SO_SNDBUF)
#   tcp_rmem / tcp_wmem max slot = 16 MB (kernel autotuning cap)
#   tcp_ecn_low = 1 while bbr is active, 0 under any other CC
#
# Per-transport overrides (polled every cycle):
#   persist.vendor.tcp.cc_wifi   = auto | bbr | westwood | cubic | reno
#   persist.vendor.tcp.cc_mobile = auto | bbr | westwood | cubic | reno
#   persist.vendor.tcp.buf_kb    = auto | 4096 | 8192 | 16384 | 32768
#   persist.vendor.tcp.tuning    = 0 turns the global sysctl tuning off
#
# "auto", empty or unknown values keep the built-in per-transport profile
# (bbr on wifi and mobile) and the 16 MB buffer ceiling. The default CC
# applies to NEW sockets only; existing connections keep the algorithm
# they were created with, so a few sockets may lag one poll cycle behind
# a transport handover. That is normal, not a bug.
#
# "Active" means a main-table default route, or the station (wlan0) or
# rmnet_data* link state up/dormant (Android keeps per-network defaults
# in private tables invisible to /proc/net/route). Mismatch warnings go
# to logcat, deduped per node. Started from vendor.somc.tcp_ca.rc
# (class late_start, explicit sys.boot_completed=1 trigger); the SELinux
# domain is derived from the binary path (see sepolicy).

# Tools pinned to vendor copies so the loop never resolves off PATH;
# without sysctl, sysctl_set falls back to direct /proc writes.
SYSCTL="/vendor/bin/sysctl"
GETPROP="/vendor/bin/getprop"
LOG="/vendor/bin/log"

# prop_get <name>: best effort, prints "" when getprop is unavailable.
prop_get()
{
    if [ -x "$GETPROP" ]; then
        "$GETPROP" "$1" 2>/dev/null || true
    fi
}

# warn <message>: logcat warning. Init sends service stderr to /dev/null,
# so the toybox log applet is the usable channel.
warn()
{
    [ -x "$LOG" ] && "$LOG" -p w -t vendor.somc.tcp_ca "$1" 2>/dev/null
    return 0
}

# sysctl_set <dotted.key> <proc_path> <value>: best effort, never warns,
# never fails the loop; nodes absent on other kernels are ignored.
sysctl_set()
{
    if [ -x "$SYSCTL" ]; then
        "$SYSCTL" -q -w "$1=$3" >/dev/null 2>&1 || true
    else
        echo "$3" > "$2" 2>/dev/null || true
    fi
}

# sysctl_apply <dotted.key> <proc_path> <value>: write, then read back.
# A mismatch means the kernel clamped or dropped the node; warn once per
# divergence episode (state resets when the node reads back correct),
# not on every 10 s poll. Dedup state lives in last_mismatch_<key>.
sysctl_apply()
{
    sysctl_set "$1" "$2" "$3"
    read live < "$2" 2>/dev/null || live=""
    _keybase="$1"
    # dedup keys are fixed literals today; refuse anything dynamic
    case "$_keybase" in
        *[!A-Za-z0-9._]*) _keybase="unknown" ;;
    esac
    _keyvar="last_mismatch_${_keybase//./_}"
    if [ "$live" = "$3" ]; then
        # recovered: a later divergence must warn again
        eval "$_keyvar=''"
        return 0
    fi
    msg="$1 readback mismatch (want '$3', got '$live')"
    eval "_last=\"\$$_keyvar\""
    if [ "$msg" != "$_last" ]; then
        warn "$msg"
        eval "$_keyvar=\"\$msg\""
    fi
}

# --- global tuning ---
# Re-asserted on every poll: system init rewrites tcp_rmem/tcp_wmem after
# boot_completed, clobbering one-shot values. $1 = buffer ceiling in KiB.
apply_tuning()
{
    cap_kb="$1"
    cap_bytes=$((cap_kb * 1024))
    sysctl_apply net.ipv4.tcp_slow_start_after_idle \
        /proc/sys/net/ipv4/tcp_slow_start_after_idle 0
    sysctl_apply net.ipv4.tcp_notsent_lowat \
        /proc/sys/net/ipv4/tcp_notsent_lowat 131072
    sysctl_apply net.core.rmem_max /proc/sys/net/core/rmem_max "$cap_bytes"
    sysctl_apply net.core.wmem_max /proc/sys/net/core/wmem_max "$cap_bytes"
    sysctl_apply net.ipv4.tcp_rmem /proc/sys/net/ipv4/tcp_rmem \
        "4096 131072 $cap_bytes"
    sysctl_apply net.ipv4.tcp_wmem /proc/sys/net/ipv4/tcp_wmem \
        "4096 16384 $cap_bytes"
}

# --- transport detection ----------------------------------------------------
# route_transport: echoes "wifi", "mobile" or "": decided by the
# interface holding the default route, read from /proc/net/route (v4,
# destination and netmask 00000000) and /proc/net/ipv6_route (v6, ::/0
# lines, device in the last field). Wifi wins when both transports carry
# a default route; a link that is up but unrouted (wlan1 hotspot)
# contributes nothing. Android keeps per-network defaults in private
# tables invisible to these files, so the operstate scan below is the
# usual path on this platform.
route_transport()
{
    _wifi=false
    _mobile=false

    if [ -r /proc/net/route ]; then
        while read _if _dest _gw _fl _r _u _m _mask _rest; do
            [ "$_dest" = "00000000" ] && [ "$_mask" = "00000000" ] || continue
            case "$_if" in
                wlan*)  _wifi=true ;;
                rmnet*) _mobile=true ;;
            esac
        done < /proc/net/route
    fi

    if [ -r /proc/net/ipv6_route ]; then
        while read _dst _plen _src _srclen _gw _m _r _u _f _dev _junk; do
            [ "$_dst" = "00000000000000000000000000000000" ] \
                && [ "$_plen" = "00" ] || continue
            case "$_dev" in
                wlan*)  _wifi=true ;;
                rmnet*) _mobile=true ;;
            esac
        done < /proc/net/ipv6_route
    fi

    if [ "$_wifi" = true ]; then
        echo wifi
    elif [ "$_mobile" = true ]; then
        echo mobile
    else
        operstate_transport
    fi
}

# Link-state scan: the usual path on Android, since per-network default
# routes live in private tables the script cannot read without ip(8).
operstate_transport()
{
    _wifi=false
    _mobile=false
    for _path in /sys/class/net/*; do
        _if=${_path##*/}
        # wlan0 is the station interface; wlan* beyond it are AP/hotspot.
        case "$_if" in
            wlan0|rmnet_data*) ;;
            *) continue ;;
        esac
        [ -r "$_path/operstate" ] || continue
        read _state < "$_path/operstate" 2>/dev/null || continue
        # dormant = interface active but in power-save; count it too.
        [ "$_state" = "up" ] || [ "$_state" = "dormant" ] || continue
        case "$_if" in
            wlan0)          _wifi=true ;;
            rmnet_data*)    _mobile=true ;;
        esac
    done
    if [ "$_wifi" = true ]; then
        echo wifi
    elif [ "$_mobile" = true ]; then
        echo mobile
    fi
}

# --- per-transport default CC loop ---------------------------------------

while true; do
    # Global tuning, skipped entirely when persist.vendor.tcp.tuning=0;
    # manual buffer override: empty/unknown value = 16 MB.
    if [ "$(prop_get persist.vendor.tcp.tuning)" != "0" ]; then
        cap_kb=16384
        buf_kb="$(prop_get persist.vendor.tcp.buf_kb)"
        case "$buf_kb" in
            4096|8192|16384|32768) cap_kb="$buf_kb" ;;
        esac
        apply_tuning "$cap_kb"
    fi

    # Active-transport detection: see route_transport/operstate_transport.
    # A link that is up but unrouted, e.g. a wlan1 hotspot, does not
    # count. Neither wifi nor mobile active -> the boot default stays in
    # charge.
    transport="$(route_transport)"
    auto_cc="bbr"
    mode=""
    case "$transport" in
        wifi)   mode="$(prop_get persist.vendor.tcp.cc_wifi)" ;;
        mobile) mode="$(prop_get persist.vendor.tcp.cc_mobile)" ;;
    esac

    # A manual value the kernel does not have is ignored until the next
    # poll.
    read available < /proc/sys/net/ipv4/tcp_available_congestion_control \
        2>/dev/null || available=""

    target=""
    case "$mode" in
        bbr|westwood|cubic|reno)
            case " $available " in
                *" $mode "*) target="$mode" ;;
            esac
            ;;
        *)
            # auto: bbr on both transports; westwood fallback if the
            # kernel lacks bbr (built-in here, kept for portability).
            case " $available " in
                *" $auto_cc "*) target="$auto_cc" ;;
                *" westwood "*) target="westwood" ;;
            esac
            ;;
    esac

    # Live CC is re-read from the kernel every poll instead of a one-shot
    # cache: an out-of-band change is picked up, and a write the kernel
    # rejects is simply retried on the next iteration.
    read current < /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null \
        || current=""

    if [ -n "$target" ] && [ "$target" != "$current" ]; then
        sysctl_set net.ipv4.tcp_congestion_control \
            /proc/sys/net/ipv4/tcp_congestion_control "$target"
    fi

    # bbr pairs with the kernel's per-netns tcp_ecn_low opt-in (default 0
    # = route-hint-only behaviour); every other CC gets it back to 0.
    # Re-asserted each poll so out-of-band resets of the main netns
    # value are covered; fresh netns keep the kernel default.
    if [ -n "$target" ]; then
        case "$target" in
            bbr) ecn=1 ;;
            *)   ecn=0 ;;
        esac
        sysctl_apply net.ipv4.tcp_ecn_low \
            /proc/sys/net/ipv4/tcp_ecn_low "$ecn"
    fi

    sleep 10
done
