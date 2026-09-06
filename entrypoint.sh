#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────────────────────
# Runtime entrypoint for the HR RAG chatbot container.
#   1. Build the FAISS index (hr_faiss_index) from PDFs in
#      ./documents if the index does not already exist. Once built,
#      Streamlit loads it into RAM (via @st.cache_resource).
#   2. Launch the Streamlit UI bound to the port GCP provides.
# ─────────────────────────────────────────────────────────────

VECTOR_DB_PATH="hr_faiss_index"

if [ ! -f "${VECTOR_DB_PATH}/index.faiss" ]; then
  if ls ./documents/*.pdf >/dev/null 2>&1; then
    echo "FAISS index not found - running ingestion from ./documents ..."
    python ingest.py
  else
    echo "WARNING: no FAISS index and no PDFs in ./documents/."
    echo "The app will fail to load the vector store until an index exists."
  fi
else
  echo "FAISS index found at ${VECTOR_DB_PATH} - skipping ingestion."
fi

# GCP (Cloud Run / App Engine) injects the listening port via $PORT.
PORT="${PORT:-8080}"

# Entry app: memory-aware version is the recommended one.
APP_FILE="${STREAMLIT_APP:-app_with_memory.py}"

echo "Starting Streamlit (${APP_FILE}) on port ${PORT}..."
exec streamlit run "${APP_FILE}" \
  --server.port="${PORT}" \
  --server.address=0.0.0.0 \
  --server.headless=true \
  --server.enableCORS=false \
  --server.enableXsrfProtection=false \
  --browser.gatherUsageStats=false
