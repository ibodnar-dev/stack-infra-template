FROM --platform=linux/amd64 python:3.11-slim

WORKDIR /stack/

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

COPY ./app /stack/app/
COPY ./pyproject.toml ./uv.lock /stack/

RUN uv sync --frozen
ENV PATH="/stack/.venv/bin:$PATH"
