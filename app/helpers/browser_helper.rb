# frozen_string_literal: true

module BrowserHelper
  def mac_os?
    request.user_agent.downcase.include?('macintosh')
  end

  def modifier_key
    mac_os? ? '⌘' : 'Ctrl'
  end

  def modifier
    mac_os? ? 'meta' : 'ctrl'
  end
end
