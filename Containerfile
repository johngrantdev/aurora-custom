# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM quay.io/fedora-ostree-desktops/kinoite:44

ARG FLAVOR=laptop


### [IM]MUTABLE /opt
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    FLAVOR=${FLAVOR} /ctx/build.sh
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint

### SIGNING POLICY
## Bake cosign public key so bootc upgrade can verify signatures against it.
## The policy and registries discovery config live in
## build_files/files/common/etc/containers/ and are copied in by build.sh.
COPY cosign.pub /etc/pki/containers/aurora-custom.pub
