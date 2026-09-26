# TranslateCat

A face-to-face translation prototype for iPhone Duo, built for Bitrig Hacks iPhone Duo Edition.

**Interactive presentation:** https://translatecat.vasanth.cloud

The web presentation uses a scroll-driven 3D phone to demonstrate the concept. The native iOS app source is included in this repository; the browser presentation uses simulated conversations.

## Features

- Inner-display conversation transcript and large outer-display captions for the person opposite you.
- Hands-free utterance detection and Gemini-powered transcription, language detection, and translation between two selected languages.
- 16 language options, language swapping, and typed input for either speaker.
- Fold-aware SwiftUI layouts using `ArrangementView`, division-aware geometry, and an outer-display scene accessory.
- Local conversation history, personal notes, and transcript sharing.
- Pro summaries with a title, key points, and follow-ups, including a fold-aware recap screen.
- RevenueCat Test Store integration for Pro purchases, restoration, and entitlement updates.
- On-device travel assistance with Foundation Models, subject to model availability.

## Run the presentation

No build step is required. From the repository root:

```sh
python3 -m http.server 8080 --directory slides
```

Open http://localhost:8080. Scroll to unfold the phone; use the navigation dots to visit the supporting slides.

## Run the iOS app

1. Install Xcode 27.1 beta with the iPhone Duo SDK/runtime, or open the project in a compatible Bitrig environment.
2. Create `Secrets.xcconfig` in the repository root:

   ```xcconfig
   GEMINI_API_KEY = your_gemini_api_key
   ```

3. Open `TranslateCat.xcodeproj`, select the TranslateCat scheme and a supported iPhone Duo simulator/device, and build. Physical-device builds also require your own signing configuration.
4. Grant microphone and camera permissions. On-device features require supported models to be installed and available.

`Config.xcconfig` optionally includes `Secrets.xcconfig`, which is excluded from Git. A missing key produces an actionable error for online translation. The RevenueCat key in `SubscriptionModel.swift` is a public client SDK Test Store key; production requires your own RevenueCat/App Store configuration. The Pro entitlement is `translatecat_pro`.

`project.yml` is also provided for XcodeGen users. The checked-in Xcode project can be used directly.

## Data and prototype limitations

Conversations and notes are saved locally. The hands-free path sends speech audio to Gemini; Gemini summaries send transcript text. Recorded audio is not retained by the app. Apple Translation and Foundation Models availability varies by device and runtime. This prototype requires internet access for its Gemini features.

A key embedded through build configuration is still extractable from the compiled app. Use a server-side authenticated proxy before distributing a production app, and rotate demo credentials after the event. Never commit `Secrets.xcconfig` or API tokens.

## Deploy the presentation

Install Wrangler v4 and authenticate with a Cloudflare account that manages the domain, then run:

```sh
wrangler deploy
```

`wrangler.jsonc` publishes only `slides/` and attaches `translatecat.vasanth.cloud`. To deploy a fork, update the account, Worker name, and custom domain in that configuration.

## Repository layout

- `TranslateCat/`: SwiftUI app, translation, speech capture, summaries, and subscriptions.
- `TranslateCat.xcodeproj/`: Xcode project.
- `slides/`: light-theme presentation, Three.js demo, and image assets.
- `project.yml`: XcodeGen configuration.
- `wrangler.jsonc`: static-site deployment configuration.

The bundled Three.js files use the MIT license; see `slides/vendor/LICENSE`.
