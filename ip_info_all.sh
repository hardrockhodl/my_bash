#!/bin/bash

blue='\033[0;34m'
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
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

print_ip() {
    local interface="$1"
    local ip_address="$2"
    local cidr="$3"

    echo -n "$interface - "

    if [[ $ip_address =~ ^10\. ]]; then
        echo -e "${blue}${ip_address}/${cidr}${default} (A-class)"
    elif [[ $ip_address =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        echo -e "${green}${ip_address}/${cidr}${default} (B-class)"
    elif [[ $ip_address =~ ^192\.168\. ]]; then
        echo -e "${yellow}${ip_address}/${cidr}${default} (C-class)"
    else
        echo "${ip_address}/${cidr}"
    fi
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
echo "Private IPs:"

for interface in $(ifconfig -l); do
    [[ $interface == lo0* ]] && continue

    while read -r _ ip_address _ netmask_hex _; do
        [[ -z "$ip_address" || -z "$netmask_hex" ]] && continue

        cidr=$(hex_to_cidr "$netmask_hex") || cidr="?"

        print_ip "$interface" "$ip_address" "$cidr"
    done < <(ifconfig "$interface" | grep 'inet ')
done

public_ip=$(get_public_ip)

echo
if [[ -n "$public_ip" ]]; then
    echo -e "Public IP: ${red}${public_ip}${default}"
else
    echo -e "Public IP: ${red}Could not determine public IP${default}"
fi