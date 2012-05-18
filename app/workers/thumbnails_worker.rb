# app/workers/hard_worker.rb
class ThumbnailsWorker
  include Sidekiq::Worker

  def perform(folder, file)
    logger.info "Calling Thumbnails helper for #{folder} and #{file}"
    ThumbnailsController.new.create_thumbnail(folder, file)
  end
end