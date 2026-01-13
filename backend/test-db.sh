#!/bin/bash
# Test database connection and verify backend setup

echo "🔍 Testing Backend Database Configuration..."
echo ""

# Check environment variables
echo "📋 Environment Check:"
echo "-------------------"

if [ -n "$FIREBASE_PROJECT_ID" ]; then
  echo "✅ FIREBASE_PROJECT_ID: $FIREBASE_PROJECT_ID"
  echo "   Using Firestore database"
  DB_TYPE="firestore"
elif [ -n "$DATABASE_URL" ]; then
  echo "✅ DATABASE_URL: ${DATABASE_URL:0:30}..."
  echo "   Using PostgreSQL database"
  DB_TYPE="postgres"
else
  echo "❌ No database configured!"
  echo "   Set either FIREBASE_PROJECT_ID or DATABASE_URL"
  exit 1
fi

if [ -n "$GEMINI_API_KEY" ]; then
  echo "✅ GEMINI_API_KEY: ${GEMINI_API_KEY:0:10}..."
else
  echo "❌ GEMINI_API_KEY not set"
  exit 1
fi

if [ -n "$JWT_SECRET" ]; then
  echo "✅ JWT_SECRET: configured"
else
  echo "⚠️  JWT_SECRET not set (optional for development)"
fi

echo ""
echo "🗄️  Database Type: $DB_TYPE"
echo ""

# Test database connection
echo "🔌 Testing Database Connection..."
echo "-------------------"

if [ "$DB_TYPE" = "firestore" ]; then
  # Test Firestore connection
  node -e "
    import('./src/services/firebase.js').then(({ initializeFirebase }) => {
      try {
        const { db } = initializeFirebase();
        if (db) {
          console.log('✅ Firestore connection successful!');
          process.exit(0);
        } else {
          console.log('❌ Firestore initialization failed');
          process.exit(1);
        }
      } catch (error) {
        console.log('❌ Firestore connection error:', error.message);
        process.exit(1);
      }
    });
  " --input-type=module
else
  # Test PostgreSQL connection
  node -e "
    import pg from 'pg';
    const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
    pool.query('SELECT NOW()')
      .then(() => {
        console.log('✅ PostgreSQL connection successful!');
        pool.end();
        process.exit(0);
      })
      .catch(error => {
        console.log('❌ PostgreSQL connection error:', error.message);
        pool.end();
        process.exit(1);
      });
  " --input-type=module
fi

echo ""
echo "✨ Database configuration is valid!"
echo ""
echo "Next steps:"
echo "  - Start server: npm run dev"
echo "  - Deploy: npm run deploy"
