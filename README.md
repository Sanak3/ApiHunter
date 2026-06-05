# API Hunter

API Hunter is a bash script designed for automated API reconnaissance and vulnerability scanning. Built for bug bounty hunters and penetration testers, it chains multiple tools to map out an application's API attack surface.

## Focus
The primary goal is to discover hidden API endpoints, extract parameters for BOLA/IDOR testing, identify exposed documentation (Swagger/OpenAPI), leak secrets, and scan for high/critical API vulnerabilities.

## Prerequisites
Ensure the following tools are installed and available in your system's PATH:
- [subfinder](https://github.com/projectdiscovery/subfinder)
- [httpx](https://github.com/projectdiscovery/httpx)
- [katana](https://github.com/projectdiscovery/katana)
- [cariddi](https://github.com/edoardottt/cariddi)
- [nuclei](https://github.com/projectdiscovery/nuclei)

## Usage
```bash
chmod +x apihunter.sh
./apihunter.sh <target-domain.com>
```

## Workflow
1. **Subdomain Mapping:** Uses Subfinder, prioritizing API-related keywords.
2. **Host Resolution:** Uses Httpx to filter alive web servers.
3. **Documentation Hunting:** Probes for common Swagger and OpenAPI paths.
4. **JavaScript Crawling:** Uses Katana to extract routes and endpoints.
5. **Secret Inspection:** Uses Cariddi to passively scan for leaked tokens and secrets.
6. **Parameter Extraction:** Filters extracted URLs to isolate parameters for IDOR/BOLA testing.
7. **Vulnerability Scanning:** Runs Nuclei with strict API, token, and exposure tags (High/Critical severity only).

## Output
Results are saved in a dedicated directory (`<target>-API/`), providing clean text files for further manual exploitation.
