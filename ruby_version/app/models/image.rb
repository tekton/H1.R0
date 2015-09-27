class Image < ActiveRecord::Base
  attr_accessible :id, :location, :name
  has_many :exif_data, dependent: :destroy
end
