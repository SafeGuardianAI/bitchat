require "xcodeproj"

project_path = "SafeGuardian.xcodeproj"
modulemap = "$(SRCROOT)/Generated/A2ABridge/swift/bitchat_a2aFFI.modulemap"
target_name = "SafeGuardian_iOS"

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == target_name }
raise "target #{target_name} not found" unless target

flag = "-Xcc -fmodule-map-file=#{modulemap}"
target.build_configurations.each do |config|
  existing = config.build_settings["OTHER_SWIFT_FLAGS"]
  flags = existing.is_a?(Array) ? existing.dup : (existing ? [existing] : ["$(inherited)"])
  flags << flag unless flags.include?(flag)
  config.build_settings["OTHER_SWIFT_FLAGS"] = flags
end

project.save
puts "wired module map flag into #{target_name}"
