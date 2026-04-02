require "test_helper"

class RevocationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get revocations_new_url
    assert_response :success
  end
end
