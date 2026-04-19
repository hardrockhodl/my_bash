#!/bin/bash

blue='\033[0;34m'
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
cyan='\033[0;36m'
magenta='\033[0;35m'
default='\033[0m'

hex_to_cidr() {
    local hex="${1#0x}"
    local cidr=0
    local i
    local char

    for ((i = 0; i < ${#hex}; i++)); do
        char="${hex:i:1}"
        case "$char" in
            f|F) ((cidr += 4)) ;;
            e|E) ((cidr += 3)) ;;
            c|C) ((cidr += 2)) ;;
            8)   ((cidr += 1)) ;;
            0)   ((cidr += 0)) ;;
            *)
                echo "?"
                return 1
                ;;
        esac
    done

    echo "$cidr"
}

class_color() {
    local ip="$1"

    if [[ $ip =~ ^10\. ]]; then
        echo "$blue"
    elif [[ $ip =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        echo "$green"
    elif [[ $ip =~ ^192\.168\. ]]; then
        echo "$yellow"
    else
        echo "$default"
    fi
}

class_name() {
    local ip="$1"

    if [[ $ip =~ ^10\. ]]; then
        echo "A-class"
    elif [[ $ip =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        echo "B-class"
    elif [[ $ip =~ ^192\.168\. ]]; then
        echo "C-class"
    else
        echo "Other"
    fi
}

get_interface_status() {
    local interface="$1"

    if ifconfig "$interface" | grep -q "status: active"; then
        echo "active"
    elif ifconfig "$interface" | grep -q "status: inactive"; then
        echo "inactive"
    else
        echo "unknown"
    fi
}

get_interface_media() {
    local interface="$1"

    ifconfig "$interface" | awk -F': ' '/media: / {print $2; exit}'
}

get_ipv4_info() {
    local interface="$1"

    ifconfig "$interface" | awk '/inet / {print $2, $4}'
}

get_ipv6_info() {
    local interface="$1"

    ifconfig "$interface" | awk '/inet6 / && $2 !~ /^fe80::/ {print $2}'
}

get_default_gateway() {
    route -n get default 2>/dev/null | awk '/gateway: / {print $2; exit}'
}

get_default_interface() {
    route -n get default 2>/dev/null | awk '/interface: / {print $2; exit}'
}

get_public_ip() {
    local services=(
        "https://ifconfig.me/ip"
        "https://api.ipify.org"
        "https://icanhazip.com"
    )

    local url
    local ip

    for url in "${services[@]}"; do
        ip=$(curl -4 -s --max-time 3 "$url" | tr -d '[:space:]')
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done

    return 1
}

echo
echo "Interfaces:"

for interface in $(ifconfig -l); do
    [[ $interface == lo0* ]] && continue

    status=$(get_interface_status "$interface")
    media=$(get_interface_media "$interface")

    if [[ $status == "active" ]]; then
        status_color="$green"
    elif [[ $status == "inactive" ]]; then
        status_color="$red"
    else
        status_color="$default"
    fi

    echo -e "${cyan}${interface}${default}"
    echo -e "  Status: ${status_color}${status}${default}"

    if [[ -n $media ]]; then
        echo "  Media:  $media"
    fi

    while read -r ip_address netmask_hex; do
        [[ -z "$ip_address" || -z "$netmask_hex" ]] && continue

        cidr=$(hex_to_cidr "$netmask_hex") || cidr="?"
        ip_color=$(class_color "$ip_address")
        ip_class=$(class_name "$ip_address")

        echo -e "  IPv4:   ${ip_color}${ip_address}/${cidr}${default} (${ip_class})"
    done < <(get_ipv4_info "$interface")

    while read -r ipv6_address; do
        [[ -z "$ipv6_address" ]] && continue
        echo -e "  IPv6:   ${magenta}${ipv6_address}${default}"
    done < <(get_ipv6_info "$interface")

    echo
done

default_gateway=$(get_default_gateway)
default_interface=$(get_default_interface)
public_ip=$(get_public_ip)

echo "Routing:"
if [[ -n $default_gateway ]]; then
    echo -e "  Default gateway:   ${cyan}${default_gateway}${default}"
else
    echo "  Default gateway:   not found"
fi

if [[ -n $default_interface ]]; then
    echo -e "  Internet interface: ${cyan}${default_interface}${default}"
else
    echo "  Internet interface: not found"
fi

echo
if [[ -n $public_ip ]]; then
    echo -e "Public IP: ${red}${public_ip}${default}"
else
    echo -e "Public IP: ${red}Could not determine public IP${default}"
fi