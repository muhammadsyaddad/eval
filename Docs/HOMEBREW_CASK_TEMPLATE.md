# Homebrew Cask Template (Eval)

This is a template for creating a Homebrew cask when you have a notarized DMG and a SHA256.

```ruby
cask "eval" do
  version "1.0.0"
  sha256 "<SHA256_OF_DMG>"

  url "https://github.com/<OWNER>/<REPO>/releases/download/v#{version}/Eval-#{version}.dmg"
  name "Eval"
  desc "Privacy-focused macOS activity recorder"
  homepage "https://github.com/<OWNER>/<REPO>"

  app "Eval.app"

  zap trash: [
    "~/Library/Application Support/Eval",
    "~/Library/Preferences/com.eval.app.plist",
    "~/Library/Saved Application State/com.eval.app.savedState"
  ]
end
```
