class ExifDatum < ActiveRecord::Base
  attr_accessible :image_id, :tag, :value
  validates :image_id, :presence => true
  belongs_to :image
end
