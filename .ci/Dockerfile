FROM cirrusci/flutter:stable

RUN yes | sdkmanager \
    "platforms;android-28" \
    "build-tools;28.0.3" \
    "extras;google;m2repository" \
    "extras;android;m2repository"

RUN yes | sdkmanager --licenses
