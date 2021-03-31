# https://github.com/cirruslabs/docker-images-flutter/blob/master/.cirrus.yml
FROM cirrusci/flutter:2.1.0-12.2.pre

RUN yes | sdkmanager \
    "platforms;android-29" \
    "build-tools;28.0.3" \
    "build-tools;29.0.3" \
    "extras;google;m2repository" \
    "extras;android;m2repository" \
    "system-images;android-29;default;x86_64"

RUN yes | sdkmanager --licenses
