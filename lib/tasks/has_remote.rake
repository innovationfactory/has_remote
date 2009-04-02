namespace :hr do

  desc 'Synchronizes all attributes locally cached by has_remote'
  task :sync => :environment do
    models = ENV['MODELS'].nil? ? HasRemote.models : extract_models
    models.each(&:update_cached_attributes!)
  end

  def extract_models
    ENV['MODELS'].split(',').map(&:constantize)
  end
end