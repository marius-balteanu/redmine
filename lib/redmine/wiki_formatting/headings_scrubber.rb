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
    class HeadingsScrubber < Loofah::Scrubber
      def initialize(project, obj, attr, only_path, options, headings_tracker)
        super()
        @project = project
        @obj = obj
        @attr = attr
        @only_path = only_path
        @options = options
        @headings_tracker = headings_tracker
        @helper = ApplicationController.helpers
        @current_section = 0
      end

      def scrub(node)
        return unless ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].include?(node.name)

        level = node.name[1].to_i

        # Handle sections (Edit links)
        if @options[:edit_section_links]
          @current_section += 1
          if @current_section > 1
            section_link = @helper.content_tag(
              'div',
              @helper.link_to(
                @helper.sprite_icon('edit', @helper.l(:button_edit_section)),
                @options[:edit_section_links].merge(:section => @current_section),
                :class => 'icon-only icon-edit'),
              :class => "contextual heading-#{level}",
              :title => @helper.l(:button_edit_section),
              :id => "section-#{@current_section}")
            node.add_previous_sibling(section_link)
          end
        end

        # Handle anchors and TOC
        if @options[:headings] != false
          item = @helper.strip_tags(node.inner_html).strip
          anchor = @helper.sanitize_anchor_name(item)

          # used for single-file wiki export
          if @options[:wiki_links] == :anchor && (@obj.is_a?(WikiContent) || @obj.is_a?(WikiContentVersion))
            anchor = "#{@obj.page.title}_#{anchor}"
          end

          @headings_tracker[:heading_anchors][anchor] ||= 0
          idx = (@headings_tracker[:heading_anchors][anchor] += 1)
          if idx > 1
            anchor = "#{anchor}-#{idx}"
          end

          @headings_tracker[:parsed_headings] << [level, anchor, item]

          # Create anchor element
          anchor_name_tag = Nokogiri::HTML5.fragment("<a name=\"#{anchor}\"></a>").children.first
          node.add_previous_sibling(anchor_name_tag)

          # Add wiki-anchor inside heading
          wiki_anchor = Nokogiri::HTML5.fragment("<a href=\"##{anchor}\" class=\"wiki-anchor\">&para;</a>").children.first
          node.add_child(wiki_anchor)
        end
      end
    end
  end
end
