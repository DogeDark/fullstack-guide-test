# The name specific in your `Cargo.toml`
ARG APPNAME=fullstack-guide-test

# The out_dir setting in your `Dioxus.toml` (defaults to `dist`)
ARG OUTDIR=dist

# The port your server is running on
ARG PORT=8080

# Install binstall, chef, and dx.
FROM rust:1 AS chef
RUN curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
RUN cargo binstall cargo-chef -y
RUN cargo binstall dioxus-cli -y
RUN rustup target add wasm32-unknown-unknown
WORKDIR /app

# Prepare dependency file
FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json


# Build the dependencies and app
FROM chef AS builder

# Build dependencies
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json --features server
RUN cargo chef cook --release --recipe-path recipe.json --features web --target wasm32-unknown-unknown

# Build app
COPY . .
RUN dx build --release --platform fullstack

# Move built files to final slim runtime.
FROM debian:bookworm-slim AS runtime

# Copy Args
ARG PORT
ARG OUTDIR
ARG APPNAME

# Copy build files
COPY --from=builder /app/$OUTDIR /usr/local/bin/$OUTDIR

# Move the executable so that it is a sibling of the outdir.
RUN mv /usr/local/bin/$OUTDIR/$APPNAME /usr/local/bin/server

WORKDIR /usr/local/bin

EXPOSE $PORT
ENTRYPOINT [ "/usr/local/bin/server" ]