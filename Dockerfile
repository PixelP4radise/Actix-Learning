FROM rust:1.88 AS cargo-build

WORKDIR /app

RUN apt update && apt install lld clang -y

COPY . .

ENV SQLX_OFFLINE=true

RUN cargo build --release

#ENTRYPOINT ["./target/release/zero2prod"]

RUN cargo install --path .

FROM ubuntu:latest

COPY --from=cargo-build /usr/local/cargo/bin/zero2prod /usr/local/bin/zero2prod

CMD ["zero2prod"]