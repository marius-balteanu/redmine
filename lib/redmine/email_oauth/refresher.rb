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

require 'net/http'
require 'uri'
require 'json'

module Redmine
  module EmailOAuth
    class Refresher
      class << self
        def refresh!(token, force: false)
          return true if !force && !token.refresh_needed?

          config = Redmine::Configuration['email_oauth']
          provider_config = config&.[]('providers')&.[](token.provider.to_s)

          if provider_config.blank?
            error_msg = "Provider configuration for '#{token.provider}' is missing in configuration.yml."
            handle_failure(token, error_msg)
            return false
          end

          token_uri = token_endpoint(token.provider, provider_config)
          payload = refresh_payload(token, provider_config)

          begin
            res = Net::HTTP.post_form(token_uri, payload)
            if res.is_a?(Net::HTTPSuccess)
              data = JSON.parse(res.body)
              
              expires_in = (data['expires_in'] || 3600).to_i.seconds
              token.access_token = data['access_token']
              token.refresh_token = data['refresh_token'] if data['refresh_token'].present?
              token.expires_at = Time.now + expires_in
              token.is_valid = true
              token.last_error = nil

              if token.save
                true
              else
                error_msg = "Failed to save refreshed token: #{token.errors.full_messages.join(', ')}"
                handle_failure(token, error_msg)
                false
              end
            else
              error_msg = "OAuth provider returned error [#{res.code}]: #{res.body}"
              handle_failure(token, error_msg)
              false
            end
          rescue => e
            error_msg = "Exception during token refresh: #{e.message}"
            handle_failure(token, error_msg)
            false
          end
        end

        private

        def token_endpoint(provider, config)
          case provider.to_s
          when 'google'
            URI("https://oauth2.googleapis.com/token")
          when 'microsoft'
            tenant = config['tenant'] || 'common'
            URI("https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/token")
          when 'custom'
            URI(config['token_url'])
          else
            raise "Unsupported provider: #{provider}"
          end
        end

        def refresh_payload(token, config)
          payload = {
            client_id: config['client_id'],
            client_secret: config['client_secret'],
            refresh_token: token.refresh_token,
            grant_type: 'refresh_token'
          }

          if token.provider == 'microsoft'
            payload[:scope] = 'https://outlook.office.com/IMAP.AccessAsUser.All offline_access'
          elsif token.provider == 'custom' && config['scope'].present?
            payload[:scope] = config['scope']
          end

          payload
        end

        def handle_failure(token, error_message)
          token.is_valid = false
          token.last_error = error_message
          token.save(validate: false) # Skip validation if we are just marking as invalid

          # Send email alert to system administrators
          begin
            Mailer.deliver_email_oauth_refresh_failure(token, error_message)
          rescue => e
            Rails.logger.error "Failed to send OAuth refresh failure email: #{e.message}"
          end
        end
      end
    end
  end
end
