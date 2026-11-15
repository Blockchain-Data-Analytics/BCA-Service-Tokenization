# CI image for the TLA+ model checks (.forgejo/workflows/tla.yml).
# node: the workflow actions (actions/checkout) run on node; the rest is what TLA+ needs.
# The TLC jar is not in the image: it comes from git LFS (ext/tla2tools.jar).
#
# Built per architecture and combined into one multi-arch tag: see ci-image.sh.
FROM node:22-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git git-lfs make default-jre-headless \
 && git lfs install --system \
 && rm -rf /var/lib/apt/lists/*
