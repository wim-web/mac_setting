#!/usr/bin/env bash
set -euo pipefail

# renovate: datasource=github-tags depName=aws/aws-cli
AWSCLI_VERSION=2.35.15

pkg_path="/tmp/AWSCLIV2-${AWSCLI_VERSION}.pkg"
choices_path="/tmp/AWSCLIV2-${AWSCLI_VERSION}-choices.xml"
install_root="$HOME/.local/share"
install_dir="$install_root/aws-cli"
bin_dir="$HOME/.local/bin"

curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2-${AWSCLI_VERSION}.pkg" -o "$pkg_path"

if type brew >/dev/null 2>&1 && brew list --versions awscli >/dev/null 2>&1; then
    brew uninstall awscli
fi

mkdir -p "$install_root" "$bin_dir"

cat > "$choices_path" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <array>
    <dict>
      <key>choiceAttribute</key>
      <string>customLocation</string>
      <key>attributeSetting</key>
      <string>$install_root</string>
      <key>choiceIdentifier</key>
      <string>default</string>
    </dict>
  </array>
</plist>
XML

installer -pkg "$pkg_path" \
    -target CurrentUserHomeDirectory \
    -applyChoiceChangesXML "$choices_path"

ln -sf "$install_dir/aws" "$bin_dir/aws"
ln -sf "$install_dir/aws_completer" "$bin_dir/aws_completer"

if type fish >/dev/null 2>&1; then
    fish -c "fish_add_path ~/.local/bin || :"
fi

"$bin_dir/aws" --version
