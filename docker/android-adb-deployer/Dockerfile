FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    openjdk-11-jdk \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# Install Android SDK Command Line Tools
RUN mkdir -p /opt/android-sdk/cmdline-tools && \
    cd /opt/android-sdk/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
    unzip commandlinetools-linux-9477386_latest.zip && \
    mv cmdline-tools latest && \
    rm commandlinetools-linux-9477386_latest.zip

# Set Android SDK environment variables
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# Accept Android SDK licenses and install platform-tools (includes adb)
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "build-tools;33.0.0"

# Create deployment script
COPY deploy-apk.sh /usr/local/bin/deploy-apk.sh
RUN chmod +x /usr/local/bin/deploy-apk.sh

# Create working directory for APK files
WORKDIR /apk

# Default command
CMD ["/usr/local/bin/deploy-apk.sh"]
