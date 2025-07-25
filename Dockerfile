# Single-stage Dockerfile for .NET Application with GitHub CI/CD

# .NET SDK stage with CI/CD capabilities
FROM mcr.microsoft.com/dotnet/sdk:9.0
WORKDIR /app

# Install system dependencies first (rarely changes - great for caching)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    unzip \
    git \
    jq \
    openssh-client \
    ca-certificates \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy CI/CD scripts first (changes less frequently than TestApp)
COPY scripts/ci-cd.sh /ci-cd.sh
COPY scripts/deploy.sh /deploy.sh
COPY scripts/startup.sh /startup.sh
RUN chmod +x /ci-cd.sh /deploy.sh /startup.sh

# Copy TestApp project files only (for dependency restoration)
COPY test-examples/TestApp/*.csproj ./fallback/TestApp/
RUN cd fallback/TestApp && dotnet restore

# Copy remaining TestApp source and build (this layer invalidates only on code changes)
COPY test-examples/TestApp/ ./fallback/TestApp/
RUN cd fallback/TestApp && dotnet build -c Release && dotnet publish -c Release -o ../publish
RUN rm -rf fallback/TestApp && mv fallback/publish/* fallback/ && rm -rf fallback/publish

# Environment variables with defaults
ENV ASPNETCORE_ENVIRONMENT=Production

# CI/CD Environment variables (GitHub Deploy Key handled securely via volume mount)
ENV GITHUB_REPO=""
ENV GITHUB_BRANCH=main
ENV PROJECT_PATH=""
ENV POLL_INTERVAL=60
ENV BUILD_SCRIPT=deploy.sh
ENV ENABLE_AUTO_BUILD=true
ENV ENABLE_CI_CD=false

# Expose standard web ports
EXPOSE 8080 443

# Set startup script as entrypoint
ENTRYPOINT ["/startup.sh"]
