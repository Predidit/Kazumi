cask "kazumi" do
  version "2.2.5"
  sha256 "5a4d228d322f33ce5227935328ab1aff4492ed0d3d64ac091e140eefde41f1d6"

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
