require "test_helper"

class RevocationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_revocation_url
    assert_response :success
  end
end
