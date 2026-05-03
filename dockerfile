# ////////////////////////// FIXED VERSION \\\\\\\\\\\\\\\\\\\\\\\\\\\\

# ✅ Use a newer, minimal, patched image
FROM python:3.12-slim
RUN apt-get update && apt-get upgrade -y && apt-get clean

# ✅ Prevent Python from writing .pyc files & buffering logs
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# ✅ Create non-root user
RUN addgroup --system appgroup && adduser --system --group appuser

WORKDIR /app

# ✅ Install dependencies separately (better caching)
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# ✅ Copy app code
COPY app/ .

# ✅ Drop privileges
USER appuser

# ✅ Explicit port (optional, good practice)
EXPOSE 5000

CMD ["python", "app.py"]
