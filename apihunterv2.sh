#!/bin/bash

# ==============================================
#  API Hunter v2.0 - BLOOD Edition 
# ==============================================

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
echo -e "                            v2.0-BLOOD Edition by Sanak3${NC}\n"

echo -e "${RED}[*] STARTING API HUNT ON TARGET: $TARGET${NC}\n"

mkdir -p "$TARGET-API"
cd "$TARGET-API" || exit

# ─── 1. Subdomínios (Subfinder + GAU + Wayback) ───
echo -e "${DARK_RED}[*] 1 - Mapping Subdomains & Historical URLs...${NC}"
echo "$TARGET" > subs.txt
if command -v subfinder &> /dev/null; then
    subfinder -d $TARGET -all -silent | sort -u >> subs.txt
else
    echo -e "${RED}[!] Subfinder not found, skipping.${NC}"
fi
# GAU
if command -v gau &> /dev/null; then
    gau "$TARGET" --subs --o gau_urls.txt 2>/dev/null || true
    if [ -f gau_urls.txt ]; then
        grep -Eo '(http|https)://[^/"]+' gau_urls.txt | sed -e 's|^[^/]*//||' -e 's|/.*$||' | sort -u >> subs.txt
    fi
fi
# Waybackurls
if command -v waybackurls &> /dev/null; then
    waybackurls "$TARGET" > wayback_urls.txt 2>/dev/null || true
    if [ -f wayback_urls.txt ]; then
        grep -Eo '(http|https)://[^/"]+' wayback_urls.txt | sed -e 's|^[^/]*//||' -e 's|/.*$||' | sort -u >> subs.txt
    fi
fi
sort -u subs.txt -o subs.txt
grep -iE "api|dev|staging|graphql|rest|v1|v2|v3" subs.txt > subs_api_priority.txt

# ─── 2. Hosts vivos (Httpx) ──────────────────
echo -e "${DARK_RED}[*] 2 - Resolving Hosts (Httpx)...${NC}"
if command -v httpx &> /dev/null; then
    httpx -l subs.txt -silent -rl 50 > alive.txt
else
    cp subs.txt alive.txt
fi

# ─── 3. Documentação (Swagger/OpenAPI/GraphQL ampliada) ───
echo -e "${DARK_RED}[*] 3 - Hunting Documentation (Swagger, OpenAPI, GraphQL)...${NC}"
> api_docs_found.txt
if command -v httpx &> /dev/null; then
    httpx -l alive.txt \
        -path /api,/api/v1,/api/v2,/api/v3,/graphql,/graphiql,/graphql/playground,/swagger-ui.html,/swagger.json,/swagger.yaml,/swagger.yml,/openapi.json,/openapi.yaml,/openapi.yml,/api-docs,/v2/api-docs,/v3/api-docs,/docs,/redoc,/redoc.html \
        -status-code -mc 200 -silent >> api_docs_found.txt
    # GraphQL POST test
    while read -r host; do
        curl -s -o /dev/null -w "%{http_code}" -X POST "$host/graphql" -H "Content-Type: application/json" -d '{"query":"{ __typename }"}' 2>/dev/null | grep -q 200 && echo "$host/graphql [POST introspection OK]" >> api_docs_found.txt
    done < alive.txt
fi

# ─── 4. JS e extração de rotas (Katana + LinkFinder) ───
echo -e "${DARK_RED}[*] 4 - Extracting JS files and hidden endpoints...${NC}"
> all_endpoints.txt
# Katana
if command -v katana &> /dev/null; then
    katana -list alive.txt -silent -jc -hl -d 3 -ct 2 > katana_urls.txt
    cat katana_urls.txt >> all_endpoints.txt
fi
# GAU + Wayback URLs (se já existirem)
cat gau_urls.txt wayback_urls.txt 2>/dev/null >> all_endpoints.txt
# Baixar JS e rodar LinkFinder
if command -v LinkFinder &> /dev/null; then
    mkdir -p js_downloads
    grep -iE '\.js(\?|$)' all_endpoints.txt | sort -u > js_files.txt
    while read -r jsurl; do
        fname=$(echo "$jsurl" | md5sum | awk '{print $1}').js
        curl -sL --max-time 10 "$jsurl" -o "js_downloads/$fname" 2>/dev/null || continue
        python3 $(which LinkFinder) -i "js_downloads/$fname" -o cli >> js_endpoints.txt 2>/dev/null
    done < js_files.txt
    cat js_endpoints.txt >> all_endpoints.txt
fi
sort -u all_endpoints.txt -o all_endpoints.txt

# ─── 5. Cariddi em todos os endpoints ─────
echo -e "${DARK_RED}[*] 5 - Cariddi: Passive Secrets & Endpoints Inspection...${NC}"
if command -v cariddi &> /dev/null; then
    cat all_endpoints.txt | cariddi -s -e -err -info -ot cariddi_output > /dev/null 2>&1
else
    echo -e "${RED}[!] Cariddi not found. Step skipped.${NC}"
fi

# ─── 6. Parâmetros para BOLA/IDOR ──────────
echo -e "${DARK_RED}[*] 6 - Separating Parameters for BOLA/IDOR Testing...${NC}"
grep "=" all_endpoints.txt | grep -vEi "\.(jpg|jpeg|png|gif|css|woff|svg|ico)$" | sort -u > api_parameters.txt

# ─── 7. Nuclei (foco API) ──────────────────
echo -e "${DARK_RED}[*] 7 - Sniper: Nuclei (API Focus)...${NC}"
if command -v nuclei &> /dev/null; then
    nuclei -l alive.txt -tags api,swagger,graphql,tokens,keys,exposure -severity critical,high -rl 50 -c 10 -silent > nuclei_api_results.txt
else
    echo -e "${RED}[!] Nuclei not found. Step skipped.${NC}"
    touch nuclei_api_results.txt
fi

# ─── 8. Métodos HTTP e Content-Type ────────
echo -e "${DARK_RED}[*] 8 - Discovering HTTP Methods & Content-Types...${NC}"
> http_methods.txt
> content_types.txt
if [ -s all_endpoints.txt ]; then
    head -n 30 all_endpoints.txt | while read -r url; do
        # OPTIONS
        methods=$(curl -s -I -X OPTIONS --max-time 4 "$url" 2>/dev/null | grep -i "^Allow:" | sed 's/Allow: //I')
        [ -n "$methods" ] && echo "$url  ->  $methods" >> http_methods.txt
        # Content-Type
        ctype=$(curl -s -I --max-time 4 "$url" 2>/dev/null | grep -i "^Content-Type:" | sed 's/Content-Type: //I' | tr -d '\r')
        [ -n "$ctype" ] && echo "$url  ->  $ctype" >> content_types.txt
    done
fi

# ─── 9. Extração de IDs e JWT ─────────────
echo -e "${DARK_RED}[*] 9 - Extracting IDs & JWT Tokens from responses...${NC}"
> id_candidates.txt
> jwt_tokens.txt
if [ -s all_endpoints.txt ]; then
    head -n 50 all_endpoints.txt | while read -r url; do
        resp=$(curl -s --max-time 5 "$url" 2>/dev/null)
        echo "$resp" | grep -Po '"(id|userId|accountId|invoiceId|projectId|orderId|orgId)"\s*:\s*"[^"]+"' >> id_candidates.txt
        echo "$resp" | grep -Po 'eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+' >> jwt_tokens.txt
    done
fi

# ─── 10. Classificação e score de risco ────
echo -e "${DARK_RED}[*] 10 - Classifying endpoints & risk scoring...${NC}"
> classified_risk.txt
if [ -s all_endpoints.txt ]; then
    grep -iE "(admin|role|permission|wallet|balance|transfer|invoice|payment|upload|PATCH|PUT|DELETE|MERGE)" all_endpoints.txt | while read -r ep; do
        score=0
        [[ "$ep" =~ (PATCH|PUT|DELETE|MERGE) ]] && score=$((score+3))
        [[ "$ep" =~ [aA]dmin ]] && score=$((score+5))
        [[ "$ep" =~ [uU]pload ]] && score=$((score+4))
        [[ "$ep" =~ [wW]allet|[bB]alance|[tT]ransfer|[iI]nvoice|[pP]ayment ]] && score=$((score+5))
        echo "$score -> $ep" >> classified_risk.txt
    done
    sort -nr classified_risk.txt -o classified_risk.txt
fi

# ─── 11. Agrupamento de parâmetros ──────────
echo -e "${DARK_RED}[*] 11 - Grouping common parameters...${NC}"
> param_groups.txt
if [ -s api_parameters.txt ]; then
    grep -Po '[?&]\K[^=&\s]+' api_parameters.txt | sort | uniq -c | sort -nr | while read -r count param; do
        endpoints=$(grep -l "[?&]${param}=" api_parameters.txt 2>/dev/null | head -3 | tr '\n' ' ')
        echo "$param ($count occurrences): $endpoints" >> param_groups.txt
    done
fi

# ─── 12. Screenshots (opcional) ────────────
echo -e "${DARK_RED}[*] 12 - Taking screenshots (Gowitness)...${NC}"
if command -v gowitness &> /dev/null; then
    gowitness scan file -f alive.txt --no-http --screenshot-path screenshots/ --write-db 2>/dev/null
    echo -e "${RED}[!] Screenshots saved in screenshots/${NC}"
else
    echo -e "${DARK_RED}[-] Gowitness not installed. Step skipped.${NC}"
fi

# ─── 13. Relatórios (HTML, MD, JSON, Checklist) ────
echo -e "${DARK_RED}[*] 13 - Generating reports (HTML, Markdown, JSON, Checklist)...${NC}"

# JSON
cat <<EOF > report.json
{
  "target": "$TARGET",
  "stats": {
    "subdomains": $(wc -l < subs.txt),
    "alive_hosts": $(wc -l < alive.txt),
    "endpoints": $(wc -l < all_endpoints.txt),
    "parameters": $(wc -l < api_parameters.txt),
    "docs_found": $(wc -l < api_docs_found.txt),
    "nuclei_high_crit": $(wc -l < nuclei_api_results.txt),
    "cariddi_secrets": $([ -f cariddi_output.secrets.txt ] && wc -l < cariddi_output.secrets.txt || echo 0),
    "id_candidates": $(wc -l < id_candidates.txt),
    "jwt_tokens": $(wc -l < jwt_tokens.txt)
  }
}
EOF

# Markdown
cat <<EOF > report.md
# API Hunter Report – $TARGET

## Resumo
- Subdomínios: $(wc -l < subs.txt)
- Hosts vivos: $(wc -l < alive.txt)
- Endpoints únicos: $(wc -l < all_endpoints.txt)
- Parâmetros: $(wc -l < api_parameters.txt)
- Documentação exposta: $(wc -l < api_docs_found.txt)
- Nuclei críticos: $(wc -l < nuclei_api_results.txt)
- Secrets (Cariddi): $([ -f cariddi_output.secrets.txt ] && wc -l < cariddi_output.secrets.txt || echo 0)
- IDs candidatos: $(wc -l < id_candidates.txt)
- JWTs: $(wc -l < jwt_tokens.txt)

## Endpoints de alto risco (top 10)
\`\`\`
$(head -10 classified_risk.txt)
\`\`\`

## Checklist final
\`\`\`
$(cat checklist.txt)
\`\`\`
EOF

# HTML simples
cat <<EOF > report.html
<html><head><title>API Hunter - $TARGET</title>
<style>body{background:#111;color:#eee;font-family:Arial;padding:20px} h1{color:red} pre{background:#222;padding:10px;}</style></head>
<body><h1>API Hunter Report - $TARGET</h1>
<ul>
<li>Subdomínios: $(wc -l < subs.txt)</li>
<li>Hosts vivos: $(wc -l < alive.txt)</li>
<li>Endpoints: $(wc -l < all_endpoints.txt)</li>
<li>Parâmetros: $(wc -l < api_parameters.txt)</li>
<li>Docs expostas: $(wc -l < api_docs_found.txt)</li>
<li>Nuclei (crítico/alto): $(wc -l < nuclei_api_results.txt)</li>
<li>Segredos: $([ -f cariddi_output.secrets.txt ] && wc -l < cariddi_output.secrets.txt || echo 0)</li>
<li>IDs candidatos: $(wc -l < id_candidates.txt)</li>
<li>JWTs: $(wc -l < jwt_tokens.txt)</li>
</ul>
<h2>Top riscos</h2><pre>$(head -20 classified_risk.txt)</pre>
</body></html>
EOF

# Checklist
cat <<EOF > checklist.txt
[ ] Swagger/OpenAPI exposto
[ ] GraphQL introspection
[ ] JWT tokens em respostas
[ ] IDOR candidates identificados
[ ] Métodos PATCH/PUT/DELETE
[ ] Endpoints de upload
[ ] Funções administrativas
[ ] Secrets vazados (Cariddi)
[ ] Vulnerabilidades Nuclei críticas
[ ] Screenshots capturados
EOF

# ─── Resumo final (idêntico ao V1) ─────────
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

if [ -s id_candidates.txt ]; then
    echo -e "${RED}[!] IDs: Possible identifiers found (see id_candidates.txt)${NC}"
fi

if [ -s jwt_tokens.txt ]; then
    echo -e "${RED}[!] JWT: Tokens discovered (see jwt_tokens.txt)${NC}"
fi

if [ -s classified_risk.txt ]; then
    echo -e "${RED}[!] RISK: High-risk endpoints classified (see classified_risk.txt)${NC}"
fi

if [ -s param_groups.txt ]; then
    echo -e "${RED}[!] PARAM GROUPING: Common parameters identified (see param_groups.txt)${NC}"
fi

echo -e "\n${DARK_RED}[*] Reports generated: report.html, report.md, report.json${NC}"
echo -e "${DARK_RED}[*] Checklist saved: checklist.txt${NC}"
echo -e "\n"
