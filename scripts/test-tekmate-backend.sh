#!/bin/bash
# TekMate Backend Health Check Script
# Tests the TekMate backend API endpoints

set -e

echo "🏥 TekMate Backend Health Check"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TEKMATE_URL="https://tekmate.airpronwa.com"
HEALTH_ENDPOINT="${TEKMATE_URL}/health"
CHAT_ENDPOINT="${TEKMATE_URL}/api/personality-chat"

# Test 1: Health endpoint
echo "Test 1: Health Endpoint"
echo "------------------------"
echo "URL: ${HEALTH_ENDPOINT}"
echo ""

HTTP_CODE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" "${HEALTH_ENDPOINT}" 2>&1)

if [ $? -eq 0 ] && [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Health endpoint accessible (HTTP ${HTTP_CODE})${NC}"
    echo "Response:"
    cat /tmp/health_response.json | python3 -m json.tool 2>/dev/null || cat /tmp/health_response.json
    echo ""
    
    # Check if response is JSON (not HTML/Cloudflare error)
    if grep -q "<!DOCTYPE" /tmp/health_response.json || grep -q "<html" /tmp/health_response.json; then
        echo -e "${YELLOW}⚠️  Warning: Received HTML response (Cloudflare issue?)${NC}"
        echo "This may indicate Cloudflare is blocking the request"
        HEALTH_OK=false
    else
        HEALTH_OK=true
    fi
else
    echo -e "${RED}✗ Health endpoint failed (HTTP ${HTTP_CODE})${NC}"
    if [ -f /tmp/health_response.json ]; then
        cat /tmp/health_response.json
    fi
    HEALTH_OK=false
fi

echo ""
echo "=================================="
echo ""

# Test 2: Personality chat endpoint
echo "Test 2: Personality Chat Endpoint"
echo "-----------------------------------"
echo "URL: ${CHAT_ENDPOINT}"
echo ""

HTTP_CODE=$(curl -s -o /tmp/chat_response.json -w "%{http_code}" \
    -X POST "${CHAT_ENDPOINT}" \
    -H "Content-Type: application/json" \
    -d '{"message":"test","user":"agent-test"}' 2>&1)

if [ $? -eq 0 ] && [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Chat endpoint accessible (HTTP ${HTTP_CODE})${NC}"
    echo "Response:"
    cat /tmp/chat_response.json | python3 -m json.tool 2>/dev/null || cat /tmp/chat_response.json
    echo ""
    
    # Check if response is JSON
    if grep -q "<!DOCTYPE" /tmp/chat_response.json || grep -q "<html" /tmp/chat_response.json; then
        echo -e "${YELLOW}⚠️  Warning: Received HTML response (Cloudflare issue?)${NC}"
        CHAT_OK=false
    else
        CHAT_OK=true
    fi
else
    echo -e "${RED}✗ Chat endpoint failed (HTTP ${HTTP_CODE})${NC}"
    if [ -f /tmp/chat_response.json ]; then
        cat /tmp/chat_response.json
    fi
    CHAT_OK=false
fi

echo ""
echo "=================================="
echo ""

# Summary
echo "Summary"
echo "-------"

if [ "$HEALTH_OK" = true ]; then
    echo -e "${GREEN}✓ Health endpoint: OK${NC}"
else
    echo -e "${RED}✗ Health endpoint: FAILED${NC}"
fi

if [ "$CHAT_OK" = true ]; then
    echo -e "${GREEN}✓ Chat endpoint: OK${NC}"
else
    echo -e "${RED}✗ Chat endpoint: FAILED${NC}"
fi

echo ""

# Overall status
if [ "$HEALTH_OK" = true ] && [ "$CHAT_OK" = true ]; then
    echo -e "${GREEN}🎉 TekMate backend is operational!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  TekMate backend has issues${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check if domain resolves: nslookup tekmate.airpronwa.com"
    echo "2. Check server status: ssh jolo@192.168.1.117 'systemctl status tekmate'"
    echo "3. Check Cloudflare tunnel: ssh jolo@192.168.1.117 'systemctl status tekmate-tunnel'"
    echo "4. Review server logs: ssh jolo@192.168.1.117 'journalctl -u tekmate -n 50'"
    exit 1
fi
