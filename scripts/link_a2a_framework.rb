require "xcodeproj"

project_path = "SafeGuardian.xcodeproj"
framework_path = "Generated/A2ABridge/BitchatA2ABridge.xcframework"
target_name = "SafeGuardian_iOS"

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == target_name }
raise "target #{target_name} not found" unless target

group = project.main_group.find_subpath("Frameworks", true)
existing = group.files.find { |f| f.path == framework_path }
file_ref = existing || group.new_reference(framework_path)
file_ref.source_tree = "<group>"

unless target.frameworks_build_phase.files.any? { |bf| bf.file_ref == file_ref }
  target.frameworks_build_phase.add_file_reference(file_ref)
end

embed_phase = target.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :frameworks }
unless embed_phase
  embed_phase = target.new_copy_files_build_phase("Embed Frameworks")
  embed_phase.symbol_dst_subfolder_spec = :frameworks
end
unless embed_phase.files.any? { |bf| bf.file_ref == file_ref }
  build_file = embed_phase.add_file_reference(file_ref)
  build_file.settings = { "ATTRIBUTES" => ["CodeSignOnCopy", "RemoveHeadersOnCopy"] }
end

fw_search_paths_key = "FRAMEWORK_SEARCH_PATHS"
target.build_configurations.each do |config|
  paths = config.build_settings[fw_search_paths_key]
  paths = paths.is_a?(Array) ? paths.dup : (paths ? [paths] : ["$(inherited)"])
  entry = "$(PROJECT_DIR)/Generated/A2ABridge"
  paths << entry unless paths.include?(entry)
  config.build_settings[fw_search_paths_key] = paths
end

project.save
puts "linked #{framework_path} into #{target_name}, Embed & Sign"
