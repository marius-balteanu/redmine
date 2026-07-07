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

class EmailOauthController < ApplicationController
  layout 'admin'
  before_action :require_admin

  def index
    @tokens = EmailOauthToken.order(:email)
  end

  def new
    @token = EmailOauthToken.new
    if Setting.email_oauth_providers.empty?
      flash[:error] = l(:text_email_oauth_providers_not_configured)
      redirect_to email_oauth_index_path
    end
  end

  def initiate
    email = params[:email_oauth_token][:email]
    provider = params[:email_oauth_token][:provider]

    provider_config = get_provider_config(provider)
    if provider_config.blank?
      flash[:error] = l(:error_oauth_authentication_failed, message: "Provider '#{provider}' is not configured in configuration.yml.")
      redirect_to new_email_oauth_path and return
    end

    # Build authorization URL
    auth_uri = build_auth_uri(provider, provider_config, email)

    # Store state in session to prevent CSRF / verify callback
    session[:email_oauth_state] = SecureRandom.hex(16)
    session[:email_oauth_email] = email
    session[:email_oauth_provider] = provider

    redirect_to auth_uri, allow_other_host: true
  end

  def callback
    state = params[:state]
    code = params[:code]
    error = params[:error]

    if error.present?
      flash[:error] = l(:error_oauth_authentication_failed, message: error)
      redirect_to email_oauth_index_path and return
    end

    Rails.logger.debug "*****"*50
    Rails.logger.debug { "EmailOauthController#callback: state=#{state}, session[:email_oauth_state]=#{session[:email_oauth_state]}" }
    unless Rails.env.development?
      if state.blank? || state != session[:email_oauth_state]
        flash[:error] = l(:error_oauth_authentication_failed, message: "OAuth verification state mismatch. Potential CSRF request.")
        redirect_to email_oauth_index_path and return
      end
    end

    email = session.delete(:email_oauth_email)
    provider = session.delete(:email_oauth_provider)
    session.delete(:email_oauth_state)

    provider_config = get_provider_config(provider)
    if provider_config.blank? || email.blank?
      flash[:error] = l(:error_oauth_authentication_failed, message: "Invalid session state or missing provider configuration.")
      redirect_to email_oauth_index_path and return
    end

    # Exchange authorization code for tokens
    exchange_and_save_tokens(provider, provider_config, email, code)
  end

  def destroy
    @token = EmailOauthToken.find(params[:id])
    if @token.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:error_oauth_authentication_failed, message: "Failed to delete OAuth token mapping.")
    end
    redirect_to email_oauth_index_path
  end

  private

  def email_oauth_config
    Redmine::Configuration['email_oauth']
  end

  def get_provider_config(provider)
    return nil if email_oauth_config.blank?

    email_oauth_config['providers']&.[] (provider.to_s)
  end

  def build_auth_uri(provider, config, email)
    redirect_uri = callback_email_oauth_url
    state = session[:email_oauth_state]

    case provider.to_s
    when 'google'
      # Google Workspace OAuth authorize URI
      uri = URI("https://accounts.google.com/o/oauth2/v2/auth")
      uri.query = URI.encode_www_form({
                                        client_id: config['client_id'],
        redirect_uri: redirect_uri,
        response_type: 'code',
        scope: 'https://mail.google.com/',
        state: state,
        login_hint: email,
        access_type: 'offline',
        prompt: 'consent'
                                      })
      uri.to_s
    when 'microsoft'
      # Microsoft Azure AD OAuth authorize URI
      tenant = config['tenant'] || 'common'
      uri = URI("https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/authorize")
      uri.query = URI.encode_www_form({
                                        client_id: config['client_id'],
        redirect_uri: redirect_uri,
        response_type: 'code',
        scope: 'https://outlook.office.com/IMAP.AccessAsUser.All offline_access',
        state: state,
        login_hint: email,
        prompt: 'consent'
                                      })
      uri.to_s
    when 'custom'
      # Custom provider dynamic authorize URL
      uri = URI(config['authorize_url'])
      params = {
        client_id: config['client_id'],
        redirect_uri: redirect_uri,
        response_type: 'code',
        state: state
      }
      params[:scope] = config['scope'] if config['scope'].present?
      params[:login_hint] = email if email.present?
      uri.query = URI.encode_www_form(params)
      uri.to_s
    else
      raise "Unsupported OAuth provider: #{provider}"
    end
  end

  def exchange_and_save_tokens(provider, config, email, code)
    token_uri = case provider.to_s
                when 'google'
                  URI("https://oauth2.googleapis.com/token")
                when 'microsoft'
                  tenant = config['tenant'] || 'common'
                  URI("https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/token")
                when 'custom'
                  URI(config['token_url'])
                end

    payload = {
      client_id: config['client_id'],
      client_secret: config['client_secret'],
      code: code,
      redirect_uri: callback_email_oauth_url,
      grant_type: 'authorization_code'
    }

    res = Net::HTTP.post_form(token_uri, payload)
    if res.is_a?(Net::HTTPSuccess)
      data = JSON.parse(res.body)

      expires_in = data['expires_in'].to_i.seconds
      expires_at = Time.now + expires_in

      # Find or initialize token mapping
      token_record = EmailOauthToken.find_or_initialize_by(email: email)
      token_record.provider = provider
      token_record.access_token = data['access_token']
      token_record.refresh_token = data['refresh_token'] if data['refresh_token'].present?
      token_record.expires_at = expires_at
      token_record.is_valid = true
      token_record.last_error = nil

      if token_record.save
        flash[:notice] = l(:notice_successful_create)
      else
        flash[:error] = l(:error_oauth_authentication_failed, message: token_record.errors.full_messages.join(', '))
      end
    else
      flash[:error] = l(:error_oauth_authentication_failed, message: "[#{res.code}] #{res.body}")
    end

    redirect_to email_oauth_index_path
  end
end
