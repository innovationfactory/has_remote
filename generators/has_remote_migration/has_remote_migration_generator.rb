class HasRemoteMigrationGenerator < Rails::Generator::Base #:nodoc:
  def manifest
    record do |m|
      m.migration_template "create_has_remote_synchronizations.erb", File.join("db", "migrate"), :migration_file_name => 'create_has_remote_synchronizations'
    end
  end
end