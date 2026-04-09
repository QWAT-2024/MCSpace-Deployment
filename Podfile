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

  # Determine where .flutter-plugins-dependencies lives.
  # Standard Flutter layout: it's one level up from Podfile (ios/../.flutter-plugins-dependencies)
  # Xcode Cloud flattened layout: Podfile IS in the repo root, so check current dir too.
  podfile_dir = File.dirname(File.realpath(__FILE__))
  flutter_plugins_deps_parent = if File.exist?(File.join(podfile_dir, '..', '.flutter-plugins-dependencies'))
    File.join(podfile_dir, '..')  # Standard layout: project root is parent of ios/
  else
    podfile_dir                   # Flattened layout: project root IS the Podfile directory
  end
  flutter_install_all_ios_pods flutter_plugins_deps_parent
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      config.build_settings['SWIFT_VERSION'] = '5.0'
      config.build_settings['DEFINES_MODULE'] = 'YES'
    end
  end

  # Fix search paths for the main Runner target
  installer.aggregate_targets.each do |target|
    target.user_targets.each do |user_target|
      next unless user_target.name == 'Runner'
      user_target.build_configurations.each do |config|
        existing = config.build_settings['HEADER_SEARCH_PATHS'] || '$(inherited)'
        config.build_settings['HEADER_SEARCH_PATHS'] = "#{existing} $(SRCROOT)/.symlinks/plugins/**"
      end
    end
  end
end