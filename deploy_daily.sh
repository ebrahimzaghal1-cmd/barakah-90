#!/bin/bash

echo "🚀 Starting daily build for Barakeh..."

###########################################
# ANDROID
###########################################

echo "📦 Building Android APK..."
flutter build apk --release

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
  echo "📤 Uploading APK to Firebase..."
  firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
    --app 1:584371966532:android:46b12853c4e83bdf252211 \
    --release-notes "Daily Build" \
    --testers "ebrahimzaghal1@gmail.com"
else
  echo "❌ APK file not found! Build failed."
fi

###########################################
# IOS
###########################################

echo "🍎 Building iOS IPA..."
flutter build ipa --release

if [ -f "build/ios/ipa/Runner.ipa" ]; then
  echo "📤 Uploading IPA to Firebase..."
  firebase appdistribution:distribute build/ios/ipa/Runner.ipa \
    --app 1:584371966532:ios:fd57a412e2c8ab28252211 \
    --release-notes "Daily Build" \
    --testers "ebrahimzaghal1@gmail.com"
else
  echo "❌ IPA file not found! Build failed."
fi

echo "✅ Done! Daily builds uploaded successfully."
