class ExifDatum < ActiveRecord::Base
  attr_accessible :image_id, :tag, :value
  validates :image_id, :presence => true
  belongs_to :image
  ##### adding attributes that are outside of the database, but used for processing
  attr_accessor :q, :y
end
