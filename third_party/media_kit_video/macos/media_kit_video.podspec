#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint media_kit_video.podspec` to validate before publishing.
#


Pod::Spec.new do |s|
  s.name             = 'media_kit_video'
  s.version          = '0.0.1'
  s.summary          = 'Native implementation for video playback in package:media_kit'
  s.description      = <<-DESC
  Native implementation for video playback in package:media_kit.
                       DESC
  s.homepage         = 'https://github.com/media-kit/media-kit.git'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hitesh Kumar Saini' => 'saini123hitesh@gmail.com' }

  s.source           = { :path => '.' }
  s.platform = :osx, '10.15'
  s.swift_version    = '5.0'
  s.dependency         'FlutterMacOS'
  s.resource_bundles = {
    'media_kit_video_privacy' => ['media_kit_video/Sources/media_kit_video/PrivacyInfo.xcprivacy']
  }

  s.source_files = 'media_kit_video/Sources/media_kit_video/plugin/**/*.swift',
                   '../common/mpv/media_kit_mpv.c', '../common/mpv/include/**/*.h'
  s.header_mappings_dir = '../common/mpv/include'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GL_SILENCE_DEPRECATION COREVIDEO_SILENCE_GL_DEPRECATION',
  }
end
