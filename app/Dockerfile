FROM python:3.14-alpine3.24

WORKDIR /app

COPY index.html favicon.ico ./
COPY js/ ./js/
COPY style/ ./style/
COPY meta/ ./meta/

EXPOSE 3000

USER 10001

CMD ["python", "-m", "http.server", "3000", "--bind", "0.0.0.0"]
