FROM nixpkgs/nix

ENV PATH=/root/.nix-profile/bin:/usr/bin:/bin
ENV PUID=1000
ENV PGID=1000

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && nix-channel --update

# Base tools for downstream sidecars: bash, shadow for useradd/groupadd.
RUN nix-env -iA nixpkgs.bash nixpkgs.shadow nixpkgs.nix nixpkgs.su-exec

RUN mkdir -p /usr/local/bin/healthcheck
COPY healthcheck/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create non-root user to be inherited by sidecars
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
