# ─────────────────────────────────────────────────────────────
# HR Support Chatbot (RAG: FAISS + OpenAI + Streamlit)
# Container image for Google Cloud (Cloud Run / App Engine Flex).
#
# Streamlit UI is the container entry point.
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

# Copy the rest of the application (source, documents/, hr_faiss_index/, etc.)
COPY . .

# GCP provides the listening port via $PORT (defaults to 8080)
ENV PORT=8080
EXPOSE 8080

# Streamlit UI is the entry point.
# NOTE: a prebuilt FAISS index (hr_faiss_index/) must exist in the image.
# Run `python ingest.py` locally and commit hr_faiss_index/ before building,
# or build the index during this step (see the commented RUN line below).
# RUN python ingest.py

# Use shell form so $PORT is expanded at runtime by the container shell.
CMD streamlit run app_with_memory.py \
    --server.port=$PORT \
    --server.address=0.0.0.0 \
    --server.headless=true \
    --server.enableCORS=false \
    --server.enableXsrfProtection=false \
    --browser.gatherUsageStats=false
