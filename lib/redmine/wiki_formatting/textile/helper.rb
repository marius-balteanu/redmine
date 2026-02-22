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

module Redmine
  module WikiFormatting
    module Textile
      module Helper
        def wikitoolbar(field_id: nil, preview_url: preview_text_path, auto_complete: true, list_autofill: true, &)
          @wikitoolbar ||= WikiToolbar.new(self)
          @wikitoolbar.render(field_id: field_id, preview_url: preview_url, auto_complete: auto_complete, list_autofill: list_autofill, &)
        end

        def wikitoolbar_for(field_id, preview_url = preview_text_path)
          heads_for_wiki_formatter

          javascript_tag(
            "var wikiToolbar = new jsToolBar(document.getElementById('#{field_id}')); " \
              "wikiToolbar.setHelpLink('#{escape_javascript help_wiki_syntax_path}'); " \
              "wikiToolbar.setPreviewUrl('#{escape_javascript preview_url}'); wikiToolbar.draw();"
          )
        end

        def initial_page_content(page)
          "h1. #{page.pretty_title}"
        end

        def heads_for_wiki_formatter
          unless @heads_for_wiki_formatter_included
            toolbar_language_options = User.current && User.current.pref.toolbar_language_options
            lang =
              if toolbar_language_options.nil?
                UserPreference::DEFAULT_TOOLBAR_LANGUAGE_OPTIONS
              else
                toolbar_language_options.split(',')
              end
            content_for :header_tags do
              javascript_include_tag('jstoolbar/jstoolbar') +
              javascript_include_tag('jstoolbar/textile') +
              javascript_include_tag("jstoolbar/lang/jstoolbar-#{current_language.to_s.downcase}") +
              javascript_tag(
                "var wikiImageMimeTypes = #{Redmine::MimeType.by_type('image').to_json};" \
                  "var userHlLanguages = #{lang.to_json};") +
              stylesheet_link_tag('jstoolbar')
            end
            @heads_for_wiki_formatter_included = true
          end
        end
      end

      class WikiToolbar < Redmine::WikiToolbar
        def controller_name
          'textile-toolbar'
        end

        def buttons
          [
            { label: :label_wiki_toolbar_strong, class: 'jstb_strong', icon: 'bold', action: 'strong', shortcut: 'b' },
            { label: :label_wiki_toolbar_italic, class: 'jstb_em', icon: 'italic', action: 'italic', shortcut: 'i' },
            { label: :label_wiki_toolbar_underline, class: 'jstb_ins', icon: 'underline', action: 'underline', shortcut: 'u' },
            { label: :label_wiki_toolbar_deleted, class: 'jstb_del', icon: 'strikethrough', action: 'deleted' },
            { label: :label_wiki_toolbar_code, class: 'jstb_code', icon: 'inline-code', action: 'inlineCode' },
            { class: 'spacer' },
            { label: :label_wiki_toolbar_heading_1, class: 'jstb_h1', icon: 'h1', action: 'h1' },
            { label: :label_wiki_toolbar_heading_2, class: 'jstb_h2', icon: 'h2', action: 'h2' },
            { label: :label_wiki_toolbar_heading_3, class: 'jstb_h3', icon: 'h3', action: 'h3' },
            { class: 'spacer' },
            { label: :label_wiki_toolbar_unordered_list, class: 'jstb_ul', icon: 'list', action: 'unorderedList' },
            { label: :label_wiki_toolbar_ordered_list, class: 'jstb_ol', icon: 'list-numbers', action: 'orderedList' },
            { class: 'spacer' },
            { label: :label_wiki_toolbar_quote, class: 'jstb_bq', icon: 'indent-increase', action: 'quote' },
            { label: :label_wiki_toolbar_unquote, class: 'jstb_unbq', icon: 'indent-decrease', action: 'unquote' },
            { label: :label_wiki_toolbar_table, class: 'jstb_table', icon: 'table', action: 'table' },
            { label: :label_wiki_toolbar_preformatted_text, class: 'jstb_pre', icon: 'pre', action: 'pre' },
            { label: :label_wiki_toolbar_preformatted_code, class: 'jstb_precode', icon: 'changeset', action: 'precode' },
            { label: :label_wiki_toolbar_wiki_link, class: 'jstb_wiki_link', icon: 'wiki-link', action: 'wikiLink' },
            { label: :label_wiki_toolbar_image, class: 'jstb_image', icon: 'image', action: 'image' },
            { class: 'spacer' },
            { label: :label_wiki_toolbar_help, class: 'jstb_help', icon: 'help', action: 'help' }
          ]
        end
      end
    end
  end
end
