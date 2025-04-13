# Purpose: Multi-stage Docker build that compiles the C# application 
# and creates a minimal runtime image for deployment
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /source

# Copy csproj and restore dependencies
COPY src/*.csproj ./
RUN dotnet restore

# Copy the rest of the code and publish
COPY src/ ./
RUN dotnet publish -c Release -o /app

# Build runtime image
FROM mcr.microsoft.com/dotnet/runtime:7.0
WORKDIR /app
COPY --from=build /app .

# Install Python for email alerts
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir requests

# Create config directory
RUN mkdir -p /app/config

# Add tty support for Gotty
ENV TERM xterm

ENTRYPOINT ["dotnet", "YourAppName.dll"]