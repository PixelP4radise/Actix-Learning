# --- Base de compilação com cargo-chef (permite cache eficiente das dependências Rust) ---
FROM lukemathwalker/cargo-chef:latest-rust-1.88 AS chef
WORKDIR /app

# Instala dependências de sistema necessárias para compilar bibliotecas nativas
# - musl-tools: permite compilar para binário estático
# - lld/clang: linker e compilador necessários
# - pkg-config, libssl-dev: suporte para bibliotecas como OpenSSL
# Adiciona o target MUSL para gerar binário 100% estático
RUN apt update && apt install -y musl-tools lld clang pkg-config libssl-dev \
    && rustup target add x86_64-unknown-linux-musl


# --- Etapa de planeamento (gera a receita com todas as dependências Rust) ---
FROM chef AS planner
COPY . .
# Gera o ficheiro recipe.json com a lista de dependências do projeto
RUN cargo chef prepare --recipe-path recipe.json


# --- Etapa de compilação (construção da aplicação Rust) ---
FROM chef AS builder
# Copia a receita gerada e compila só as dependências para maximizar cache
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json

# Copia o código da aplicação e compila o binário final
COPY . .
# Usa SQLX offline para evitar chamadas à base de dados no build
ENV SQLX_OFFLINE=true
RUN cargo build --release --target x86_64-unknown-linux-musl --bin zero2prod


# --- Etapa de runtime (imagem mínima para correr o binário) ---
FROM alpine:latest AS runtime
WORKDIR /app

# Instala certificados de autoridade (necessários para HTTPS)
RUN apk add --no-cache ca-certificates

# Copia o binário estático compilado e a pasta de configuração
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/zero2prod zero2prod
COPY configuration configuration

# Define ambiente de produção
ENV APP_ENVIRONMENT=production

# Ponto de entrada: arranca a aplicação
ENTRYPOINT ["./zero2prod"]