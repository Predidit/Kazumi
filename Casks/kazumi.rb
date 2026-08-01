cask "kazumi" do
  version "2.2.6"
  sha256 "4de2a977f93e5420d07981c7c4f2fd712a47b7122424088d5d55de9e3b8f18a2"

  url "https://github.com/Predidit/Kazumi/releases/download/#{version}/Kazumi_macos_#{version}.dmg",
      verified: "github.com/Predidit/Kazumi/"
  name "Kazumi"
  desc "基于自定义规则的番剧采集APP，支持流媒体在线观看，支持弹幕，支持实时超分辨率。"
  homepage "https://github.com/Predidit/Kazumi"

  depends_on macos: :big_sur

  app "Kazumi.app"

  zap trash: [
    "~/Library/Application Scripts/com.example.kazumi/",
    "~/Library/Containers/com.example.kazumi/",
  ]
end
