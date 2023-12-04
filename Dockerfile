FROM dart:3.1 AS dartimage

COPY app/ /app/

# Compiling the Dart application that manages this action
RUN cd /app \
    && dart pub get \
    && dart compile exe /app/bin/main.dart -o /app/dart_package_analyzer

# Using the latest version of the Dart SDK
FROM cirrusci/flutter:stable

# Copying only the executable
COPY --from=dartimage /app/dart_package_analyzer /dart_package_analyzer

ENV PATH /root/.pub-cache/bin:/flutter/bin:$PATH

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*

# Installing and activating pana
RUN dart pub global activate pana

ENTRYPOINT ["/dart_package_analyzer"]