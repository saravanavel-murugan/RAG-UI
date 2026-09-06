# Deploying the HR RAG Chatbot (RAG-UI) to Google Cloud

This is a Streamlit RAG chatbot (FAISS vector search + OpenAI `gpt-4o-mini`).
The FAISS index (`hr_faiss_index`) is built from the PDFs in `documents/` and
held **in memory (RAM)** at runtime by Streamlit's `@st.cache_resource`.

## What to copy into the RAG-UI repo root

Copy every file from this `RAG-UI-deploy/` folder into the root of the
`RAG-UI` repository (next to `app.py`, `ingest.py`, etc.):

| File               | Purpose                                                          |
|--------------------|------------------------------------------------------------------|
| `Dockerfile`       | Builds the container image                                       |
| `entrypoint.sh`    | Runs ingestion if the index is missing, then starts Streamlit    |
| `app.yaml`         | App Engine Flexible config (custom runtime = Dockerfile)         |
| `requirements.txt` | **Replaces** the repo's original (adds missing packages)         |
| `.dockerignore`    | Keeps the image lean                                             |
| `.gcloudignore`    | Excludes files from `gcloud` uploads                             |

> The repo's original `requirements.txt` is missing `streamlit`,
> `python-dotenv`, `pypdf`, and `langchain-classic` (imported by the code).
> The version here includes them, otherwise the container build/run fails.

---

## IMPORTANT security notes before deploying

1. **A real `.env` is committed to the repo.** If it contains a live
   `OPENAI_API_KEY`, treat that key as compromised: rotate it in the OpenAI
   dashboard, remove `.env` from git history, and add `.env` to `.gitignore`.
2. Do **not** put your real key in `app.yaml`. Use Secret Manager (below).
3. Make sure the `documents/` folder with the HR PDFs is present in the repo,
   otherwise ingestion has nothing to index and the app cannot start.

---

## Prerequisites

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```
Plus a valid OpenAI API key and the `documents/*.pdf` files in the repo.

---

## Option A: Cloud Run (recommended for Streamlit)

```bash
# 1. Enable services
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com

# 2. Store the API key as a secret
echo -n "sk-your-openai-key" | gcloud secrets create openai-api-key --data-file=-

# 3. Build + deploy from the repo root
gcloud run deploy hr-rag-chatbot \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 1 \
  --timeout 600 \
  --min-instances 1 \
  --set-secrets OPENAI_API_KEY=openai-api-key:latest
```

To run the non-memory app instead of the memory-aware one:
```bash
  --set-env-vars STREAMLIT_APP=app.py
```

Cloud Run injects `$PORT` (8080); the container already binds to it. gcloud
prints the public HTTPS URL when the deploy completes.

---

## Option B: App Engine Flexible

```bash
# First time only
gcloud services enable appengine.googleapis.com
gcloud app create --region=us-central

# Set your key in app.yaml (or wire up Secret Manager), then:
gcloud app deploy app.yaml
gcloud app browse
```

---

## Local test before deploying

```bash
docker build -t hr-rag-chatbot .
docker run -p 8080:8080 -e OPENAI_API_KEY=sk-your-openai-key hr-rag-chatbot
# open http://localhost:8080
```

---

## Tuning notes

- **Memory**: 2 GB suits a handful of HR PDFs. Raise it for larger corpora.
- **Cold start**: First boot runs `ingest.py` (OpenAI embeddings), ~10-60s.
  `--min-instances 1` avoids repeating that on every request.
- **Persisting the index**: This rebuilds the index on each fresh instance. To
  skip rebuilds, persist `hr_faiss_index/` to a GCS bucket and download it at
  startup instead of running ingestion - ask if you want that variant.
