# WAF-Bypass Auditor & Automated Reconnaissance Pipeline

A fully automated bash script designed for penetration testers, bug bounty hunters, and network administrators to identify Web Application Firewall (WAF) misconfigurations and audit exposed backend infrastructure. 

By cross-references passive OSINT with known WAF IP ranges, this tool automatically hunts for Origin IP leaks and executes a throttled infrastructure audit.

---

## ⚠️ Legal Disclaimer
**This tool was created strictly for educational purposes and authorized penetration testing.** Do not use this tool against infrastructure you do not own or do not have explicit, written permission to audit. The author is not responsible for any misuse, damage, or legal consequences caused by the use of this software. Always ensure your testing adheres to local laws and established Rules of Engagement (RoE).

---

## 🚀 Features
* **Passive Discovery:** Aggregates subdomains using Certificate Transparency logs (`crt.sh`) and HackerTarget OSINT APIs.
* **WAF Bypass Engine:** Cross-references resolved IP addresses against known Cloudflare/WAF subnets to automatically identify the true Origin IP of a target network.
* **Infrastructure Auditing:** Executes a comprehensive TCP port scan (`nmap`) against the discovered Origin IP.
* **Directory Enumeration:** Uses throttled directory brute-forcing (`gobuster`) to map hidden administrative interfaces without triggering server-side rate limits or causing Denial of Service.
* **Directory Service Testing:** Dynamically calculates Base DNs to test for Unauthenticated/Anonymous LDAP binds (`ldapsearch`).

---

## 🛠️ Prerequisites
This script requires a standard Linux environment (Kali Linux / Ubuntu / Debian preferred) with the following open-source packages installed:

```bash
sudo apt update
sudo apt install curl nmap ldap-utils gobuster grepcidr jq bind9-dnsutils
```

> [!NOTE]
> You will also need a standard wordlist located at `/usr/share/wordlists/dirb/common.txt`, which is default in Kali Linux.

---

## 💻 Usage
The script is entirely automated and requires only a single argument: the target domain name.

### Installation
Clone the repository and navigate to the directory:

```bash
git clone https://github.com/YourUsername/WAF-Bypass-Auditor.git
cd WAF-Bypass-Auditor
```

### Execution
Make the script executable:

```bash
chmod +x WAF-Bypass-Auditor.sh
```

Run the script:

```bash
./WAF-Bypass-Auditor.sh example.com
```

---

## 📊 Sample Output
Below is an example of the terminal output during a successful WAF bypass and audit execution on an authorized test target.

```plaintext
==================================================================
  AUTOMATED INFRASTRUCTURE AUDIT: example.com 
==================================================================

[*] PHASE 1: Discovery Engine - Hunting for Origin IP Leaks...
[+] Subdomain list compiled. Resolving IPs to identify WAF bypasses...
[!] LEAK FOUND: dev-internal.example.com resolves to non-WAF IP: 203.0.113.42
[✔] Origin IP Candidate Identified: 203.0.113.42

[*] PHASE 2: Active Audit on Origin IP (203.0.113.42)...
Scanning all TCP ports on the Origin Server...
Testing LDAP Directory (Port 389)...
[!] CRITICAL: LDAP Anonymous Bind Success! Data saved to ldap_dump.txt
Testing common web and administrative ports...
Checking http://203.0.113.42:80...
Checking http://203.0.113.42:443...
Checking http://203.0.113.42:8080...

==================================================================
[✔] AUDIT COMPLETE.
Results folder: audit_example.com_2026-04-09_1430
==================================================================
```

---

## 📦 Generated Artifacts
Upon completion, the tool generates a timestamped directory containing the raw audit data:

- **subdomains.txt**: The compiled list of discovered subdomains.
- **nmap_results.txt**: The complete output of the service version scan.
- **ldap_dump.txt**: The extracted directory data (Only generated if anonymous binds are permitted).
- **web_audit_port_[X].txt**: Hidden administrative directories and status codes found by Gobuster.
