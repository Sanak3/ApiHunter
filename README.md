# API Hunter v2.0 - BLOOD Edition

API Hunter is an advanced bash script designed for automated API reconnaissance and vulnerability scanning. Built for bug bounty hunters and penetration testers, it chains multiple tools to map out an application's API attack surface and prioritize high-risk endpoints.

## Focus
The primary goal is to discover hidden and historical API endpoints, extract parameters and IDs for BOLA/IDOR testing, identify exposed documentation (Swagger/OpenAPI/GraphQL), leak secrets, calculate risk scores, and scan for high/critical API vulnerabilities.

## Prerequisites
Ensure the following tools are installed and available in your system's PATH:
- [subfinder](https://github.com/projectdiscovery/subfinder)
- [httpx](https://github.com/projectdiscovery/httpx)
- [katana](https://github.com/projectdiscovery/katana)
- [cariddi](https://github.com/edoardottt/cariddi)
- [nuclei](https://github.com/projectdiscovery/nuclei)
- [gau](https://github.com/lc/gau) *(New in v2)*
- [waybackurls](https://github.com/tomnomnom/waybackurls) *(New in v2)*
- [LinkFinder](https://github.com/GerbenJavado/LinkFinder) *(New in v2)*
- [gowitness](https://github.com/sensepost/gowitness) *(Optional - New in v2)*
- Standard utilities: `curl` and `jq`

## Usage
```bash
chmod +x apihunterv2.sh
./apihunterv2.sh <target-domain.com>
```

## Workflow
1. **Subdomain & Historical Mapping:** Uses Subfinder, GAU, and Waybackurls to find active and "zombie" APIs.

2. **Host Resolution:** Uses Httpx to filter alive web servers.

3. **Documentation Hunting:** Probes for Swagger, OpenAPI, and actively tests GraphQL introspection.

4. **JavaScript Crawling & Analysis:** Uses Katana to extract routes, and LinkFinder to dig hidden endpoints out of downloaded JS files.

5. **Secret Inspection:** Uses Cariddi to passively scan for leaked tokens and secrets.

6. **Parameter Extraction:** Filters extracted URLs to isolate parameters for IDOR/BOLA testing.

7. **Vulnerability** Scanning: Runs Nuclei with strict API, token, and exposure tags (High/Critical severity only).

8. **Methods & Content-Type:** Discovers allowed HTTP methods (via OPTIONS) and response types.

9. **ID & JWT Extraction:** Automatically harvests candidate IDs (UUIDs, accountIds) and JWT tokens directly from responses.

10. **Risk Scoring:** Classifies endpoints based on dangerous verbs (PATCH, DELETE) and sensitive keywords (admin, wallet, upload).

11. **Parameter Grouping:** Maps out the most frequently used parameters across the API for targeted fuzzing.

12. **Reporting:** Generates comprehensive HTML, Markdown, and JSON reports, alongside a manual testing checklist.

## Output
Results are saved in a dedicated directory (`<target>-API/`), providing clean text files, visual screenshots (if gowitness is used), a consolidated risk report, and a structured checklist for further manual exploitation.
