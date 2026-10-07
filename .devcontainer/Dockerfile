FROM mcr.microsoft.com/devcontainers/base:2-trixie

# Claude Code from Anthropic's signed apt repository (stable channel).
# The build fails unless the downloaded signing key matches Anthropic's
# published fingerprint, and apt then verifies every package against it.
ARG CLAUDE_CODE_KEY_FPR=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
      -o /etc/apt/keyrings/claude-code.asc \
 && gpg --show-keys --with-colons /etc/apt/keyrings/claude-code.asc \
      | grep -q "^fpr:::::::::${CLAUDE_CODE_KEY_FPR}:" \
 && echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
      > /etc/apt/sources.list.d/claude-code.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends claude-code \
 && rm -rf /var/lib/apt/lists/*
