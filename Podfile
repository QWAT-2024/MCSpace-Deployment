# Uncomment this line to define a global platform for your project
platform :ios, '15.0'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  return ENV['FLUTTER_ROOT'] if ENV['FLUTTER_ROOT']
  
  # Try common paths for Generated.xcconfig (handles standard and flattened layouts)
  base_dir = File.dirname(__FILE__)
  config_paths = [
    File.join(base_dir, 'Flutter', 'Generated.xcconfig'),
    File.join(base_dir, '..', 'Flutter', 'Generated.xcconfig')
  ]
  
  config_paths.each do |path|
    if File.exist?(path)
      File.foreach(path) do |line|
        matches = line.match(/FLUTTER_ROOT\=(.*)/)
        return matches[1].strip if matches
      end
    end
  end

  raise "FLUTTER_ROOT not found in environment or Generated.xcconfig. Run flutter pub get first."
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks! :linkage => :static
  use_modular_headers!

  # Trick flutter_install_all_ios_pods to look for .flutter-plugins-dependencies in the root
  # (Standard helper uses File.join(ios_application_path, '..', '.flutter-plugins-dependencies'))
  flutter_install_all_ios_pods File.join(File.dirname(File.realpath(__FILE__)), 'ios')
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
    end
  end
end