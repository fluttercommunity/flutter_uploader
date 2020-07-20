# https://github.com/cirruslabs/docker-images-flutter/blob/master/.cirrus.yml
FROM cirrusci/flutter:1.17.5

RUN yes | sdkmanager \
    "platforms;android-29" \
    "build-tools;29.0.3" \
    "extras;google;m2repository" \
    "extras;android;m2repository" \
    "system-images;android-29;default;x86_64"

RUN yes | sdkmanager --licenses
