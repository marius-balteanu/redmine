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
    class ImagesScrubber < Loofah::Scrubber
      def initialize(project, obj, attr, only_path, options)
        super()
        @project = project
        @obj = obj
        @attr = attr
        @only_path = only_path
        @options = options
        @helper = ApplicationController.helpers
      end

      def scrub(node)
        return unless node.name == 'img' && node['src'].present?

        parse_hires_images(node)
        parse_inline_attachments(node)
      end

      private

      def parse_hires_images(node)
        return if node['srcset'].present?

        if node['src'] =~ /([^"]+@(\dx)\.(bmp|gif|jpg|jpe|jpeg|png))/i
          filename, dpr = $1, $2
          node['srcset'] = "#{filename} #{dpr}"
        end
      end

      def parse_inline_attachments(node)
        return if @options[:inline_attachments] == false

        attachments = @options[:attachments] || []
        if @obj.is_a?(Journal)
          attachments += @obj.journalized.attachments if @obj.journalized.respond_to?(:attachments)
        elsif @obj.respond_to?(:attachments)
          attachments += @obj.attachments
        end

        return if attachments.blank?

        if node['src'] =~ /([^\/"]+\.(bmp|gif|jpg|jpe|jpeg|png|webp))/i
          filename = $1
          if found = Attachment.latest_attach(attachments, CGI.unescape(filename))
            image_url = @helper.download_named_attachment_url(found, found.filename, :only_path => @only_path)
            node['src'] = image_url

            desc = found.description.to_s.delete('"')
            if !desc.blank? && node['alt'].blank?
              node['title'] = desc
              node['alt'] = desc
            end
            node['loading'] = 'lazy'
          end
        end
      end
    end
  end
end
