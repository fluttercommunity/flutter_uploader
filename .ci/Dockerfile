# https://github.com/cirruslabs/docker-images-flutter/blob/master/.cirrus.yml
FROM cirrusci/flutter:1.17.5

RUN yes | sdkmanager \
    "platforms;android-28" \
    "build-tools;28.0.3" \
    "extras;google;m2repository" \
    "extras;android;m2repository" \
    "system-images;android-28;default;x86_64"

RUN yes | sdkmanager --licenses
