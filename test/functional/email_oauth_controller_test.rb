# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../test_helper'

class EmailOauthControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
    @request.session[:user_id] = 1 # Admin User
    EmailOauthToken.delete_all
    
    # Configure mock OAuth settings
    @mock_config = {
      'providers' => {
        'google' => {
          'client_id' => 'google_id',
          'client_secret' => 'google_secret'
        },
        'microsoft' => {
          'client_id' => 'ms_id',
          'client_secret' => 'ms_secret',
          'tenant' => 'common'
        }
      }
    }
  end

  def test_index_should_require_admin
    @request.session[:user_id] = nil # Anonymous
    get :index
    assert_response :redirect
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fadmin%2Fmail_handler%2Foauth'

    @request.session[:user_id] = 2 # Non-admin user
    get :index
    assert_response :forbidden
  end

  def test_index
    EmailOauthToken.create!(
      email: 'redmine@example.net',
      provider: 'google',
      refresh_token: 'refresh',
      expires_at: 1.hour.from_now
    )

    get :index
    assert_response :success
    assert_select 'tr td.name strong', text: 'redmine@example.net'
  end

  def test_new
    Redmine::Configuration.with 'email_oauth' => @mock_config do
      get :new
      assert_response :success
      assert_select 'select[name=?]', 'email_oauth_token[provider]' do
        assert_select 'option[value=google]', text: 'Google'
        assert_select 'option[value=microsoft]', text: 'Microsoft'
      end
    end
  end

  def test_initiate_redirects_to_google
    Redmine::Configuration.with 'email_oauth' => @mock_config do
      post :initiate, params: {
        email_oauth_token: {
          email: 'test@example.net',
          provider: 'google'
        }
      }
      
      # Verify redirection to Google's authorize URL
      assert_response :redirect
      assert_match %r{\Ahttps://accounts\.google\.com/o/oauth2/v2/auth}, @response.redirect_url
      assert_match %r{client_id=google_id}, @response.redirect_url
      assert_match %r{scope=https%3A%2F%2Fmail\.google\.com%2F}, @response.redirect_url
      assert_match %r{login_hint=test%40example\.net}, @response.redirect_url
      
      # Verify session is populated for callback verification
      assert_equal 'test@example.net', session[:email_oauth_email]
      assert_equal 'google', session[:email_oauth_provider]
      assert_not_nil session[:email_oauth_state]
    end
  end

  def test_initiate_redirects_to_microsoft
    Redmine::Configuration.with 'email_oauth' => @mock_config do
      post :initiate, params: {
        email_oauth_token: {
          email: 'ms@example.net',
          provider: 'microsoft'
        }
      }

      # Verify redirection to MS Azure authorize URL
      assert_response :redirect
      assert_match %r{\Ahttps://login\.microsoftonline\.com/common/oauth2/v2\.0/authorize}, @response.redirect_url
      assert_match %r{client_id=ms_id}, @response.redirect_url
      assert_match %r{scope=https%3A%2F%2Foutlook\.office\.com%2FIMAP\.AccessAsUser\.All\+offline_access}, @response.redirect_url
    end
  end

  def test_callback_success
    Redmine::Configuration.with 'email_oauth' => @mock_config do
      # Set up active authorization session state
      state_token = 'securestate'
      @request.session[:email_oauth_state] = state_token
      @request.session[:email_oauth_email] = 'success@example.net'
      @request.session[:email_oauth_provider] = 'google'

      # Mock successful token exchange response from Google
      mock_response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      mock_response.stubs(:body).returns({
        access_token: 'mock_access',
        refresh_token: 'mock_refresh',
        expires_in: 3600
      }.to_json)

      Net::HTTP.expects(:post_form).with(
        URI("https://oauth2.googleapis.com/token"),
        {
          client_id: 'google_id',
          client_secret: 'google_secret',
          code: 'auth_code_123',
          redirect_uri: 'http://test.host/admin/mail_handler/oauth/callback',
          grant_type: 'authorization_code'
        }
      ).returns(mock_response)

      get :callback, params: {
        state: state_token,
        code: 'auth_code_123'
      }

      # Should redirect to index with success message
      assert_response :redirect
      assert_redirected_to email_oauth_index_path
      assert_equal I18n.t(:notice_successful_create), flash[:notice]

      # Verify record was created/updated in the database
      token = EmailOauthToken.find_by(email: 'success@example.net')
      assert_not_nil token
      assert_equal 'google', token.provider
      assert_equal 'mock_access', token.access_token
      assert_equal 'mock_refresh', token.refresh_token
      assert token.expires_at > Time.now
      assert token.is_valid?
    end
  end

  def test_destroy
    token = EmailOauthToken.create!(
      email: 'delete_me@example.net',
      provider: 'google',
      refresh_token: 'refresh',
      expires_at: 1.hour.from_now
    )

    assert_difference 'EmailOauthToken.count', -1 do
      delete :destroy, params: { id: token.id }
    end

    assert_redirected_to email_oauth_index_path
    assert_equal I18n.t(:notice_successful_delete), flash[:notice]
  end
end
