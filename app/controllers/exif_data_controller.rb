class ExifDataController < ApplicationController
  # GET /exif_data
  # GET /exif_data.json
  def index
    @exif_data = ExifDatum.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @exif_data }
    end
  end

  # GET /exif_data/1
  # GET /exif_data/1.json
  def show
    @exif_datum = ExifDatum.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @exif_datum }
    end
  end

  # GET /exif_data/new
  # GET /exif_data/new.json
  def new
    @exif_datum = ExifDatum.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @exif_datum }
    end
  end

  # GET /exif_data/1/edit
  def edit
    @exif_datum = ExifDatum.find(params[:id])
  end

  # POST /exif_data
  # POST /exif_data.json
  def create
    @exif_datum = ExifDatum.new(params[:exif_datum])

    respond_to do |format|
      if @exif_datum.save
        format.html { redirect_to @exif_datum, notice: 'Exif datum was successfully created.' }
        format.json { render json: @exif_datum, status: :created, location: @exif_datum }
      else
        format.html { render action: "new" }
        format.json { render json: @exif_datum.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /exif_data/1
  # PUT /exif_data/1.json
  def update
    @exif_datum = ExifDatum.find(params[:id])

    respond_to do |format|
      if @exif_datum.update_attributes(params[:exif_datum])
        format.html { redirect_to @exif_datum, notice: 'Exif datum was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @exif_datum.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /exif_data/1
  # DELETE /exif_data/1.json
  def destroy
    @exif_datum = ExifDatum.find(params[:id])
    @exif_datum.destroy

    respond_to do |format|
      format.html { redirect_to exif_data_url }
      format.json { head :no_content }
    end
  end
end
