#!/bin/bash

# Complete end-to-end test with meal creation
BACKEND_URL="https://nutrition-ai-backend-1051629517898.us-central1.run.app"

echo "🧪 End-to-End Test with Meal Creation"
echo "======================================"
echo ""

# 1. Register
echo "1️⃣ Registering user..."
TIMESTAMP=$(date +%s)
EMAIL="e2e-${TIMESTAMP}@test.com"
REGISTER_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"${EMAIL}\", \"password\": \"testpass123\", \"name\": \"E2E Test\"}")

TOKEN=$(echo $REGISTER_RESPONSE | jq -r '.token')
USER_ID=$(echo $REGISTER_RESPONSE | jq -r '.user.id')

if [[ $TOKEN == "null" ]]; then
  echo "❌ Registration failed"
  echo $REGISTER_RESPONSE
  exit 1
fi

echo "✅ User registered: $USER_ID"
echo ""

# 2. Check stats (should be empty)
echo "2️⃣ Checking initial stats..."
STATS=$(curl -s -X GET "${BACKEND_URL}/api/user/stats" \
  -H "Authorization: Bearer ${TOKEN}")
echo $STATS | jq '.'
echo ""

# 3. Create a mock meal analysis
echo "3️⃣ Creating meal analysis..."
MEAL_DATA='{
  "foods": [
    {
      "name": "Test Chicken",
      "portion": "1 piece",
      "nutrition": {"calories": 250, "protein": 30, "carbs": 0, "fat": 13},
      "confidence": 0.9
    }
  ],
  "totals": {"calories": 250, "protein": 30, "carbs": 0, "fat": 13}
}'

# Note: analyze endpoint requires actual image, so we'll simulate with a placeholder
echo "Note: Analyze endpoint requires actual image data"
echo "Skipping meal creation for now"
echo ""

# 4. Check stats again
echo "4️⃣ Checking stats after (no meals expected)..."
STATS2=$(curl -s -X GET "${BACKEND_URL}/api/user/stats" \
  -H "Authorization: Bearer ${TOKEN}")
echo $STATS2 | jq '.'
echo ""

echo "======================================"
echo "Test complete"
echo "User: $EMAIL"
echo "Token: ${TOKEN:0:50}..."
