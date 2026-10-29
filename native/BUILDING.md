# Building native REACH

The project definition lives in project.yml. The generated Xcode project is intentionally not committed.

## Generate
Install XcodeGen 2.46 or later, then from this directory run:

    xcodegen generate

## Build gate
For an unsigned simulator build:

    xcodebuild -project REACH.xcodeproj -scheme REACH -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build

For tests, choose an available iOS Simulator destination and run the REACH scheme tests.

## Privacy
The generated app target includes the required camera and microphone usage descriptions. REACH requests those permissions only when preparing an intentional connection.

## Signing
No signing certificate, Apple team ID, provisioning profile or Firebase environment file belongs in Git. Those are injected only in trusted build/distribution environments.

## Current bundle ID
com.reachprototype.app is a temporary development identifier. Do not register it as the final App Store identity without an explicit product decision.
