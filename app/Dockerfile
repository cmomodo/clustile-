FROM python:3.14-alpine3.24

#the directory we are working with
WORKDIR /app

COPY index.html favicon.ico ./
COPY js/ ./js/
COPY style/ ./style/
COPY meta/ ./meta/

# Expose port 3000
EXPOSE 3000

#run as non-root user
USER 10001

CMD ["python", "-m", "http.server", "3000", "--bind", "0.0.0.0"]
