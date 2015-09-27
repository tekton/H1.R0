# app/workers/hard_worker.rb
class ExifWorker
  include Sidekiq::Worker

  def perform(file, id)
    logger.info "Calling exif_file for #{file}"
    ExifParseController.new.exif_file(file, id)
  end
end