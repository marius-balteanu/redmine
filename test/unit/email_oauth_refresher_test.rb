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
require 'redmine/email_oauth/refresher'

class EmailOauthRefresherTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    EmailOauthToken.delete_all
    @token = EmailOauthToken.create!(
      email: 'oauth-test@example.net',
      provider: 'google',
      access_token: 'initial_access_token',
      refresh_token: 'initial_refresh_token',
      expires_at: 10.minutes.ago,
      is_valid: true
    )
    # Clear any deliveries
    ActionMailer::Base.deliveries.clear
  end

  def test_refresh_not_needed
    @token.update!(expires_at: 1.hour.from_now)
    # No Net::HTTP requests should be made
    Net::HTTP.expects(:post_form).never
    assert Redmine::EmailOAuth::Refresher.refresh!(@token)
    assert @token.is_valid?
    assert_nil @token.last_error
  end

  def test_refresh_with_missing_config
    Redmine::Configuration.with 'email_oauth' => nil do
      assert_not Redmine::EmailOAuth::Refresher.refresh!(@token)
      @token.reload
      assert_not @token.is_valid?
      assert_match /missing in configuration.yml/, @token.last_error
      assert_equal 1, ActionMailer::Base.deliveries.size
    end
  end

  def test_refresh_success
    config = {
      'providers' => {
        'google' => {
          'client_id' => 'google_id',
          'client_secret' => 'google_secret'
        }
      }
    }

    mock_response = mock('response')
    mock_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    mock_response.stubs(:body).returns({
      'access_token' => 'new_access_token',
      'expires_in' => 3600
    }.to_json)

    Redmine::Configuration.with 'email_oauth' => config do
      Net::HTTP.expects(:post_form).with(
        URI("https://oauth2.googleapis.com/token"),
        {
          client_id: 'google_id',
          client_secret: 'google_secret',
          refresh_token: 'initial_refresh_token',
          grant_type: 'refresh_token'
        }
      ).returns(mock_response)

      assert Redmine::EmailOAuth::Refresher.refresh!(@token)
      @token.reload
      assert_equal 'new_access_token', @token.access_token
      assert @token.is_valid?
      assert_nil @token.last_error
      assert_equal 0, ActionMailer::Base.deliveries.size
    end
  end

  def test_refresh_custom_provider_success
    @token.update!(provider: 'custom', refresh_token: 'custom_refresh')
    config = {
      'providers' => {
        'custom' => {
          'client_id' => 'custom_id',
          'client_secret' => 'custom_secret',
          'token_url' => 'https://oauth.custom.local/token',
          'scope' => 'custom_scope'
        }
      }
    }

    mock_response = mock('response')
    mock_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    mock_response.stubs(:body).returns({
      'access_token' => 'new_custom_access_token',
      'expires_in' => 1800
    }.to_json)

    Redmine::Configuration.with 'email_oauth' => config do
      Net::HTTP.expects(:post_form).with(
        URI("https://oauth.custom.local/token"),
        {
          client_id: 'custom_id',
          client_secret: 'custom_secret',
          refresh_token: 'custom_refresh',
          grant_type: 'refresh_token',
          scope: 'custom_scope'
        }
      ).returns(mock_response)

      assert Redmine::EmailOAuth::Refresher.refresh!(@token)
      @token.reload
      assert_equal 'new_custom_access_token', @token.access_token
      assert @token.is_valid?
      assert_nil @token.last_error
    end
  end

  def test_refresh_failure
    config = {
      'providers' => {
        'google' => {
          'client_id' => 'google_id',
          'client_secret' => 'google_secret'
        }
      }
    }

    mock_response = mock('response')
    mock_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(false)
    mock_response.stubs(:code).returns('400')
    mock_response.stubs(:body).returns('{"error":"invalid_grant"}')

    Redmine::Configuration.with 'email_oauth' => config do
      Net::HTTP.expects(:post_form).returns(mock_response)

      assert_not Redmine::EmailOAuth::Refresher.refresh!(@token)
      @token.reload
      assert_not @token.is_valid?
      assert_match /invalid_grant/, @token.last_error
      assert_equal 1, ActionMailer::Base.deliveries.size

      # Check email delivery content
      mail = ActionMailer::Base.deliveries.first
      assert_match /OAuth 2.0 Email Account Authentication Failure/, mail.subject
      assert_match /oauth-test@example.net/, mail.body.encoded
    end
  end

  def test_imap_integration_with_oauth
    @token.update!(expires_at: 1.hour.from_now)

    mock_imap = mock('imap')
    Net::IMAP.expects(:new).with('127.0.0.1', port: '143', ssl: false).returns(mock_imap)
    mock_imap.expects(:authenticate).with('XOAUTH2', 'oauth-test@example.net', 'initial_access_token')
    mock_imap.expects(:select).with('INBOX')
    mock_imap.expects(:uid_search).with(['NOT', 'SEEN']).returns([])
    mock_imap.expects(:expunge)
    mock_imap.expects(:logout)
    mock_imap.expects(:disconnect)

    Redmine::IMAP.check({
      host: '127.0.0.1',
      port: '143',
      username: 'oauth-test@example.net'
    })
  end

  def test_imap_integration_fallback_to_login
    mock_imap = mock('imap')
    Net::IMAP.expects(:new).with('127.0.0.1', port: '143', ssl: false).returns(mock_imap)
    mock_imap.expects(:login).with('plain-user@example.net', 'password')
    mock_imap.expects(:select).with('INBOX')
    mock_imap.expects(:uid_search).with(['NOT', 'SEEN']).returns([])
    mock_imap.expects(:expunge)
    mock_imap.expects(:logout)
    mock_imap.expects(:disconnect)

    Redmine::IMAP.check({
      host: '127.0.0.1',
      port: '143',
      username: 'plain-user@example.net',
      password: 'password'
    })
  end
end
