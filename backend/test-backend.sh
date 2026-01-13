#!/bin/bash

# Test script for NutritionAI backend
# Usage: ./test-backend.sh

BACKEND_URL="https://nutrition-ai-backend-1051629517898.us-central1.run.app"

echo "🧪 Testing NutritionAI Backend"
echo "================================"
echo ""

# Test 1: Health check
echo "1️⃣ Testing health endpoint..."
HEALTH=$(curl -s "${BACKEND_URL}/health")
echo "Response: $HEALTH"
if [[ $HEALTH == *"ok"* ]]; then
  echo "✅ Health check passed"
else
  echo "❌ Health check failed"
  exit 1
fi
echo ""

# Test 2: Register new user
echo "2️⃣ Testing user registration..."
TIMESTAMP=$(date +%s)
EMAIL="test-${TIMESTAMP}@example.com"
PASSWORD="testpass123"
NAME="Test User ${TIMESTAMP}"

REGISTER_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${EMAIL}\",
    \"password\": \"${PASSWORD}\",
    \"name\": \"${NAME}\"
  }")

echo "Response: $REGISTER_RESPONSE"
TOKEN=$(echo $REGISTER_RESPONSE | jq -r '.token')
USER_ID=$(echo $REGISTER_RESPONSE | jq -r '.user.id')

if [[ $TOKEN != "null" && $TOKEN != "" ]]; then
  echo "✅ Registration successful"
  echo "   User ID: $USER_ID"
  echo "   Token: ${TOKEN:0:50}..."
else
  echo "❌ Registration failed"
  exit 1
fi
echo ""

# Test 3: Login
echo "3️⃣ Testing user login..."
LOGIN_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${EMAIL}\",
    \"password\": \"${PASSWORD}\"
  }")

echo "Response: $LOGIN_RESPONSE"
NEW_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')

if [[ $NEW_TOKEN != "null" && $NEW_TOKEN != "" ]]; then
  echo "✅ Login successful"
  TOKEN=$NEW_TOKEN
else
  echo "❌ Login failed"
  exit 1
fi
echo ""

# Test 4: Get user stats
echo "4️⃣ Testing user stats endpoint..."
STATS_RESPONSE=$(curl -s -X GET "${BACKEND_URL}/api/user/stats" \
  -H "Authorization: Bearer ${TOKEN}")

echo "Response: $STATS_RESPONSE"
if [[ $STATS_RESPONSE == *"error"* ]]; then
  echo "⚠️  Stats endpoint returned error (expected for new user with no meals)"
else
  echo "✅ Stats endpoint accessible"
fi
echo ""

# Test 5: Analyze endpoint (without image)
echo "5️⃣ Testing analyze endpoint availability..."
ANALYZE_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/api/analyze" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{}')

echo "Response: $ANALYZE_RESPONSE"
if [[ $ANALYZE_RESPONSE == *"error"* ]]; then
  echo "✅ Analyze endpoint accessible (expected error without image)"
else
  echo "⚠️  Unexpected response from analyze endpoint"
fi
echo ""

echo "================================"
echo "✅ Backend tests completed!"
echo ""
echo "Test credentials:"
echo "  Email: ${EMAIL}"
echo "  Password: ${PASSWORD}"
echo "  Token: ${TOKEN}"
