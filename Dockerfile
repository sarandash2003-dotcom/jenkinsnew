# Use Python 3.12
FROM python:3.12-slim

# Prevent Python from creating .pyc files
ENV PYTHONDONTWRITEBYTECODE=1

# Send Python output directly to container logs
ENV PYTHONUNBUFFERED=1

# Application directory
WORKDIR /app

# Install system packages required by Pillow / image processing
RUN apt-get update && apt-get install -y \
    libjpeg62-turbo \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency file first for Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY main.py .
COPY crypto_engine.py .
COPY ocr_engine.py .
COPY audit_ledger.py .

# Copy application assets
COPY static ./static
COPY sample_certificates ./sample_certificates

# Create required directories
RUN mkdir -p /app/static /app/sample_certificates

# Application port
EXPOSE 8080

# Start FastAPI application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```
