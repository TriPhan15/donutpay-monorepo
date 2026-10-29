# Client image of the benchmark: one long-lived Python process per experiment runs inside the throwaway network.
FROM python:3.12-slim
RUN pip install --no-cache-dir pymongo==4.10.1 redis==5.2.1 "psycopg[binary]==3.2.3" requests==2.32.3
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /bench
