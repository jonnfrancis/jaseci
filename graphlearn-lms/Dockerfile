FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install the same Jaseci toolchain used by the local project.
RUN python -m pip install --upgrade pip \
    && python -m pip install "jaseci==2.3.28"

# Copy the dependency manifest first for better layer caching.
COPY jac.toml ./

# jac.toml references required runtime variables. These build-only placeholders
# let Jac install dependencies without embedding real secrets in the image.
RUN MONGODB_URI="mongodb://localhost:27017/graphlearn" \
    JWT_SECRET="build-only-placeholder" \
    GEMINI_API_KEY="build-only-placeholder" \
    jac install

COPY . .

EXPOSE 10000

CMD ["sh", "-c", "jac start main.jac --port ${PORT:-10000}"]