class FilterController < ApplicationController
  
  def hash_filter
    
    @hash_filter = params[:hash_filter]
    
    @s = Search.where("md5hash = ?", @hash_filter).first
    
    @strs = "select image_id, count(*) from exif_data inner join images on exif_data.image_id = images.id where ";
    
    logger.info @s.serial.length
    
    i = 0
    @s.serial.each do |t|
      if i != 0
        @strs += " OR "
      end
      @strs += "(tag = '#{t["tag"]}' and value = '#{t["value"]}') "
      i = 1
    end
    
      @strs += "group by image_id having count(*) = #{@s.serial.length} "
    
      logger.info @strs
    ##array for the id's for searching later
    @id_array = Array.new
    
    @exif = ExifDatum.find_by_sql(@strs.to_s)
    @exif.each do |img|
      #logger.info img.image_id
      #logger.info img.image.location
      @id_array.push img.image_id
    end
    
    @exi2 = ExifDatum.select("tag, value, count(*) as count").where("image_id IN (?)", @id_array).group("tag, value").order("tag asc")
    #@exi2 = ExifDatum.all(:conditions => {["image_id = ?", @id_array]}) #.select("tag, value, count(*) as count") ##.group("tag, value").order("tag asc")
      @exi2.each do |exi2_data|
      
        @h = Array.new
        @s.serial.each do |t|
          @h.push({ "tag" => t["tag"], "value" => t["value"] })
        end
        @h.push({ "tag" => exi2_data.tag, "value" => exi2_data.value })

        logger.info @h
        logger.info "\n\n###"
        
        @y = @h.to_yaml
        @q = Digest::MD5.new.update(@y)

        filter_check(@q.to_s, @h)
        exi2_data.q = @q
        
      end
    
  end
  
end
