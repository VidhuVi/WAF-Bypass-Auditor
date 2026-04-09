#!/bin/bash

# ==============================================================================

# SMART SAFE AUDIT TOOL (v3.0)

# Purpose: Accurate origin discovery + low-impact auditing

# ==============================================================================

if [ "$#" -ne 1 ]; then
echo -e "\nUsage: ./audit.sh [DOMAIN]"
exit 1
fi

DOMAIN=$1
DATE=$(date +"%Y-%m-%d_%H%M")
OUT_DIR="audit_${DOMAIN}_${DATE}"
mkdir -p "$OUT_DIR"

echo -e "\n[+] Starting SMART audit for: $DOMAIN\n"

# ------------------------------------------------------------------------------

# STEP 1: Passive Subdomain Enumeration

# ------------------------------------------------------------------------------

echo "[*] Collecting subdomains (passive)..."

curl -s "https://api.hackertarget.com/hostsearch/?q=$DOMAIN" 
| cut -d',' -f1 > "$OUT_DIR/subdomains.txt"

curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" 
| jq -r '.[].name_value' 2>/dev/null 
| sed 's/\*\.//g' >> "$OUT_DIR/subdomains.txt"

sort -u "$OUT_DIR/subdomains.txt" -o "$OUT_DIR/subdomains.txt"

echo "[+] Total subdomains: $(wc -l < "$OUT_DIR/subdomains.txt")"

# ------------------------------------------------------------------------------

# STEP 2: Resolve ALL IPs (multi-IP aware)

# ------------------------------------------------------------------------------

echo "[*] Resolving IPs..."

> "$OUT_DIR/resolved_ips.txt"

while read sub; do
IPS=$(dig +short "$sub" | grep -Eo '([0-9]{1,3}.){3}[0-9]{1,3}')
for ip in $IPS; do
echo "$sub -> $ip" >> "$OUT_DIR/resolved_ips.txt"
done
done < "$OUT_DIR/subdomains.txt"

sort -u "$OUT_DIR/resolved_ips.txt" -o "$OUT_DIR/resolved_ips.txt"

echo "[+] Unique IP mappings saved."

# ------------------------------------------------------------------------------

# STEP 3: Candidate Filtering (basic CDN/hosting noise removal)

# ------------------------------------------------------------------------------

echo "[*] Filtering candidate IPs..."

> "$OUT_DIR/candidate_ips.txt"

while read line; do
IP=$(echo "$line" | awk '{print $3}')

```
HOSTNAME=$(host "$IP" 2>/dev/null | awk '{print $5}')

# Skip obvious CDN / shared hosting patterns
if echo "$HOSTNAME" | grep -qiE "cloudflare|akamai|fastly|webhostbox|cpanel"; then
    continue
fi

echo "$IP" >> "$OUT_DIR/candidate_ips.txt"
```

done < "$OUT_DIR/resolved_ips.txt"

sort -u "$OUT_DIR/candidate_ips.txt" -o "$OUT_DIR/candidate_ips.txt"

echo "[+] Candidate IPs:"
cat "$OUT_DIR/candidate_ips.txt"

# ------------------------------------------------------------------------------

# STEP 4: Origin Validation (CRITICAL FIX)

# ------------------------------------------------------------------------------

echo -e "\n[*] Validating origin servers..."

> "$OUT_DIR/validated_origins.txt"

while read ip; do

```
echo "[*] Testing $ip..."

RESPONSE=$(curl -s --max-time 5 -H "Host: $DOMAIN" http://$ip)

if echo "$RESPONSE" | grep -qi "$DOMAIN"; then
    echo "[!] VALID ORIGIN FOUND: $ip"
    echo "$ip" >> "$OUT_DIR/validated_origins.txt"
fi

sleep 1  # rate limiting
```

done < "$OUT_DIR/candidate_ips.txt"

# ------------------------------------------------------------------------------

# STEP 5: SAFE NMAP (Stage 1)

# ------------------------------------------------------------------------------

if [ -s "$OUT_DIR/validated_origins.txt" ]; then

```
echo -e "\n[*] Running SAFE scan (top 1000 ports)..."

while read ip; do
    nmap --top-ports 1000 -T2 -sV --max-retries 2 --host-timeout 2m \
        "$ip" -oN "$OUT_DIR/nmap_stage1_$ip.txt"
    sleep 2
done < "$OUT_DIR/validated_origins.txt"
```

# ------------------------------------------------------------------------------

# STEP 6: OPTIONAL DEEP SCAN (controlled)

# ------------------------------------------------------------------------------

```
echo -e "\n[*] Do you want to run a FULL port scan? (y/N)"
read choice

if [[ "$choice" == "y" ]]; then
    echo "[!] Running controlled full scan (slow mode)..."

    while read ip; do
        nmap -p- -T2 --min-rate 50 --max-retries 2 \
            "$ip" -oN "$OUT_DIR/nmap_full_$ip.txt"
        sleep 5
    done < "$OUT_DIR/validated_origins.txt"
else
    echo "[*] Skipping full scan."
fi
```

else
echo "[!] No valid origin IPs found. Skipping active scanning."
fi

# ------------------------------------------------------------------------------

# COMPLETE

# ------------------------------------------------------------------------------

echo -e "\n[✔] Audit complete."
echo "Results saved in: $OUT_DIR"
