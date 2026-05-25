#!/bin/bash
# ============================================
# 🔄 Sync Chatwoot Production DB → Local
# Usage: ./scripts/sync_production_db.sh
# ============================================

set -e

# === Configuration ===
SERVER="root@209.38.232.136"
REMOTE_DB_USER="chatwoot"
REMOTE_DB_NAME="chatwoot_production"
REMOTE_DUMP_PATH="/tmp/chatwoot_prod.dump"

LOCAL_DB_USER="macbookpro"
LOCAL_DB_NAME="chatwoot_dev"
LOCAL_DUMP_PATH="/tmp/chatwoot_prod.dump"

echo "🚀 Starting production → local DB sync..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 1: Dump on server
echo ""
echo "📦 [1/4] Dumping production DB on server..."
ssh $SERVER "su - chatwoot -c 'PGPASSWORD=Fxgg8tRsPJChhLx pg_dump -Fc -h localhost -U $REMOTE_DB_USER $REMOTE_DB_NAME -f $REMOTE_DUMP_PATH'"
echo "   ✅ Dump created on server"

# Step 2: Download dump
echo ""
echo "📥 [2/4] Downloading dump to local machine..."
scp $SERVER:$REMOTE_DUMP_PATH $LOCAL_DUMP_PATH
DUMP_SIZE=$(du -sh $LOCAL_DUMP_PATH | cut -f1)
echo "   ✅ Downloaded ($DUMP_SIZE)"

# Step 3: Drop & recreate local DB
echo ""
echo "🗑️  [3/4] Resetting local database..."
psql -U $LOCAL_DB_USER -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$LOCAL_DB_NAME' AND pid <> pg_backend_pid();" 2>/dev/null || true
dropdb --if-exists --force -U $LOCAL_DB_USER $LOCAL_DB_NAME 2>/dev/null || true
createdb -U $LOCAL_DB_USER $LOCAL_DB_NAME
echo "   ✅ Local DB reset"

# Step 4: Restore
echo ""
echo "📂 [4/4] Restoring production data locally..."
pg_restore -U $LOCAL_DB_USER -d $LOCAL_DB_NAME --no-owner --no-privileges $LOCAL_DUMP_PATH 2>/dev/null || true
echo "   ✅ Restore complete"

# Cleanup
echo ""
echo "🧹 Cleaning up temp files..."
rm -f $LOCAL_DUMP_PATH
ssh $SERVER "rm -f $REMOTE_DUMP_PATH"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Done! Production data is now on your local machine."
echo "   Run: bundle exec rails s"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
