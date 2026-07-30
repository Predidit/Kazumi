cask "kazumi" do
  version "2.2.4"
  sha256 "a29c3131b4795301ad51bf2991b52f1ede689ada617739e87788459fbd915a8c"

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
