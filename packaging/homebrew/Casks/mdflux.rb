# Draft Homebrew cask for MDFlux (macOS Apple Silicon).
# Published automatically on v* tags by .github/workflows/portable.yml → publish-homebrew
# into audichuang/homebrew-tap (requires HOMEBREW_TAP_TOKEN secret).
#
# Install (after tap is updated):
#   brew tap audichuang/tap
#   brew install --cask audichuang/tap/mdflux
#
# Manual dry-run from this monorepo (advanced):
#   brew install --cask --formula ./packaging/homebrew/Casks/mdflux.rb
#   (prefer the published tap; local path install is for maintainers only)

cask "mdflux" do
  version "0.1.1"
  sha256 "REPLACE_WITH_CI_SHA256_OF_MDFlux_VERSION_aarch64.dmg"

  url "https://github.com/audichuang/mdflux/releases/download/v#{version}/MDFlux_#{version}_aarch64.dmg"
  name "MDFlux"
  desc "Convert documents to clean Markdown — offline desktop app"
  homepage "https://github.com/audichuang/mdflux"

  # First ship: Apple Silicon only. Intel mac can use online provision later.
  depends_on macos: ">= :big_sur"
  depends_on arch: :arm64

  app "MDFlux.app"

  zap trash: [
    "~/Library/Application Support/com.projektvisyo.mdflux",
    "~/Library/Caches/com.projektvisyo.mdflux",
    "~/Library/Preferences/com.projektvisyo.mdflux.plist",
    "~/Library/WebKit/com.projektvisyo.mdflux",
  ]
end
