# Adds the ShareExtension target (ios/ShareExtension) to Runner.xcodeproj, so
# Synk shows in the iPhone share menu. Run by .github/workflows/ios-build.yml
# on the build Mac; the project file in git stays without it.
require 'xcodeproj'

project = Xcodeproj::Project.open(File.join(__dir__, '..', 'Runner.xcodeproj'))
exit if project.targets.any? { |t| t.name == 'ShareExtension' }

app = project.targets.find { |t| t.name == 'Runner' }
ext = project.new_target(:app_extension, 'ShareExtension', :ios, '15.0')

group = project.main_group.new_group('ShareExtension', 'ShareExtension')
ext.add_file_references([group.new_file('ShareViewController.swift')])
group.new_file('Info.plist')

project.build_configurations.each do |config|
  next if ext.build_configurations.any? { |c| c.name == config.name }
  ext.add_build_configuration(config.name, config.type)
end
ext.build_configurations.each do |config|
  s = config.build_settings
  s['INFOPLIST_FILE'] = 'ShareExtension/Info.plist'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.synk.ShareExtension'
  s['PRODUCT_NAME'] = 'ShareExtension'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end

# Embedded before Flutter's Thin Binary script, or Xcode reports a cycle.
embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed.name = 'Embed App Extensions'
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
thin = app.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
app.build_phases.insert(thin || app.build_phases.length, embed)
app.add_dependency(ext)

project.save
