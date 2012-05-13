class BrowseController < ApplicationController
  # GET /
  def index
    @images = Image.order(:name).limit(4)
  end
end
