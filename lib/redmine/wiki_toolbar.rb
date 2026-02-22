#attributes frozen_string_literal: true

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

module Redmine
  class WikiToolbar
    extend Forwardable
    def_delegators :@view_context, :tag, :concat, :help_wiki_syntax_path, :l, :safe_join, :sprite_icon, :modifier_key, :modifier

    def initialize(view_context)
      @view_context = view_context
    end

    def controller_name
    end

    def buttons
    end

    def render(field_id:, preview_url:, auto_complete:, list_autofill:)
      tag.div(class: 'wiki-editor',
              data: {
                controller: controller_name,
                field_id: field_id,
                "#{controller_name}-preview-url-value": preview_url,
                "#{controller_name}-help-url-value": help_wiki_syntax_path,
                "#{controller_name}-languages-value": current_language
              }) do
        concat(
          tag.div(class: 'wiki-editor-header') do
            concat(
              tag.div(class: 'wiki-editor-tabs') do
                concat tag.button(l(:button_edit), type: 'button', class: 'wiki-editor-tab selected', data: { action: "#{controller_name}#edit", "#{controller_name}-target": "editTab" })
                concat tag.button(l(:label_preview), type: 'button', class: 'wiki-editor-tab', data: { action: "#{controller_name}#preview", "#{controller_name}-target": "previewTab" })
              end
            )
            concat(
              tag.div(class: 'wiki-editor-buttons', data: { "#{controller_name}-target": "buttons" }) do
                render_buttons
              end
            )
          end
        )

        concat(
          tag.div(class: 'wiki-editor-pane wiki-editor-edit', data: { "#{controller_name}-target": "editPane" }) do
            yield(attributes(field_id, auto_complete, list_autofill))
          end
        )

        concat(
          tag.div(class: 'wiki-editor-pane wiki-editor-preview wiki hidden', data: { "#{controller_name}-target": "previewPane" })
        )
      end
    end

    private

    def attributes(field_id, auto_complete, list_autofill)
      controllers = []
      actions = ["keydown.#{modifier}+b->#{controller_name}#strong:prevent",
                 "keydown.#{modifier}+i->#{controller_name}#italic:prevent",
                 "keydown.#{modifier}+u->#{controller_name}#underline:prevent",
                 "keydown.#{modifier}+shift+p@window->#{controller_name}#togglePreview:prevent",
                 "keydown.#{modifier}+shift+p->#{controller_name}#preview:prevent"]
      data = {}
      if field_id.nil?
        data["#{controller_name}_target"] = 'field'
      end

      if auto_complete
        data[:auto_complete] = true
      end

      if Setting.text_formatting.present? && list_autofill
        controllers << 'list-autofill'
        actions << 'beforeinput->list-autofill#handleBeforeInput'
        data[:list_autofill_text_formatting_param] = Setting.text_formatting
      end
      data.merge!({controller: controllers.join(' '), action: actions.join(' ')})
    end

    def render_buttons
      @rendered_buttons ||= safe_join(
        buttons.map do |button|
          if button[:class] == 'jstSpacer' || button[:class] == 'spacer'
            tag.span(class: 'jstSpacer')
          else
            title = l(button[:label])
            title += " (#{modifier_key}+#{button[:shortcut].upcase})" if button[:shortcut]

            tag.button(
              button_content(button, title),
              type: 'button',
              class: button[:class],
              title: title,
              data: { action: "#{controller_name}##{button[:action]}" }
            )
          end
        end)
    end

    def button_content(button, title)
      if button[:icon] == 'pre'
        tag.svg(class: 's16 icon-svg', aria: { hidden: true }, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2', 'stroke-linecap': 'round',
                'stroke-linejoin': 'round') do
          concat tag.rect(x: '3', y: '5', width: '18', height: '14', rx: '2')
          concat tag.text('pre', x: '12', y: '15', 'text-anchor': 'middle', style: 'font-size: 8px; font-weight: bold; font-family: monospace;', fill: 'currentColor', stroke: 'none')
        end
      else
        sprite_icon(button[:icon], title, icon_only: true, size: 16)
      end
    end

    def current_language
      @current_language ||= (User.current && User.current.pref.toolbar_language_options || UserPreference::DEFAULT_TOOLBAR_LANGUAGE_OPTIONS).split(',')
    end
  end
end
