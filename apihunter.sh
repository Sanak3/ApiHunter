#!/bin/bash

RED='\033[1;31m'
DARK_RED='\033[0;31m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}[!] CORRECT USAGE: ./apihunter.sh <target-domain.com>${NC}"
    exit 1
fi

TARGET=$(echo "$1" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

clear
echo -e "${RED}"
cat << "EOF"
 █████╗  ██████╗  ██╗    ██╗  ██╗ ██╗   ██╗ ███╗   ██╗ ████████╗ ███████╗ ██████╗
██╔══██╗ ██╔══██╗ ██║    ██║  ██║ ██║   ██║ ████╗  ██║ ╚══██╔══╝ ██╔════╝ ██╔══██╗
███████║ ██████╔╝ ██║    ███████║ ██║   ██║ ██╔██╗ ██║    ██║    █████╗   ██████╔╝
██╔══██║ ██╔═══╝  ██║    ██╔══██║ ██║   ██║ ██║╚██╗██║    ██║    ██╔══╝   ██╔══██╗
██║  ██║ ██║      ██║    ██║  ██║ ╚██████╔╝ ██║ ╚████║    ██║    ███████╗ ██║  ██║
╚═╝  ╚═╝ ╚═╝      ╚═╝    ╚═╝  ╚═╝  ╚═════╝  ╚═╝  ╚═══╝    ╚═╝    ╚══════╝ ╚═╝  ╚═╝
EOF
echo -e "                            v1.7-BLOOD Edition by Sanak3${NC}\n"

echo -e "${RED}[*] STARTING API HUNT ON TARGET: $TARGET${NC}\n"

mkdir -p "$TARGET-API"
cd "$TARGET-API" || exit

echo -e "${DARK_RED}[*] 1 - Mapping Subdomains (Subfinder)...${NC}"
echo "$TARGET" > subs.txt
subfinder -d $TARGET -all -silent | sort -u >> subs.txt
sort -u subs.txt -o subs.txt
grep -iE "api|dev|staging|graphql|rest|v1|v2|v3" subs.txt > subs_api_priority.txt

echo -e "${DARK_RED}[*] 2 - Resolving Hosts and Searching for Documentation (Httpx)...${NC}"
httpx -l subs.txt -silent -rl 50 > alive.txt

echo -e "${DARK_RED}[*] 3 - Hunting for Hidden Swagger and OpenAPI...${NC}"
httpx -l alive.txt -path /api,/api/v1,/api/v2,/api/v3,/graphql,/swagger-ui.html,/swagger.json,/openapi.json,/api-docs,/v2/api-docs -status-code -mc 200 -silent > api_docs_found.txt

echo -e "${DARK_RED}[*] 4 - Katana: Reading JavaScript and Extracting Routes...${NC}"
katana -list alive.txt -silent -jc -hl -d 3 -ct 2 > katana_urls.txt

echo -e "${DARK_RED}[*] 5 - Cariddi: Passive Inspection of Secrets and Endpoints...${NC}"
if command -v cariddi &> /dev/null; then
    cat katana_urls.txt | cariddi -s -e -err -info -ot cariddi_output > /dev/null 2>&1
else
    echo -e "${RED}[!] Cariddi not found on the system. Step skipped.${NC}"
fi

echo -e "${DARK_RED}[*] 6 - Separating Parameters for BOLA/IDOR Testing...${NC}"
grep "=" katana_urls.txt | grep -vEi "\.(jpg|jpeg|png|gif|css|woff|svg|ico)$" | sort -u > api_parameters.txt

echo -e "${DARK_RED}[*] 7 - Sniper: Nuclei (API Focus)...${NC}"
nuclei -l alive.txt -tags api,swagger,graphql,tokens,keys,exposure -severity critical,high -rl 50 -c 10 -silent > nuclei_api_results.txt

echo -e "\n${RED}HUNT COMPLETED FOR: $TARGET${NC}\n"

if [ -s nuclei_api_results.txt ]; then
    echo -e "${RED}[!] NUCLEI: Found HIGH/CRITICAL vulnerabilities (see nuclei_api_results.txt)${NC}"
else
    echo -e "${DARK_RED}[-] Nuclei: No critical flaws detected in nuclei_api_results.txt${NC}"
fi

if [ -s api_docs_found.txt ]; then
    echo -e "${RED}[!] DOCS: Exposed documentation found! (see api_docs_found.txt)${NC}"
else
    echo -e "${DARK_RED}[-] Docs: No standard documentation leaked in api_docs_found.txt${NC}"
fi

if [ -f cariddi_output.secrets.txt ] && [ -s cariddi_output.secrets.txt ]; then
    echo -e "${RED}[!] CARIDDI: Leaked secrets/tokens detected! (see cariddi_output.secrets.txt)${NC}"
else
    echo -e "${DARK_RED}[-] Cariddi: No obvious secrets exposed in cariddi_output.secrets.txt${NC}"
fi

if [ -s api_parameters.txt ]; then
    PARAM_COUNT=$(wc -l < api_parameters.txt)
    echo -e "${RED}[!] ENDPOINTS: $PARAM_COUNT parameters extracted for IDOR/BOLA testing. (see api_parameters.txt)${NC}"
else
    echo -e "${DARK_RED}[-] API Parameters: None found in api_parameters.txt${NC}"
fi
echo -e "\n"