FROM nixpkgs/nix
# 🤖 NIX-SIDECAR: Manage the shared Nix store and profile
# Minimal base - just Nix and essential tools
RUN mkdir -p /etc/nix
COPY nix.conf /etc/nix/nix.conf

ENV PATH=/root/.nix-profile/bin:/usr/bin:/bin

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && nix-channel --update

# Install bash, shadow (for user/group management), and su-exec
RUN nix-env -iA nixpkgs.bash nixpkgs.shadow nixpkgs.su-exec

RUN mkdir -p /usr/local/bin/healthcheck
COPY healthcheck/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create non-root user
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
