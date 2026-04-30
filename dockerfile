# ❌ Old base image (will trigger Trivy)
FROM python:3.8-slim

WORKDIR /app

COPY app/ .

# ❌ Running as root (default)
RUN pip install flask

CMD ["python", "app.py"]
