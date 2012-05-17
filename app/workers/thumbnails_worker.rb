# app/workers/hard_worker.rb
class ThumbnailsWorker
  include Sidekiq::Worker

  def perform(folder, file)
    puts "Calling Thumbnails helper for #{folder} and #{file}"
    @t = ThumbnailsHelper
    @t.create_thumbnail folder, file
  end
end