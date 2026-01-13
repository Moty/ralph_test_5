#!/bin/bash
BACKEND="https://nutrition-ai-backend-1051629517898.us-central1.run.app"

# Register fresh user
echo "1. Registering new user..."
REG=$(curl -s -X POST "$BACKEND/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"statstest-$(date +%s)@test.com\",\"password\":\"testpass123\",\"name\":\"Stats Test\"}")
TOKEN=$(echo "$REG" | jq -r '.token')
echo "Token: ${TOKEN:0:40}..."

# Test stats
echo ""
echo "2. Testing stats endpoint..."
STATS=$(curl -s -X GET "$BACKEND/api/user/stats" \
  -H "Authorization: Bearer $TOKEN")
echo "Stats response:"
echo "$STATS" | jq '.'
