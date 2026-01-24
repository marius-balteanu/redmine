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
    class LinksScrubber < Loofah::Scrubber
      attr_reader :project, :obj, :attr, :only_path, :options

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
        return unless node.text?
        return if node.ancestors('a, pre, code').any?

        content = node.content
        parse_wiki_links(content)
        parse_redmine_links(content)

        if content != node.content
          node.replace(content)
        end
      end

      private

      def parse_wiki_links(text)
        text.gsub!(/(!)?(\[\[([^\n|]+?)(\|([^\n|]+?))?\]\])/) do |m|
          link_project = project
          esc, all, page, title = $1, $2, $3, $5
          if esc.nil?
            page = CGI.unescapeHTML(page)
            if page =~ /^\#(.+)$/
              anchor = @helper.sanitize_anchor_name($1)
              url = "##{anchor}"
              next @helper.link_to(title.present? ? title.html_safe : ERB::Util.h(page), url, :class => 'wiki-page')
            end

            if page =~ /^([^:]+):(.*)$/
              identifier, page = $1, $2
              link_project = Project.find_by_identifier(identifier) || Project.find_by_name(identifier)
              title ||= identifier if page.blank?
            end

            if link_project && link_project.wiki && User.current.allowed_to?(:view_wiki_pages, link_project)
              # extract anchor
              anchor = nil
              if page =~ /^(.+?)\#(.+)$/
                page, anchor = $1, $2
              end
              anchor = @helper.sanitize_anchor_name(anchor) if anchor.present?
              # check if page exists
              wiki_page = link_project.wiki.find_page(page)
              url =
                if anchor.present? && wiki_page.present? &&
                     (obj.is_a?(WikiContent) || obj.is_a?(WikiContentVersion)) &&
                     obj.page == wiki_page
                  "##{anchor}"
                else
                  case options[:wiki_links]
                  when :local
                    "#{page.present? ? Wiki.titleize(page) : ''}.html" + (anchor.present? ? "##{anchor}" : '')
                  when :anchor
                    # used for single-file wiki export
                    "##{page.present? ? Wiki.titleize(page) : title}" + (anchor.present? ? "_#{anchor}" : '')
                  else
                    wiki_page_id = page.present? ? Wiki.titleize(page) : nil
                    parent =
                      if wiki_page.nil? && obj.is_a?(WikiContent) &&
                           obj.page && project == link_project
                        obj.page.title
                      else
                        nil
                      end
                    @helper.url_for(:only_path => only_path, :controller => 'wiki',
                            :action => 'show', :project_id => link_project,
                            :id => wiki_page_id, :version => nil, :anchor => anchor,
                            :parent => parent)
                  end
                end
              @helper.link_to(title.present? ? title.html_safe : ERB::Util.h(page),
                      url, :class => ('wiki-page' + (wiki_page ? '' : ' new')))
            else
              # project or wiki doesn't exist
              all
            end
          else
            all
          end
        end
      end

      def parse_redmine_links(text)
        text.gsub!(ApplicationHelper::LINKS_RE) do |_|
          tag_content = $~[:tag_content]
          leading = $~[:leading]
          esc = $~[:esc]
          project_prefix = $~[:project_prefix]
          project_identifier = $~[:project_identifier]
          prefix = $~[:prefix]
          repo_prefix = $~[:repo_prefix]
          repo_identifier = $~[:repo_identifier]
          sep = $~[:sep1] || $~[:sep2] || $~[:sep3] || $~[:sep4]
          identifier = $~[:identifier1] || $~[:identifier2] || $~[:identifier3]
          comment_suffix = $~[:comment_suffix]
          comment_id = $~[:comment_id]

          if tag_content
            $&
          else
            link = nil
            current_project = project
            if project_identifier
              current_project = Project.visible.find_by_identifier(project_identifier)
            end
            if esc.nil?
              if prefix.nil? && sep == 'r'
                if current_project
                  repository = nil
                  if repo_identifier
                    repository = current_project.repositories.detect {|repo| repo.identifier == repo_identifier}
                  else
                    repository = current_project.repository
                  end
                  if repository &&
                       (changeset = Changeset.visible.
                                        find_by_repository_id_and_revision(repository.id, identifier))
                    link = @helper.link_to(ERB::Util.h("#{project_prefix}#{repo_prefix}r#{identifier}"),
                                   {:only_path => only_path, :controller => 'repositories',
                                    :action => 'revision', :id => current_project,
                                    :repository_id => repository.identifier_param,
                                    :rev => changeset.revision},
                                   :class => 'changeset',
                                   :title => @helper.truncate_single_line_raw(changeset.comments, 100))
                  end
                end
              elsif sep == '#' || sep == '##'
                oid = identifier.to_i
                case prefix
                when nil
                  if oid.to_s == identifier &&
                    issue = Issue.visible.find_by_id(oid)
                    anchor = comment_id ? "note-#{comment_id}" : nil
                    url = @helper.issue_url(issue, :only_path => only_path, :anchor => anchor)
                    link =
                      if sep == '##'
                        @helper.link_to("#{issue.tracker.name} ##{oid}#{comment_suffix}: #{issue.subject}",
                                url,
                                :class => issue.css_classes,
                                :title => "#{I18n.l(:field_status)}: #{issue.status.name}")
                      else
                        @helper.link_to("##{oid}#{comment_suffix}",
                                url,
                                :class => issue.css_classes,
                                :title => "#{issue.tracker.name}: #{issue.subject.truncate(100)} (#{issue.status.name})")
                      end
                  elsif identifier == 'note'
                    link = @helper.link_to("#note-#{comment_id}", "#note-#{comment_id}")
                  end
                when 'document'
                  if document = Document.visible.find_by_id(oid)
                    link = @helper.link_to(document.title,
                                   @helper.document_url(document, :only_path => only_path),
                                   :class => 'document')
                  end
                when 'version'
                  if version = Version.visible.find_by_id(oid)
                    link = @helper.link_to(version.name, @helper.version_url(version, :only_path => only_path), :class => 'version')
                  end
                when 'message'
                  if message = Message.visible.find_by_id(oid)
                    link = @helper.link_to_message(message, {:only_path => only_path}, :class => 'message')
                  end
                when 'forum'
                  if board = Board.visible.find_by_id(oid)
                    link = @helper.link_to(board.name,
                                   @helper.project_board_url(board.project, board, :only_path => only_path),
                                   :class => 'board')
                  end
                when 'news'
                  if news = News.visible.find_by_id(oid)
                    link = @helper.link_to(news.title, @helper.news_url(news, :only_path => only_path), :class => 'news')
                  end
                when 'project'
                  if p = Project.visible.find_by_id(oid)
                    link = @helper.link_to_project(p, {:only_path => only_path}, :class => 'project')
                  end
                when 'user'
                  u = User.visible.find_by(:id => oid, :type => 'User')
                  link = @helper.link_to_user(u, :only_path => only_path) if u
                end
              elsif sep == ':'
                name = @helper.remove_double_quotes(identifier)
                case prefix
                when 'document'
                  if current_project && document = current_project.documents.visible.find_by_title(name)
                    link = @helper.link_to(document.title,
                                   @helper.document_url(document, :only_path => only_path),
                                   :class => 'document')
                  end
                when 'version'
                  if current_project && version = current_project.versions.visible.find_by_name(name)
                    link = @helper.link_to(version.name, @helper.version_url(version, :only_path => only_path), :class => 'version')
                  end
                when 'forum'
                  if current_project && board = current_project.boards.visible.find_by_name(name)
                    link = @helper.link_to(board.name,
                                   @helper.project_board_url(board.project, board, :only_path => only_path),
                                   :class => 'board')
                  end
                when 'news'
                  if current_project && news = current_project.news.visible.find_by_title(name)
                    link = @helper.link_to(news.title, @helper.news_url(news, :only_path => only_path), :class => 'news')
                  end
                when 'commit', 'source', 'export'
                  if current_project
                    repository = nil
                    if name =~ %r{^(([a-z0-9\-_]+)\|)(.+)$}
                      repo_prefix, repo_identifier, name = $1, $2, $3
                      repository = current_project.repositories.detect {|repo| repo.identifier == repo_identifier}
                    else
                      repository = current_project.repository
                    end
                    if prefix == 'commit'
                      if repository &&
                           (changeset =
                              Changeset.visible.
                                where(
                                  "repository_id = ? AND scmid LIKE ?",
                                  repository.id, "#{name}%"
                                ).first)
                        link =
                          @helper.link_to(
                            ERB::Util.h("#{project_prefix}#{repo_prefix}#{name}"),
                            {:only_path => only_path, :controller => 'repositories',
                             :action => 'revision', :id => current_project,
                             :repository_id => repository.identifier_param,
                            :rev => changeset.identifier},
                            :class => 'changeset',
                            :title => @helper.truncate_single_line_raw(changeset.comments, 100)
                          )
                      end
                    elsif repository && User.current.allowed_to?(:browse_repository, current_project)
                      name =~ %r{^[/\\]*(.*?)(@([^/\\@]+?))?(#(L\d+))?$}
                      path, rev, anchor = $1, $3, $5
                      link =
                        @helper.link_to(
                          ERB::Util.h("#{project_prefix}#{prefix}:#{repo_prefix}#{name}"),
                          {:only_path => only_path, :controller => 'repositories',
                           :action => (prefix == 'export' ? 'raw' : 'entry'),
                           :id => current_project, :repository_id => repository.identifier_param,
                           :path => @helper.to_path_param(path),
                           :rev => rev,
                           :anchor => anchor},
                          :class => (prefix == 'export' ? 'source download' : 'source'))
                    end
                    repo_prefix = nil
                  end
                when 'attachment'
                  attachments = options[:attachments] || []
                  if obj.is_a?(Journal)
                    attachments += obj.journalized.attachments if obj.journalized.respond_to?(:attachments)
                  elsif obj.respond_to?(:attachments)
                    attachments += obj.attachments
                  end
                  if attachments && attachment = Attachment.latest_attach(attachments, name)
                    link = @helper.link_to_attachment(attachment, :only_path => only_path, :class => 'attachment')
                  end
                when 'project'
                  if p = Project.visible.where("identifier = :s OR LOWER(name) = :s", :s => name.downcase).first
                    link = @helper.link_to_project(p, {:only_path => only_path}, :class => 'project')
                  end
                when 'user'
                  u = User.visible.find_by("LOWER(login) = :s AND type = 'User'", :s => name.downcase)
                  link = @helper.link_to_user(u, :only_path => only_path) if u
                end
              elsif sep == "@"
                name = @helper.remove_double_quotes(identifier)
                u = User.visible.find_by("LOWER(login) = :s AND type = 'User'", :s => name.downcase)
                link = @helper.link_to_user(u, :only_path => only_path, :class => 'user-mention', :mention => true) if u
              end
            end
            (leading + (link || "#{project_prefix}#{prefix}#{repo_prefix}#{sep}#{identifier}#{comment_suffix}"))
          end
        end
      end
    end
  end
end
