# ─────────────────────────────────────────────────────────────
# HR Support Chatbot (RAG: FAISS + OpenAI + Streamlit)
# Container image for Google Cloud (Cloud Run / App Engine Flex).
#
# Place this file in the ROOT of the RAG-UI repo.
# ─────────────────────────────────────────────────────────────
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# System deps for faiss / pypdf builds
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (better layer caching)
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy the rest of the application (source, documents/, etc.)
COPY . .

# Runtime entrypoint (builds FAISS index if missing, then starts Streamlit)
RUN chmod +x /app/entrypoint.sh

# GCP provides the listening port via $PORT (defaults to 8080)
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]
