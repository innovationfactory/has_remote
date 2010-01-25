namespace :hr do

  desc 'Synchronizes all attributes locally cached by has_remote'
  task :sync => :environment do
    models = ENV['MODELS'].nil? ? HasRemote.models : extract_models
    options = ENV['PARAMS'] ? Rack::Utils.parse_query(ENV['PARAMS']) : {}
    models.each{|model| model.synchronize!(options)}
  end

  def extract_models
    ENV['MODELS'].split(',').map(&:constantize)
  end
end
