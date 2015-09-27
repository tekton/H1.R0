require 'test_helper'

class ExifDataControllerTest < ActionController::TestCase
  setup do
    @exif_datum = exif_data(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:exif_data)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create exif_datum" do
    assert_difference('ExifDatum.count') do
      post :create, exif_datum: { parent: @exif_datum.parent, tag: @exif_datum.tag, value: @exif_datum.value }
    end

    assert_redirected_to exif_datum_path(assigns(:exif_datum))
  end

  test "should show exif_datum" do
    get :show, id: @exif_datum
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @exif_datum
    assert_response :success
  end

  test "should update exif_datum" do
    put :update, id: @exif_datum, exif_datum: { parent: @exif_datum.parent, tag: @exif_datum.tag, value: @exif_datum.value }
    assert_redirected_to exif_datum_path(assigns(:exif_datum))
  end

  test "should destroy exif_datum" do
    assert_difference('ExifDatum.count', -1) do
      delete :destroy, id: @exif_datum
    end

    assert_redirected_to exif_data_path
  end
end
