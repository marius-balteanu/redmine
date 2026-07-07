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

class EmailOauthTokenTest < ActiveSupport::TestCase
  def setup
    EmailOauthToken.delete_all
  end

  def test_validations
    # Valid record
    token = EmailOauthToken.new(
      email: 'redmine@example.net',
      provider: 'microsoft',
      refresh_token: 'valid_refresh_token',
      expires_at: 1.hour.from_now
    )
    assert token.valid?

    # Missing email
    token.email = nil
    assert_not token.valid?
    assert_includes token.errors[:email], "cannot be blank"

    # Invalid email format
    token.email = 'not-an-email'
    assert_not token.valid?

    # Missing provider
    token.email = 'redmine@example.net'
    token.provider = nil
    assert_not token.valid?

    # Invalid provider
    token.provider = 'invalid_provider'
    assert_not token.valid?

    # Duplicate email (case-insensitive)
    EmailOauthToken.create!(
      email: 'redmine@example.net',
      provider: 'microsoft',
      refresh_token: 'token1',
      expires_at: 1.hour.from_now
    )
    duplicate = EmailOauthToken.new(
      email: 'REDMINE@example.net',
      provider: 'google',
      refresh_token: 'token2',
      expires_at: 1.hour.from_now
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  def test_ciphering
    Redmine::Configuration.with 'database_cipher_key' => 'secret' do
      token = EmailOauthToken.create!(
        email: 'redmine@example.net',
        provider: 'google',
        access_token: 'secret_access',
        refresh_token: 'secret_refresh',
        expires_at: 1.hour.from_now
      )

      # In-memory reading should be transparently decrypted
      assert_equal 'secret_access', token.access_token
      assert_equal 'secret_refresh', token.refresh_token

      # Reading raw database attributes should show encrypted values (with 'aes-256-cbc:')
      raw_record = ActiveRecord::Base.connection.select_one(
        "SELECT access_token, refresh_token FROM email_oauth_tokens WHERE id = #{token.id}"
      )
      assert_match /\Aaes-256-cbc:/, raw_record['access_token']
      assert_match /\Aaes-256-cbc:/, raw_record['refresh_token']
    end
  end

  def test_expired_and_refresh_needed
    token = EmailOauthToken.new(
      email: 'redmine@example.net',
      provider: 'microsoft',
      refresh_token: 'refresh',
      expires_at: 10.minutes.ago
    )
    assert token.expired?
    assert token.refresh_needed?

    token.expires_at = 2.minutes.from_now
    assert_not token.expired?
    assert token.refresh_needed? # within 5 minutes grace period

    token.expires_at = 10.minutes.from_now
    assert_not token.expired?
    assert_not token.refresh_needed?
  end
end
