require 'exifr'

class ExifParseController < ApplicationController
  
  def initialize
    @h = Hash.new()
  end
  
  # GET /exif_parse/:test
  def index
    folder = params[:test]
    loc = File.dirname(__FILE__) + "/../assets/images/"+folder
    find_files loc
  end
  
  def find_files(loc)
    files = Dir.new(loc)
    Dir.chdir(loc)
    files.each do |file|
      case file.downcase
      when /.jpg\Z/
        logger.info "#{file} is a jpg!"
        
        folder = params[:test]
        fname = folder+"/"+File.basename(file)
        logger.info fname
        image = Image.where("location = ?",fname).first_or_create!(:location => fname)

        
        if image == nil
          logger.info "Image not in database...yet..."
        else
          #exif_file(file)
          ExifWorker.perform_async(loc+"/"+file, image.id)
        end
      end
    end
  end
  
  def exif_file(file, id)
    exif_data = nil
    exif_data = EXIFR::JPEG.new(file)
    exif_loop_db(exif_data, id)
  end
  
  def exif_loop_db(exif_data, id)
    logger.info "loop through exif data for #{id}"
    exif_loop(exif_data, id)
  end
  
  def exif_loop(exif_data, id)
    exif_map = Hash.new()
    if exif_data.exif? then
      i = exif_data.exif.to_hash
      i.each_pair do |key,val|
        logger.info "#{key} :: #{val}"
        begin
        exif = ExifDatum.where(:image_id => id, :tag=>key.to_s, :value=>val.to_s).first_or_create!(:image_id => id, :tag=>key.to_s, :value=>val.to_s)
        rescue
          #just go to the next one...
        end
      end
    else
      
    end
  end
  
  
  #########################
  def i_h(h)
    h.each_key do |k|
      puts "#{k} ::"
        h[k].each_pair do |key,val|
          puts "     #{key} :: #{val}"
        end
    end
  end
  
  def old_function
    t = Time.now()
    @h = Hash.new()
    $log = Logger.new('log')
    loc = ARGV.first
    find_files(loc)
    
    logger.info @h.inspect
    
    i_h(@h)
    
    t = Time.now() - t
    puts t
  end
  
end
