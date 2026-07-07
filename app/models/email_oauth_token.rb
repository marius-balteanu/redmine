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

class EmailOauthToken < ApplicationRecord
  include Redmine::Ciphering

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :provider, presence: true, inclusion: { in: %w[microsoft google custom] }
  validates :refresh_token, presence: true
  validates :expires_at, presence: true

  def access_token
    read_ciphered_attribute(:access_token)
  end

  def access_token=(arg)
    write_ciphered_attribute(:access_token, arg)
  end

  def refresh_token
    read_ciphered_attribute(:refresh_token)
  end

  def refresh_token=(arg)
    write_ciphered_attribute(:refresh_token, arg)
  end

  # Check if the access token has expired
  def expired?
    expires_at.nil? || expires_at <= Time.now
  end

  # Check if a refresh is needed (e.g., if expired or expiring in the next 5 minutes)
  def refresh_needed?
    expired? || expires_at <= 5.minutes.from_now
  end
end
