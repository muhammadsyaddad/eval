# Homebrew Cask Template (MacPulse)

This is a template for creating a Homebrew cask when you have a notarized DMG and a SHA256.

```ruby
cask "macpulse" do
  version "1.0.0"
  sha256 "<SHA256_OF_DMG>"

  url "https://github.com/<OWNER>/<REPO>/releases/download/v#{version}/MacPulse-#{version}.dmg"
  name "MacPulse"
  desc "Privacy-focused macOS activity recorder"
  homepage "https://github.com/<OWNER>/<REPO>"

  app "MacPulse.app"

  zap trash: [
    "~/Library/Application Support/MacPulse",
    "~/Library/Preferences/com.macpulse.app.plist",
    "~/Library/Saved Application State/com.macpulse.app.savedState"
  ]
end
```
