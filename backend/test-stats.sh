#!/bin/bash
REGISTER=$(curl -s -X POST "https://nutrition-ai-backend-1051629517898.us-central1.run.app/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"fresh-$(date +%s)@test.com\", \"password\": \"testpass123\", \"name\": \"Fresh Test\"}")

TOKEN=$(echo "$REGISTER" | jq -r '.token')

echo "Testing stats endpoint..."
curl -s -X GET "https://nutrition-ai-backend-1051629517898.us-central1.run.app/api/user/stats" \
  -H "Authorization: Bearer $TOKEN" | jq '.'
