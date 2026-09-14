#!/usr/bin/env nu

# Scan the LAN for reachable hosts (ARP sweep), resolve their host names
# through the router's DNS, and flag the target host (default: lanchamarcou).
#
# Usage:
#   sudo nu scan-lan.nu                 # look for "lanchamarcou"
#   sudo nu scan-lan.nu otherhost       # look for "otherhost"
#   sudo nu scan-lan.nu --router 192.168.2.1

def main [
    target: string = "lanchamarcou"   # host name to detect
    --router: string = "192.168.2.1"  # router / DNS server IP
] {
    # Locate a dig binary from nixpkgs (returned as its full store path,
    # so we can call it directly without re-running nix for every lookup)
    let dig = (nix shell nixpkgs#bind -c sh -c 'command -v dig'
        | complete | get stdout | str trim)

    # ARP sweep of the local network (requires root)
    print $"Scanning local network via ARP..."
    let raw = (sudo nix shell nixpkgs#arp-scan -c sh -c 'arp-scan --localnet --plain'
        | complete)

    if $raw.exit_code != 0 {
        print -e $"arp-scan failed: ($raw.stderr | str trim)"
        exit 1
    }

    let hosts = ($raw.stdout
        | lines
        | where {|l| $l =~ '^\d+\.\d+\.\d+\.\d+\s'}
        | split column -r '\s+' ip mac)

    if ($hosts | is-empty) {
        print "No hosts found."
        return
    }

    # Resolve each discovered IP through the router's DNS
    let with_names = ($hosts | each {|h|
        let name = (run-external $dig +short +time=1 +tries=1 @($router) -- -x $h.ip
            | complete | get stdout
            | lines | get 0? | default "" | str trim | str replace -r '\.$' '')
        {
            ip: $h.ip
            mac: $h.mac
            name: (if $name == "" { "--" } else { $name })
        }
    })

    let sorted = ($with_names | sort-by ip)
    print ($sorted | table)

    let hits = ($sorted | where {|h| ($h.name | str lowercase | str contains ($target | str lowercase))})
    if ($hits | is-empty) {
        print $"==> No host matching '($target)' found."
    } else {
        for h in $hits {
            print $"==> FOUND: ($h.ip) — host name: ($h.name)"
        }
    }
}
