# Build the manager binary
FROM golang:1.21.9@sha256:ff6cfbd291c157a5b67e121b050e80a646a88b55de5c489a5c07acb9528a1feb as builder
WORKDIR /workspace

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# Cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN  --mount=type=cache,target=/root/.local/share/golang \
     --mount=type=cache,target=/go/pkg/mod \
     go mod download -x

# Copy the sources
COPY ./ ./

# Ensure script has execution permissions
RUN chmod +x hack/custom/change-version.sh

# Build the manager binary
ARG ARCH
ARG LDFLAGS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.local/share/golang \
    CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} \
    go build -a -trimpath -ldflags "${LDFLAGS} -extldflags '-static'" \
    -o manager .

# Final image stage
FROM alpine:3.18

# Install go, git, and gcloud in the final image
RUN apk add --no-cache \
    go \
    git \
    python3 \
    py3-pip \
    curl \
    && pip3 install --upgrade pip \
    && echo "https://packages.cloud.google.com/apt" >> /etc/apk/repositories \
    && curl -O https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    && apk add --no-cache --allow-untrusted google-cloud-sdk

WORKDIR /

# Copy the manager binary from the builder stage
COPY --from=builder /workspace/manager .

# Use a non-root user for security
USER nobody

# Set the entrypoint to the manager binary
ENTRYPOINT ["/manager"]
