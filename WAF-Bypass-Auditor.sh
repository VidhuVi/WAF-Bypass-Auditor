#!/bin/bash

# ==============================================================================
# WAF-Bypass Auditor & Automated Reconnaissance Pipeline
# Description: Automates passive OSINT, WAF-bypass discovery, and active auditing.
# Author: Vidhu
# ==============================================================================

if [ "$#" -ne 1 ]; then
    echo -e "\nUsage: ./WAF-Bypass-Auditor.sh [DOMAIN]"
    echo -e "Example: ./WAF-Bypass-Auditor.sh example.com\n"
    exit 1
fi

DOMAIN=$1
DATE=$(date +"%Y-%m-%d_%H%M")
OUT_DIR="audit_${DOMAIN}_${DATE}"
mkdir -p "$OUT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}  AUTOMATED INFRASTRUCTURE AUDIT: $DOMAIN ${NC}"
echo -e "${BLUE}==================================================================${NC}\n"

# ------------------------------------------------------------------------------
# STEP 1: DEFINE THE WAF RANGES (Known Cloudflare Blocks)
# ------------------------------------------------------------------------------
CF_RANGES="173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 172.64.0.0/13 131.0.72.0/22"

# ------------------------------------------------------------------------------
# STEP 2: DISCOVERY ENGINE (Hunting for Origin IP)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[*] PHASE 1: Discovery Engine - Hunting for Origin IP Leaks...${NC}"

curl -s "https://api.hackertarget.com/hostsearch/?q=$DOMAIN" | cut -d',' -f1 > "$OUT_DIR/subs.tmp"
curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' >> "$OUT_DIR/subs.tmp" 2>/dev/null
sort -u "$OUT_DIR/subs.tmp" > "$OUT_DIR/subdomains.txt"
rm "$OUT_DIR/subs.tmp"

echo -e "${GREEN}[+] Subdomain list compiled. Resolving IPs to identify WAF bypasses...${NC}"

ORIGIN_IP=""
for sub in $(cat "$OUT_DIR/subdomains.txt"); do
    IP=$(host "$sub" | grep "has address" | awk '{print $4}' | head -n 1)
    if [ ! -z "$IP" ]; then
        IS_CF=false
        for range in $CF_RANGES; do
            if grepcidr "$range" <(echo "$IP") &>/dev/null; then
                IS_CF=true
                break
            fi
        done
        
        if [ "$IS_CF" = false ]; then
            echo -e "${RED}[!] LEAK FOUND: $sub resolves to non-WAF IP: $IP${NC}"
            ORIGIN_IP=$IP
            break # Select the first viable Origin IP candidate
        fi
    fi
done

if [ -z "$ORIGIN_IP" ]; then
    echo -e "${RED}[X] Error: Could not automatically find an Origin IP outside of WAF ranges.${NC}"
    exit 1
fi

echo -e "${GREEN}[✔] Origin IP Candidate Identified: $ORIGIN_IP${NC}\n"

# ------------------------------------------------------------------------------
# STEP 3: INFRASTRUCTURE AUDIT
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[*] PHASE 2: Active Audit on Origin IP ($ORIGIN_IP)...${NC}"

# 1. Full Nmap Scan
echo "Scanning all TCP ports on the Origin Server..."
nmap -sV -T3 -p- "$ORIGIN_IP" -oN "$OUT_DIR/nmap_results.txt"

# 2. LDAP Audit (Anonymous Bind)
echo "Testing LDAP Directory (Port 389)..."
# Dynamically calculate the Base DN from the target domain (e.g., example.com -> dc=example,dc=com)
BASE_DN=$(echo "$DOMAIN" | tr '.' '\n' | sed 's/^/dc=/' | paste -sd, -)
ldapsearch -x -H ldap://$ORIGIN_IP -b "$BASE_DN" > "$OUT_DIR/ldap_dump.txt" 2>/dev/null
if [ -s "$OUT_DIR/ldap_dump.txt" ]; then
    echo -e "${RED}[!] CRITICAL: LDAP Anonymous Bind Success! Data saved to ldap_dump.txt${NC}"
fi

# 3. Web Directory Audit (Gobuster)
echo "Testing common web and administrative ports..."
for PORT in 80 443 8080 8443; do
    echo "Checking http://$ORIGIN_IP:$PORT..."
    gobuster dir -u "http://$ORIGIN_IP:$PORT" -w /usr/share/wordlists/dirb/common.txt -t 5 --delay 2s --quiet > "$OUT_DIR/web_audit_port_$PORT.txt" 2>/dev/null
done

echo -e "\n${BLUE}==================================================================${NC}"
echo -e "${GREEN}[✔] AUDIT COMPLETE.${NC}"
echo -e "${BLUE}Results folder: $OUT_DIR${NC}"
echo -e "${BLUE}==================================================================${NC}"