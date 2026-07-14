FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install the compiler used to bootstrap the project environment.
RUN python -m pip install --upgrade pip \
    && python -m pip install \
        "jaseci==2.3.28" \
        "jac-scale[deploy]==0.2.31" \
        "byllm==0.6.19"

COPY jac.toml ./

# Install project dependencies at image-build time. Retry in the same layer so
# Bun retains downloads if Jac's five-minute npm timeout is reached.
RUN set -eu; \
    attempt=1; \
    while [ "$attempt" -le 3 ]; do \
        echo "Jac dependency installation attempt ${attempt}/3"; \
        if MONGODB_URI="mongodb://localhost:27017/graphlearn" \
           JWT_SECRET="build-only-placeholder" \
           GEMINI_API_KEY="build-only-placeholder" \
           jac install; then \
            exit 0; \
        fi; \
        attempt=$((attempt + 1)); \
        echo "Dependency installation failed; retrying with the existing cache..."; \
    done; \
    exit 1

COPY . .

RUN MONGODB_URI="mongodb://localhost:27017/graphlearn" \
    JWT_SECRET="build-only-placeholder" \
    GEMINI_API_KEY="build-only-placeholder" \
    jac build main.jac

EXPOSE 10000

# Crucially, run the Jac executable from the project environment created above.
CMD ["sh", "-c", "exec jac start main.jac --port ${PORT:-10000}"]